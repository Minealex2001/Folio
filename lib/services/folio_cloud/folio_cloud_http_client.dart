import 'dart:async';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../app_logger.dart';

/// Timeout corto solo para el primer intento al host canónico cuando existe
/// respaldo (`*.folio.com.es` → Minealex). Evita esperar 20–120s ante un
/// bloqueo corporativo (DNS/TCP colgado).
const Duration kFolioHostFallbackProbeTimeout = Duration(seconds: 8);

/// Cliente HTTP compartido para todas las llamadas a Folio Cloud.
///
/// Las funciones top-level de `package:http` (`http.get`, `http.post`, ...)
/// crean y cierran un `http.Client` nuevo en cada llamada, lo que obliga a
/// repetir el handshake TCP+TLS por request. Reutilizar un único cliente
/// permite mantener conexiones keep-alive por host, lo que importa mucho
/// en redes con más latencia (VPN/proxy corporativo).
///
/// Además, si el origen canónico (`api.folio.com.es` / `api-beta…`) falla por
/// transporte/timeout, reintenta una vez contra `backendfolio` /
/// `backendfoliobeta` y deja sticky el host efectivo en [FolioBackendConfig].
final http.Client folioCloudHttpClient = FolioCloudHttpClient();

/// Wrapper con fallback de host ante bloqueos de red.
class FolioCloudHttpClient extends http.BaseClient {
  FolioCloudHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = FolioBackendConfig.applySessionHostOverride(request.url);
    final prepared =
        url == request.url ? request : _copyRequest(request, url);

    final canProbeFallback = !FolioBackendConfig.isUsingHostFallback &&
        FolioBackendConfig.fallbackBaseUrlForHost(url.host) != null;

    if (!canProbeFallback) {
      return _inner.send(prepared);
    }

    try {
      return await _inner
          .send(prepared)
          .timeout(kFolioHostFallbackProbeTimeout);
    } catch (e) {
      if (!_isHostBlockTransportError(e)) rethrow;
      final rewritten = FolioBackendConfig.activateHostFallbackForUri(url);
      if (rewritten == null) rethrow;

      AppLogger.warn(
        'API host unreachable; retrying on Minealex fallback',
        tag: 'cloud_sync',
        context: {
          'from': url.host,
          'to': rewritten.host,
          'error': '$e',
        },
      );

      final retryReq = _copyRequest(request, rewritten);
      return _inner.send(retryReq);
    }
  }

  @override
  void close() => _inner.close();
}

bool _isHostBlockTransportError(Object e) {
  if (e is TimeoutException) return true;
  if (e is http.ClientException) return true;
  final msg = '$e'.toLowerCase();
  return msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('connection reset') ||
      msg.contains('connection closed') ||
      msg.contains('connection abort') ||
      msg.contains('broken pipe') ||
      msg.contains('network is unreachable') ||
      msg.contains('software caused connection abort') ||
      msg.contains('timed out') ||
      msg.contains('handshake exception') ||
      msg.contains('certificate');
}

http.BaseRequest _copyRequest(http.BaseRequest request, Uri newUrl) {
  late final http.BaseRequest copy;
  if (request is http.Request) {
    copy = http.Request(request.method, newUrl)
      ..encoding = request.encoding
      ..bodyBytes = request.bodyBytes;
  } else if (request is http.MultipartRequest) {
    copy = http.MultipartRequest(request.method, newUrl)
      ..fields.addAll(request.fields)
      ..files.addAll(request.files);
  } else if (request is http.StreamedRequest) {
    // Cuerpo de un solo uso: no se puede reintentar de forma segura.
    throw http.ClientException(
      'Cannot retry streamed request on host fallback',
      request.url,
    );
  } else {
    throw http.ClientException(
      'Cannot retry ${request.runtimeType} on host fallback',
      request.url,
    );
  }
  request.headers.forEach((key, value) {
    copy.headers[key] = value;
  });
  copy.followRedirects = request.followRedirects;
  copy.maxRedirects = request.maxRedirects;
  copy.persistentConnection = request.persistentConnection;
  return copy;
}
