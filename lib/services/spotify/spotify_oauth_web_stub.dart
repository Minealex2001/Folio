/// Stub: puente OAuth Web no disponible fuera de navegador.
void clearPendingOAuthResult() {}

Future<String> awaitWebOAuthCode({
  required String expectedState,
  Future<void>? whenCancelled,
}) {
  throw UnsupportedError('OAuth Web solo disponible en el navegador.');
}
