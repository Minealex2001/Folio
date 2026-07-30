import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'folio_cloud_http_client.dart';
import 'folio_cloud_identity.dart';

/// Timeout para PUT/GET de objetos (pueden ser blobs grandes en redes lentas).
const Duration _kStorageObjectTimeout = Duration(seconds: 120);

/// Timeout para HEAD/DELETE (metadata ligera, sin cuerpo grande esperado).
const Duration _kStorageMetaTimeout = Duration(seconds: 20);

/// Cabecera con la ruta lógica del objeto (misma convención Firebase Storage).
const String kFolioStoragePathHeader = 'X-Folio-Storage-Path';

class FolioSpringStorageException implements Exception {
  FolioSpringStorageException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() =>
      'FolioSpringStorageException(status=$statusCode, body=$body)';
}

Uri _objectsUri() => Uri.parse('${FolioBackendConfig.apiV1Prefix}/storage/objects');

Future<Map<String, String>> _authHeaders({
  String? contentType,
  required String path,
  bool forceRefresh = false,
}) async {
  final token = await folioCloudBearerToken(forceRefresh: forceRefresh);
  if (token == null || token.isEmpty) {
    throw StateError('Not signed in (Spring storage)');
  }
  return <String, String>{
    'Authorization': 'Bearer $token',
    kFolioStoragePathHeader: path,
    if (contentType != null && contentType.isNotEmpty) 'Content-Type': contentType,
  };
}

Future<T> _withAuthRetry<T>(Future<T> Function(bool forceRefresh) run) async {
  try {
    return await run(false);
  } on FolioSpringStorageException catch (e) {
    if (e.statusCode != 401) rethrow;
    return await run(true);
  }
}

void _ensureOk(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  throw FolioSpringStorageException(res.statusCode, res.body);
}

Future<void> folioSpringStoragePutData(String path, Uint8List data) async {
  await _withAuthRetry((force) async {
    final headers = await _authHeaders(
      contentType: 'application/octet-stream',
      path: path,
      forceRefresh: force,
    );
    final res = await folioCloudHttpClient
        .put(_objectsUri(), headers: headers, body: data)
        .timeout(_kStorageObjectTimeout);
    _ensureOk(res);
  });
}

Future<Uint8List?> folioSpringStorageGetData(String path, int maxBytes) async {
  return _withAuthRetry((force) async {
    final headers = await _authHeaders(path: path, forceRefresh: force);
    final res = await folioCloudHttpClient
        .get(_objectsUri(), headers: headers)
        .timeout(_kStorageObjectTimeout);
    if (res.statusCode == 404) return null;
    _ensureOk(res);
    final bytes = res.bodyBytes;
    if (bytes.length > maxBytes) {
      throw FolioSpringStorageException(
        413,
        'Object exceeds maxBytes=$maxBytes (got ${bytes.length})',
      );
    }
    return Uint8List.fromList(bytes);
  });
}

Future<bool> folioSpringStorageObjectExists(String path) async {
  return _withAuthRetry((force) async {
    final headers = await _authHeaders(path: path, forceRefresh: force);
    final req = http.Request('HEAD', _objectsUri())..headers.addAll(headers);
    final streamed = await folioCloudHttpClient
        .send(req)
        .timeout(_kStorageMetaTimeout);
    final code = streamed.statusCode;
    await streamed.stream.drain<void>();
    if (code == 404) return false;
    if (code >= 200 && code < 300) return true;
    throw FolioSpringStorageException(code, '');
  });
}

/// `DELETE /api/v1/storage/objects` — 404 se trata como éxito.
Future<void> folioSpringStorageDelete(String path) async {
  await _withAuthRetry((force) async {
    final headers = await _authHeaders(path: path, forceRefresh: force);
    final res = await folioCloudHttpClient
        .delete(_objectsUri(), headers: headers)
        .timeout(_kStorageMetaTimeout);
    if (res.statusCode == 404) return;
    _ensureOk(res);
  });
}
