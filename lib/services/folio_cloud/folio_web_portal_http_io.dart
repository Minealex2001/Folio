import 'dart:convert';
import 'dart:io';

/// Respuesta HTTP mínima para el portal Next.js (VM / escritorio).
class FolioPortalHttpResult {
  FolioPortalHttpResult({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

/// POST/GET sin User-Agent extra (Firebase callable en Windows es quisquilloso;
/// mantenemos el mismo criterio aquí).
Future<FolioPortalHttpResult> folioPortalHttpRequest({
  required Uri uri,
  required String method,
  Map<String, String>? headers,
  String? body,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 30),
}) async {
  final client = HttpClient();
  client.userAgent = null;
  client.connectionTimeout = connectionTimeout;
  try {
    final HttpClientRequest req;
    switch (method) {
      case 'POST':
        req = await client.postUrl(uri);
        break;
      case 'GET':
        req = await client.getUrl(uri);
        break;
      default:
        throw ArgumentError.value(method, 'method');
    }
    headers?.forEach((name, value) {
      req.headers.set(name, value);
    });
    if (body != null) {
      req.write(body);
    }
    final res = await req.close();
    final text = await utf8.decoder.bind(res).timeout(bodyTimeout).join();
    return FolioPortalHttpResult(statusCode: res.statusCode, body: text);
  } finally {
    client.close(force: true);
  }
}
