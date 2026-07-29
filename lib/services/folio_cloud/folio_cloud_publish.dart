import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_identity.dart';
import 'folio_spring_storage.dart';

class FolioPublishResult {
  const FolioPublishResult({required this.publicUrl, required this.docId});

  final Uri publicUrl;
  final String docId;
}

class PublishedPageEntry {
  const PublishedPageEntry({
    required this.docId,
    required this.slug,
    required this.publicUrl,
    required this.storagePath,
    this.updatedAt,
  });

  final String docId;
  final String slug;
  final String publicUrl;
  final String storagePath;
  final DateTime? updatedAt;
}

void _requirePublishWebEntitlement(FolioCloudSnapshot? snapshot) {
  if (snapshot != null && !snapshot.canPublishToWeb) {
    throw StateError(
      'Tu plan Folio Cloud no incluye publicación web o la suscripción no está activa.',
    );
  }
}

String _safeSlug(String slug) {
  final safe = slug.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  if (safe.isEmpty) {
    throw ArgumentError('Invalid slug');
  }
  return safe;
}

String _slugFromStoragePath(String storagePath) {
  final name = storagePath.split('/').last;
  if (name.toLowerCase().endsWith('.html')) {
    return name.substring(0, name.length - 5);
  }
  return name;
}

Uri _springPublishedLogicalUrl(String storagePath) {
  return Uri.parse(
    '${FolioBackendConfig.apiV1Prefix}/storage/objects#${Uri.encodeComponent(storagePath)}',
  );
}

DateTime? _parseApiInstant(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

Future<Map<String, String>> _springAuthHeaders({bool forceRefresh = false}) async {
  final token = await folioCloudBearerToken(forceRefresh: forceRefresh);
  if (token == null || token.isEmpty) {
    throw StateError('Not signed in');
  }
  return <String, String>{
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };
}

Future<http.Response> _springAuthorized(
  Future<http.Response> Function(Map<String, String> headers) send,
) async {
  var headers = await _springAuthHeaders();
  var res = await send(headers);
  if (res.statusCode == 401) {
    headers = await _springAuthHeaders(forceRefresh: true);
    res = await send(headers);
  }
  return res;
}

void _ensureSpringOk(http.Response res, {bool allowNoContent = false}) {
  if (allowNoContent && res.statusCode == 204) return;
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  throw StateError(
    'published-pages HTTP ${res.statusCode}: ${res.body}',
  );
}

Map<String, dynamic> _decodeJsonMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw StateError('published-pages: expected JSON object');
  }
  return decoded.map((k, v) => MapEntry('$k', v));
}

PublishedPageEntry _entryFromSpringDto(Map<String, dynamic> m) {
  final id = m['id']?.toString() ?? '';
  final storagePath = m['storagePath']?.toString() ?? '';
  if (id.isEmpty || storagePath.isEmpty) {
    throw StateError('published-pages: missing id/storagePath');
  }
  final url = _springPublishedLogicalUrl(storagePath);
  return PublishedPageEntry(
    docId: id,
    slug: _slugFromStoragePath(storagePath),
    publicUrl: '$url',
    storagePath: storagePath,
    updatedAt: _parseApiInstant(m['updatedAt']),
  );
}

/// Publica HTML vía storage proxy + índice `POST/PUT /api/v1/published-pages`.
Future<FolioPublishResult> publishHtmlPage({
  required String slug,
  required String html,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requirePublishWebEntitlement(entitlementSnapshot);
  final uid = folioCloudCurrentUid();
  if (uid == null || uid.isEmpty) throw StateError('Not signed in');
  final safeSlug = _safeSlug(slug);
  final path = 'published/$uid/$safeSlug.html';
  final bytes = utf8.encode(html);
  await folioSpringStoragePutData(path, bytes);

  final mine = await listMyPublishedPages();
  PublishedPageEntry? existing;
  for (final e in mine) {
    if (e.storagePath == path) {
      existing = e;
      break;
    }
  }

  final body = jsonEncode(<String, dynamic>{'storagePath': path});
  late http.Response res;
  if (existing != null) {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/published-pages/${existing.docId}',
    );
    res = await _springAuthorized(
      (h) => http.put(uri, headers: h, body: body),
    );
  } else {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/published-pages',
    );
    res = await _springAuthorized(
      (h) => http.post(uri, headers: h, body: body),
    );
  }
  _ensureSpringOk(res);
  final dto = _decodeJsonMap(res.body);
  final entry = _entryFromSpringDto(dto);
  return FolioPublishResult(
    publicUrl: Uri.parse(entry.publicUrl),
    docId: entry.docId,
  );
}

Future<List<PublishedPageEntry>> listMyPublishedPages() async {
  final uid = folioCloudCurrentUid();
  if (uid == null || uid.isEmpty) throw StateError('Not signed in');
  final uri = Uri.parse(
    '${FolioBackendConfig.apiV1Prefix}/published-pages/mine',
  );
  final res = await _springAuthorized((h) => http.get(uri, headers: h));
  _ensureSpringOk(res);
  if (res.body.isEmpty) return const <PublishedPageEntry>[];
  final decoded = jsonDecode(res.body);
  if (decoded is! List) {
    throw StateError('published-pages/mine: expected JSON array');
  }
  final out = <PublishedPageEntry>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    try {
      out.add(
        _entryFromSpringDto(item.map((k, v) => MapEntry('$k', v))),
      );
    } catch (_) {}
  }
  return out;
}

Future<void> deletePublishedPage(
  PublishedPageEntry entry, {
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requirePublishWebEntitlement(entitlementSnapshot);
  final uid = folioCloudCurrentUid();
  if (uid == null || uid.isEmpty) throw StateError('Not signed in');
  final uri = Uri.parse(
    '${FolioBackendConfig.apiV1Prefix}/published-pages/${entry.docId}',
  );
  final res = await _springAuthorized((h) => http.delete(uri, headers: h));
  _ensureSpringOk(res, allowNoContent: true);
}
