import 'dart:async';

import 'package:app_links/app_links.dart';

import 'oauth_loopback_io.dart' show OAuthCancelledException;
import 'oauth_mobile.dart';

/// Espera el redirect `folio://oauth/<provider>/callback?code=&state=`.
Future<String> awaitMobileOAuthCode({
  required String provider,
  required String expectedState,
  Future<void>? whenCancelled,
  Duration timeout = const Duration(minutes: 5),
}) async {
  final appLinks = AppLinks();
  final completer = Completer<String>();
  StreamSubscription<Uri>? sub;
  Timer? timer;

  void fail(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }

  void succeed(String code) {
    if (!completer.isCompleted) completer.complete(code);
  }

  Future<void> handle(Uri uri) async {
    if (!OAuthMobileRedirect.matchesProvider(uri, provider)) return;
    final state = (uri.queryParameters['state'] ?? '').trim();
    final code = (uri.queryParameters['code'] ?? '').trim();
    final err = (uri.queryParameters['error'] ?? '').trim();
    if (state != expectedState) return;
    if (err.isNotEmpty) {
      fail(const OAuthCancelledException());
      return;
    }
    if (code.isEmpty) return;
    succeed(code);
  }

  try {
    final initial = await appLinks.getInitialLink();
    if (initial != null) {
      await handle(initial);
    }
  } catch (_) {
    // Ignorar: no hay link inicial.
  }

  sub = appLinks.uriLinkStream.listen(
    (uri) {
      unawaited(handle(uri));
    },
    onError: fail,
  );

  if (whenCancelled != null) {
    unawaited(
      whenCancelled.then((_) {
        fail(const OAuthCancelledException());
      }),
    );
  }

  timer = Timer(timeout, () {
    fail(
      TimeoutException(
        'OAuth mobile timeout esperando folio://oauth/$provider/callback',
        timeout,
      ),
    );
  });

  try {
    return await completer.future;
  } finally {
    timer.cancel();
    await sub.cancel();
  }
}
