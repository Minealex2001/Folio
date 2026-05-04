/// Compilación web: [folioHttpsCallableUsesHttp] es false; no se usa este POST.
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

Future<FolioCallableHttpResponse> folioCallableHttpPost({
  required Uri uri,
  required String body,
  required String bearerToken,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 120),
}) async {
  throw UnsupportedError('folioCallableHttpPost is not used on web');
}
