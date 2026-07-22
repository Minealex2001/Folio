import 'dart:convert';
import 'dart:io';

/// Utilidades HTTP compartidas por los bridges locales (45831 / 45832).
abstract final class LocalBridgeHttp {
  static const maxBodyBytes = 8 * 1024 * 1024;

  static Future<HttpServer> bindLoopback(int port) async {
    try {
      return await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
    } catch (e) {
      throw StateError(
        'No se pudo abrir el puerto local $port. '
        'Comprueba que no esté en uso por otra instancia de Folio. '
        'Detalle: $e',
      );
    }
  }

  static void applyCors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, X-Folio-App-Id, X-Folio-App-Name, '
      'X-Folio-App-Version, X-Folio-Integration-Version',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PATCH, OPTIONS',
    );
  }

  static Future<void> writeJson(
    HttpResponse response,
    int statusCode,
    Object body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  static Future<List<int>> readBodyBytes(
    HttpRequest request, {
    int maxBytes = maxBodyBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw StateError('body_too_large');
      }
    }
    return builder.takeBytes();
  }
}
