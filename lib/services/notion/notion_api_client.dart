import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../integrations/integration_api_exception.dart';

class NotionApiException extends IntegrationApiException {
  const NotionApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.uri,
    super.method,
  });

  @override
  String get exceptionName => 'NotionApiException';
}

/// Resultado de `/v1/search`: una página o base de datos que el usuario
/// compartió con la Public Connection durante el OAuth (Notion nunca expone
/// más que eso — ver developers.notion.com/guides/get-started/authorization).
class NotionSearchResultItem {
  NotionSearchResultItem({
    required this.id,
    required this.object,
    required this.title,
    this.iconEmoji,
    this.iconUrl,
    this.parentType,
    this.parentId,
  });

  final String id;

  /// `page` o `database`.
  final String object;
  final String title;
  final String? iconEmoji;
  final String? iconUrl;
  final String? parentType;
  final String? parentId;

  bool get isDatabase => object == 'database';

  static NotionSearchResultItem fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final object = json['object'] as String? ?? 'page';
    final title = _extractTitle(json, isDatabase: object == 'database');
    String? iconEmoji;
    String? iconUrl;
    final icon = json['icon'];
    if (icon is Map) {
      final type = icon['type'] as String?;
      if (type == 'emoji') {
        iconEmoji = icon['emoji'] as String?;
      } else if (type == 'external') {
        iconUrl = (icon['external'] as Map?)?['url'] as String?;
      } else if (type == 'file') {
        iconUrl = (icon['file'] as Map?)?['url'] as String?;
      }
    }
    String? parentType;
    String? parentId;
    final parent = json['parent'];
    if (parent is Map) {
      parentType = parent['type'] as String?;
      if (parentType != null) {
        parentId = parent[parentType] as String?;
      }
    }
    return NotionSearchResultItem(
      id: id,
      object: object,
      title: title,
      iconEmoji: iconEmoji,
      iconUrl: iconUrl,
      parentType: parentType,
      parentId: parentId,
    );
  }

  static String _extractTitle(Map<String, dynamic> json, {required bool isDatabase}) {
    // Las páginas guardan el título en `properties.title` (o cualquier
    // propiedad con type=='title'); las bases de datos lo guardan en un
    // array `title` de rich_text a nivel raíz.
    if (isDatabase) {
      final rich = json['title'];
      if (rich is List) {
        return _plainTextFromRichText(rich);
      }
      return '';
    }
    final properties = json['properties'];
    if (properties is Map) {
      for (final entry in properties.entries) {
        final value = entry.value;
        if (value is Map && value['type'] == 'title') {
          final rich = value['title'];
          if (rich is List) {
            return _plainTextFromRichText(rich);
          }
        }
      }
    }
    return '';
  }

  static String _plainTextFromRichText(List rich) {
    final buffer = StringBuffer();
    for (final r in rich) {
      if (r is Map) {
        final plain = r['plain_text'] as String?;
        if (plain != null) buffer.write(plain);
      }
    }
    return buffer.toString();
  }
}

class NotionApiClient {
  NotionApiClient({required this.accessToken, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String accessToken;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 30);

  /// Tope de resultados de `/v1/search` para no colgar el picker con
  /// workspaces enormes. Si se trunca, la UI del picker debe avisar.
  static const int searchResultCap = 500;

  /// Tope defensivo de recursión de bloques hijos (workspace mal formado /
  /// referencia circular no debería colgar el import).
  static const int _maxBlockDepth = 40;

  Future<Map<String, dynamic>> _proxy({
    required String method,
    required String path,
    Object? body,
  }) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/integrations/notion/api-proxy');
    final http.Response resp;
    try {
      resp = await _http
          .post(
            uri,
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'method': method,
              'path': path,
              'accessToken': accessToken,
              if (body != null) 'body': body,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      throw NotionApiException('Fallo de red hacia el proxy de Notion: $e', uri: path, method: method);
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw NotionApiException(
        'El proxy de Notion respondió con error.',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: path,
        method: method,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (e) {
      throw NotionApiException('Respuesta del proxy no es JSON válido.', uri: path, method: method);
    }
    if (decoded is! Map) {
      throw NotionApiException('Forma de respuesta del proxy inesperada.', uri: path, method: method);
    }
    final envelope = Map<String, dynamic>.from(decoded);
    final status = (envelope['status'] as num?)?.toInt() ?? 0;
    final respBody = envelope['body'];
    if (status < 200 || status >= 300) {
      throw NotionApiException(
        'Notion devolvió un error.',
        statusCode: status,
        body: respBody == null ? null : jsonEncode(respBody),
        uri: path,
        method: method,
      );
    }
    if (respBody is! Map) {
      throw NotionApiException('Forma de respuesta de Notion inesperada.', statusCode: status, uri: path, method: method);
    }
    return Map<String, dynamic>.from(respBody);
  }

  /// Lista páginas y bases de datos compartidas con la integración
  /// (`POST /v1/search`), paginando hasta [searchResultCap].
  ///
  /// Devuelve también si el resultado se truncó, para que el picker pueda
  /// avisar en vez de dar una lista silenciosamente incompleta.
  Future<({List<NotionSearchResultItem> items, bool truncated})> search() async {
    final items = <NotionSearchResultItem>[];
    String? cursor;
    bool truncated = false;
    while (true) {
      final page = await _proxy(
        method: 'POST',
        path: '/v1/search',
        body: {
          'page_size': 100,
          if (cursor != null) 'start_cursor': cursor,
          'sort': {'direction': 'descending', 'timestamp': 'last_edited_time'},
        },
      );
      final results = page['results'];
      if (results is List) {
        for (final r in results) {
          if (r is Map) {
            items.add(NotionSearchResultItem.fromJson(Map<String, dynamic>.from(r)));
            if (items.length >= searchResultCap) {
              truncated = (page['has_more'] == true) || results.length > items.length;
              return (items: items, truncated: truncated);
            }
          }
        }
      }
      if (page['has_more'] != true) break;
      final next = page['next_cursor'];
      if (next is! String || next.isEmpty) break;
      cursor = next;
    }
    return (items: items, truncated: truncated);
  }

  /// Recupera recursivamente los bloques hijos de [blockId]
  /// (`GET /v1/blocks/{id}/children`), anidando bajo la clave `_children` de
  /// cada bloque con `has_children == true`. No recurse dentro de
  /// `child_page`/`child_database` — esos son destinos propios que el picker
  /// gestiona por separado (el usuario decide si importarlos o no).
  Future<List<Map<String, dynamic>>> retrieveBlockChildrenRecursive(String blockId, {int depth = 0}) async {
    final children = <Map<String, dynamic>>[];
    String? cursor;
    while (true) {
      final page = await _proxy(
        method: 'GET',
        path: '/v1/blocks/$blockId/children?page_size=100${cursor != null ? '&start_cursor=$cursor' : ''}',
      );
      final results = page['results'];
      if (results is List) {
        for (final r in results) {
          if (r is! Map) continue;
          final block = Map<String, dynamic>.from(r);
          final type = block['type'] as String?;
          final hasChildren = block['has_children'] == true;
          if (hasChildren && depth < _maxBlockDepth && type != 'child_page' && type != 'child_database') {
            block['_children'] = await retrieveBlockChildrenRecursive(block['id'] as String? ?? '', depth: depth + 1);
          }
          children.add(block);
        }
      }
      if (page['has_more'] != true) break;
      final next = page['next_cursor'];
      if (next is! String || next.isEmpty) break;
      cursor = next;
    }
    return children;
  }

  /// Todas las filas de una base de datos (`POST /v1/databases/{id}/query`).
  Future<List<Map<String, dynamic>>> queryDatabaseAll(String databaseId) async {
    final rows = <Map<String, dynamic>>[];
    String? cursor;
    while (true) {
      final page = await _proxy(
        method: 'POST',
        path: '/v1/databases/$databaseId/query',
        body: {'page_size': 100, if (cursor != null) 'start_cursor': cursor},
      );
      final results = page['results'];
      if (results is List) {
        for (final r in results) {
          if (r is Map) rows.add(Map<String, dynamic>.from(r));
        }
      }
      if (page['has_more'] != true) break;
      final next = page['next_cursor'];
      if (next is! String || next.isEmpty) break;
      cursor = next;
    }
    return rows;
  }

  /// Esquema de una base de datos (`GET /v1/databases/{id}`) — nombre y tipo
  /// de cada propiedad, necesario para mapear a `FolioDatabaseData`.
  Future<Map<String, dynamic>> retrieveDatabase(String databaseId) {
    return _proxy(method: 'GET', path: '/v1/databases/$databaseId');
  }

  /// Página completa (título/icono/propiedades) — `GET /v1/pages/{id}`.
  Future<Map<String, dynamic>> retrievePage(String pageId) {
    return _proxy(method: 'GET', path: '/v1/pages/$pageId');
  }

  /// Descarga los bytes de una URL de adjunto (imagen/archivo/vídeo/audio de
  /// un bloque). A diferencia del resto de métodos, esto NO pasa por el
  /// proxy del backend: las URLs de adjuntos alojados por Notion son enlaces
  /// S3 firmados que ya incluyen su propia autorización (no llevan el
  /// access token de Notion), así que se piden directo. Usa el mismo
  /// [http.Client] inyectado que el resto del cliente para que sea testeable
  /// con un `MockClient` en vez de tocar la red real.
  Future<List<int>> downloadRaw(String url) async {
    final http.Response resp;
    try {
      resp = await _http.get(Uri.parse(url)).timeout(_timeout);
    } catch (e) {
      throw NotionApiException('Fallo de red descargando un adjunto: $e', uri: url, method: 'GET');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw NotionApiException('Descarga de adjunto falló.', statusCode: resp.statusCode, uri: url, method: 'GET');
    }
    return resp.bodyBytes;
  }
}
