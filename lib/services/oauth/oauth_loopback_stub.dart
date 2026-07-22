String readOsEnv(String key) => '';

Future<String> awaitLoopbackOAuthCode({
  required int port,
  required String expectedState,
  Future<void>? whenCancelled,
}) async {
  throw UnsupportedError('OAuth loopback no disponible en esta plataforma.');
}

class OAuthCancelledException implements Exception {
  const OAuthCancelledException([this.message = 'oauth_cancelled']);
  final String message;
  @override
  String toString() => message;
}
