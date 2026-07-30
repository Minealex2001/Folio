export 'oauth_loopback_stub.dart' show OAuthCancelledException;

Future<String> awaitMobileOAuthCode({
  required String provider,
  required String expectedState,
  Future<void>? whenCancelled,
  Duration timeout = const Duration(minutes: 5),
}) async {
  throw UnsupportedError('OAuth deep link no disponible en esta plataforma.');
}
