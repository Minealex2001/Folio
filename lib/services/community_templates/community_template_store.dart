import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/folio_backend_config.dart';
import '../../models/folio_page_template.dart';
import '../folio_cloud/folio_cloud_identity.dart';
import '../folio_cloud/folio_spring_storage.dart';

const String kCommunityTemplatesCollection = 'communityTemplates';

/// Metadatos de una plantilla en la tienda comunitaria
/// (`/api/v1/community-templates` + proxy de storage).
class CommunityTemplateEntry {
  const CommunityTemplateEntry({
    required this.docId,
    required this.ownerUid,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.blockCount,
    required this.storagePath,
    required this.storageDownloadUrl,
    this.createdAt,
  });

  final String docId;
  final String ownerUid;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final int blockCount;
  final String storagePath;
  final String storageDownloadUrl;
  final DateTime? createdAt;

  static CommunityTemplateEntry? fromDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    final ownerUid = data['ownerUid']?.toString() ?? '';
    final name = data['name']?.toString() ?? '';
    final storagePath = data['storagePath']?.toString() ?? '';
    final url = data['storageDownloadUrl']?.toString() ?? '';
    if (ownerUid.isEmpty || name.isEmpty || storagePath.isEmpty || url.isEmpty) {
      return null;
    }
    DateTime? createdAt;
    final rawCreated = data['createdAt'];
    if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated);
    } else if (rawCreated is DateTime) {
      createdAt = rawCreated;
    }
    final blockCount = (data['blockCount'] as num?)?.toInt() ?? 0;
    return CommunityTemplateEntry(
      docId: docId,
      ownerUid: ownerUid,
      name: name,
      description: data['description']?.toString() ?? '',
      emoji: data['emoji']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      blockCount: blockCount,
      storagePath: storagePath,
      storageDownloadUrl: url,
      createdAt: createdAt,
    );
  }

  /// Shape JSON de `CommunityTemplatesService.toDto`.
  static CommunityTemplateEntry? fromSpringDto(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return fromDoc(id, data);
  }
}

class CommunityTemplateStore {
  CommunityTemplateStore();

  static bool get isFirebaseReady => true;

  static bool get isStoreAvailable => true;

  Future<Map<String, String>> _springAuthHeaders({
    bool forceRefresh = false,
  }) async {
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
      'community-templates HTTP ${res.statusCode}: ${res.body}',
    );
  }

  Future<String> publishTemplate(FolioPageTemplate tpl) async {
    final uid = folioCloudCurrentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Not signed in');
    }
    const uuid = Uuid();
    final docId = uuid.v4();
    final path = 'community-templates/$uid/$docId.folio-template';
    final published = FolioPageTemplate(
      id: docId,
      name: tpl.name,
      description: tpl.description,
      emoji: tpl.emoji,
      category: tpl.category,
      createdAtMs: tpl.createdAtMs,
      blocks: tpl.blocks,
    );
    final bytes = utf8.encode(published.encodeAsFile());
    await folioSpringStoragePutData(path, bytes);

    final storageDownloadUrl =
        '${FolioBackendConfig.apiV1Prefix}/storage/objects#${Uri.encodeComponent(path)}';
    final name = tpl.name.trim().isEmpty ? 'Template' : tpl.name.trim();
    final emoji = tpl.emoji?.trim() ?? '';
    final body = <String, dynamic>{
      'id': docId,
      'name': name,
      'description': tpl.description.trim(),
      'category': tpl.category.trim(),
      if (emoji.isNotEmpty) 'emoji': emoji,
      'blockCount': tpl.blocks.length,
      'storagePath': path,
      'storageDownloadUrl': storageDownloadUrl,
      'sizeBytes': bytes.length,
    };
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/community-templates',
    );
    final res = await _springAuthorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    _ensureSpringOk(res);
    return docId;
  }

  Future<List<CommunityTemplateEntry>> listRecent({int limit = 80}) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/community-templates',
    );
    http.Response res;
    final token = await folioCloudBearerToken();
    if (token != null && token.isNotEmpty) {
      res = await _springAuthorized((h) => http.get(uri, headers: h));
    } else {
      res = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    }
    _ensureSpringOk(res);
    if (res.body.isEmpty) return const <CommunityTemplateEntry>[];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw StateError('community-templates: expected JSON array');
    }
    final out = <CommunityTemplateEntry>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final e = CommunityTemplateEntry.fromSpringDto(
        item.map((k, v) => MapEntry('$k', v)),
      );
      if (e != null) out.add(e);
    }
    if (out.length > limit) {
      return out.sublist(0, limit);
    }
    return out;
  }

  Future<FolioPageTemplate> downloadTemplate(
    String downloadUrl, {
    String? storagePath,
  }) async {
    final path = (storagePath ?? '').trim().isNotEmpty
        ? storagePath!.trim()
        : _storagePathFromLogicalUrl(downloadUrl);
    if (path.isEmpty) {
      throw StateError('storagePath required');
    }
    final data = await folioSpringStorageGetData(path, 2 * 1024 * 1024);
    if (data == null) {
      throw StateError('Template object not found');
    }
    final raw = utf8.decode(data);
    final parsed = FolioPageTemplate.tryParseFile(raw);
    if (parsed == null) {
      throw const FormatException('Invalid community template file');
    }
    return parsed;
  }

  static String _storagePathFromLogicalUrl(String downloadUrl) {
    final uri = Uri.tryParse(downloadUrl);
    if (uri != null && uri.fragment.isNotEmpty) {
      return Uri.decodeComponent(uri.fragment);
    }
    if (downloadUrl.startsWith('community-templates/')) {
      return downloadUrl;
    }
    return '';
  }

  FolioPageTemplate copyIntoVault(FolioPageTemplate parsed) {
    const uuid = Uuid();
    return FolioPageTemplate(
      id: uuid.v4(),
      name: parsed.name,
      description: parsed.description,
      emoji: parsed.emoji,
      category: parsed.category,
      createdAtMs: parsed.createdAtMs,
      blocks: parsed.blocks,
    );
  }

  Future<void> deleteMyTemplate({
    required String docId,
    required String storagePath,
  }) async {
    final uid = folioCloudCurrentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Not signed in');
    }
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/community-templates/$docId',
    );
    final res = await _springAuthorized((h) => http.delete(uri, headers: h));
    _ensureSpringOk(res, allowNoContent: true);
  }
}
