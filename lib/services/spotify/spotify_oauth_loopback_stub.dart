/// Stub IO: OAuth loopback no aplica en Web.
String readOsEnv(String key) => '';

Future<String> awaitLoopbackOAuthCode({
  required int port,
  required String expectedState,
  Future<void>? whenCancelled,
}) {
  throw UnsupportedError('OAuth loopback no disponible en Web.');
}
