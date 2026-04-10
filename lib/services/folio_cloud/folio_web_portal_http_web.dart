import 'package:http/http.dart' as http;

/// Respuesta HTTP mínima para el portal Next.js (web).
class FolioPortalHttpResult {
  FolioPortalHttpResult({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

Future<FolioPortalHttpResult> folioPortalHttpRequest({
  required Uri uri,
  required String method,
  Map<String, String>? headers,
  String? body,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 30),
}) async {
  final merged = <String, String>{
    ...?headers,
  };
  final timeout = connectionTimeout > bodyTimeout ? connectionTimeout : bodyTimeout;
  final client = http.Client();
  try {
    switch (method) {
      case 'POST':
        final r = await client
            .post(uri, headers: merged, body: body)
            .timeout(timeout);
        return FolioPortalHttpResult(statusCode: r.statusCode, body: r.body);
      case 'GET':
        final r = await client.get(uri, headers: merged).timeout(timeout);
        return FolioPortalHttpResult(statusCode: r.statusCode, body: r.body);
      default:
        throw ArgumentError.value(method, 'method');
    }
  } finally {
    client.close();
  }
}
