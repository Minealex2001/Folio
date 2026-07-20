import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'spotify_auth_errors.dart';

const _storageKey = 'folio_spotify_oauth';

void clearPendingOAuthResult() {
  html.window.localStorage.remove(_storageKey);
}

Future<String> awaitWebOAuthCode({
  required String expectedState,
  Future<void>? whenCancelled,
}) async {
  final completer = Completer<String>();

  void handleMap(Map<dynamic, dynamic> data) {
    if (data['type']?.toString() != 'folio-spotify-oauth') return;
    final state = (data['state']?.toString() ?? '').trim();
    if (state != expectedState) return;
    final err = (data['error']?.toString() ?? '').trim();
    final code = (data['code']?.toString() ?? '').trim();
    if (err.isNotEmpty) {
      if (!completer.isCompleted) {
        completer.completeError(const SpotifyAuthCancelledException());
      }
      return;
    }
    if (code.isNotEmpty && !completer.isCompleted) {
      completer.complete(code);
    }
  }

  void onMessage(html.Event raw) {
    if (raw is! html.MessageEvent) return;
    final data = raw.data;
    if (data is Map) {
      handleMap(Map<dynamic, dynamic>.from(data));
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) handleMap(Map<dynamic, dynamic>.from(decoded));
      } catch (_) {}
    }
  }

  void pollStorage() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        handleMap(Map<dynamic, dynamic>.from(decoded));
        html.window.localStorage.remove(_storageKey);
      }
    } catch (_) {}
  }

  html.window.addEventListener('message', onMessage);
  final timer = Timer.periodic(
    const Duration(milliseconds: 400),
    (_) => pollStorage(),
  );
  pollStorage();

  try {
    final futures = <Future<Object>>[
      completer.future,
      Future<Object>.delayed(
        const Duration(minutes: 5),
        () => throw TimeoutException(
          'Timeout esperando callback OAuth Spotify.',
        ),
      ),
    ];
    if (whenCancelled != null) {
      futures.add(
        whenCancelled.then<Object>(
          (_) => const SpotifyAuthCancelledException(),
        ),
      );
    }
    final result = await Future.any(futures);
    if (result is SpotifyAuthCancelledException) throw result;
    return result as String;
  } finally {
    timer.cancel();
    html.window.removeEventListener('message', onMessage);
    clearPendingOAuthResult();
  }
}
