import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/folio_backend_config.dart';
import '../../models/folio_page_template.dart';
import '../folio_cloud/folio_cloud_identity.dart';
import '../folio_cloud/folio_spring_storage.dart';

const String kCommunityTemplatesCollection = 'communityTemplates';

/// Orden de resultados soportado por `GET /api/v1/community-templates`.
enum CommunityTemplateSort { recent, popular, relevance }

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
    required this.useCount,
    this.storageDownloadUrl,
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
  final String? storageDownloadUrl;
  final int useCount;
  final DateTime? createdAt;

  static CommunityTemplateEntry? fromDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    final ownerUid = data['ownerUid']?.toString() ?? '';
    final name = data['name']?.toString() ?? '';
    final storagePath = data['storagePath']?.toString() ?? '';
    if (ownerUid.isEmpty || name.isEmpty || storagePath.isEmpty) {
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
    final useCount = (data['useCount'] as num?)?.toInt() ?? 0;
    final url = data['storageDownloadUrl']?.toString() ?? '';
    return CommunityTemplateEntry(
      docId: docId,
      ownerUid: ownerUid,
      name: name,
      description: data['description']?.toString() ?? '',
      emoji: data['emoji']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      blockCount: blockCount,
      storagePath: storagePath,
      storageDownloadUrl: url.isEmpty ? null : url,
      useCount: useCount,
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

/// Resultado paginado de `CommunityTemplateStore.search`.
class CommunityTemplateSearchResult {
  const CommunityTemplateSearchResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<CommunityTemplateEntry> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => (page + 1) * limit < total;
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
    final code = _apiErrorCode(res.body);
    if (code == 'community_template_upload_banned') {
      throw const CommunityTemplateApiException(
        'community_template_upload_banned',
        'Upload banned',
      );
    }
    if (code == 'already_reported') {
      throw const CommunityTemplateApiException(
        'already_reported',
        'Already reported',
      );
    }
    if (code == 'user_suspended') {
      throw const CommunityTemplateApiException(
        'user_suspended',
        'Account suspended',
      );
    }
    throw StateError('community-templates HTTP ${res.statusCode}: ${res.body}');
  }

  static String? _apiErrorCode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err != null) return err.toString();
      }
    } catch (_) {}
    return null;
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

  /// Búsqueda paginada en servidor: filtro opcional por categoría, texto libre
  /// (nombre/categoría/descripción) y orden (recientes/populares/relevancia).
  /// Sustituye al antiguo `listRecent()`, que traía como mucho 80-200 entradas
  /// y filtraba/ordenaba en memoria — invisible para cualquier plantilla más
  /// allá de ese límite.
  Future<CommunityTemplateSearchResult> search({
    String? query,
    String? category,
    CommunityTemplateSort sort = CommunityTemplateSort.recent,
    int page = 0,
    int limit = 80,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    switch (sort) {
      case CommunityTemplateSort.recent:
        break; // 'recent' es el default en el backend, no hace falta enviarlo.
      case CommunityTemplateSort.popular:
        params['sort'] = 'popular';
      case CommunityTemplateSort.relevance:
        params['sort'] = 'relevance';
    }
    final trimmedQuery = query?.trim() ?? '';
    if (trimmedQuery.isNotEmpty) params['query'] = trimmedQuery;
    final trimmedCategory = category?.trim() ?? '';
    if (trimmedCategory.isNotEmpty) params['category'] = trimmedCategory;

    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/community-templates',
    ).replace(queryParameters: params);
    http.Response res;
    final token = await folioCloudBearerToken();
    if (token != null && token.isNotEmpty) {
      res = await _springAuthorized((h) => http.get(uri, headers: h));
    } else {
      res = await http.get(uri, headers: const {'Accept': 'application/json'});
    }
    _ensureSpringOk(res);
    if (res.body.isEmpty) {
      return CommunityTemplateSearchResult(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw StateError('community-templates: expected a JSON object');
    }
    final itemsRaw = decoded['items'];
    final items = <CommunityTemplateEntry>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is! Map) continue;
        final e = CommunityTemplateEntry.fromSpringDto(
          item.map((k, v) => MapEntry('$k', v)),
        );
        if (e != null) items.add(e);
      }
    }
    return CommunityTemplateSearchResult(
      items: items,
      total: (decoded['total'] as num?)?.toInt() ?? items.length,
      page: (decoded['page'] as num?)?.toInt() ?? page,
      limit: (decoded['limit'] as num?)?.toInt() ?? limit,
    );
  }

  Future<FolioPageTemplate> downloadTemplate(
    String? downloadUrl, {
    String? storagePath,
  }) async {
    final path = (storagePath ?? '').trim().isNotEmpty
        ? storagePath!.trim()
        : _storagePathFromLogicalUrl(downloadUrl ?? '');
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

  /// Registra que una plantilla se ha usado/descargado (contador de
  /// popularidad). Requiere sesión iniciada igual que la propia descarga;
  /// nunca bloquea el flujo de uso si falla — es una métrica, no una ruta
  /// crítica.
  Future<void> recordDownload(String docId) async {
    try {
      final uri = Uri.parse(
        '${FolioBackendConfig.apiV1Prefix}/community-templates/$docId/downloads',
      );
      await _springAuthorized((h) => http.post(uri, headers: h));
    } catch (_) {
      // Silenciado a propósito: ver docstring.
    }
  }

  Future<void> reportTemplate(String docId, {String? reason}) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/community-templates/$docId/reports',
    );
    final body = <String, dynamic>{
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    final res = await _springAuthorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    _ensureSpringOk(res);
  }

  /// Solo queda como fallback de lectura para filas publicadas antes de que
  /// `storageDownloadUrl` dejara de generarse (ver `publishTemplate`); las
  /// entradas nuevas siempre traen `storagePath` directamente.
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

class CommunityTemplateApiException implements Exception {
  const CommunityTemplateApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CommunityTemplateApiException($code): $message';
}
