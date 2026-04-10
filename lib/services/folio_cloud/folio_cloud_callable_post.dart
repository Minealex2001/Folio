import 'dart:convert';
import 'dart:io';

/// Respuesta mínima POST (solo cabeceras permitidas en el protocolo callable).
class FolioCallableHttpResponse {
  FolioCallableHttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// POST al endpoint callable con **solo** `Content-Type` y `Authorization`.
///
/// La spec de Firebase rechaza cabeceras extra; `package:http` añade
/// `User-Agent` y puede provocar respuestas no JSON en Windows/Linux.
Future<FolioCallableHttpResponse> folioCallableHttpPost({
  required Uri uri,
  required String body,
  required String bearerToken,
}) async {
  final client = HttpClient();
  client.userAgent = null;
  try {
    final req = await client.postUrl(uri);
    req.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $bearerToken',
    );
    req.write(body);
    final res = await req.close();
    final headers = <String, String>{};
    res.headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headers[name.toLowerCase()] = values.first;
      }
    });
    final text = await utf8.decoder.bind(res).join();
    return FolioCallableHttpResponse(
      statusCode: res.statusCode,
      body: text,
      headers: headers,
    );
  } finally {
    client.close(force: true);
  }
}
