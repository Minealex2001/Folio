import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/spotify_integration_state.dart';
import '../../session/vault_session.dart';
import 'spotify_api_client.dart';

/// Controlador global de reproducción Spotify (now playing + controles).
class SpotifyPlaybackController extends ChangeNotifier {
  SpotifyPlaybackController._();
  static final SpotifyPlaybackController instance = SpotifyPlaybackController._();

  VaultSession? _session;
  SpotifyApiClient? _client;
  Timer? _pollTimer;
  int _listeners = 0;

  SpotifyPlaybackSnapshot _snapshot = SpotifyPlaybackSnapshot.empty;
  String? _lastError;

  SpotifyPlaybackSnapshot get snapshot => _snapshot;
  String? get lastError => _lastError;
  bool get hasConnection => _client != null;
  SpotifyConnection? get activeConnection =>
      _session?.spotifyConnections.isNotEmpty == true
          ? _session!.spotifyConnections.first
          : null;

  void attachSession(VaultSession session) {
    if (identical(_session, session)) return;
    _session?.removeListener(_onSessionChanged);
    _session = session;
    session.addListener(_onSessionChanged);
    _rebuildClient();
  }

  void detachSession() {
    _session?.removeListener(_onSessionChanged);
    _session = null;
    _client = null;
    _stopPolling();
    _snapshot = SpotifyPlaybackSnapshot.empty;
    _lastError = null;
    notifyListeners();
  }

  void _onSessionChanged() {
    _rebuildClient();
  }

  void _rebuildClient() {
    final session = _session;
    if (session == null || session.state != VaultFlowState.unlocked) {
      _client = null;
      _stopPolling();
      return;
    }
    final conns = session.spotifyConnections;
    if (conns.isEmpty) {
      _client = null;
      _stopPolling();
      _snapshot = SpotifyPlaybackSnapshot.empty;
      notifyListeners();
      return;
    }
    final conn = conns.first;
    // Si el cliente ya existe y es para la misma cuenta, solo actualizamos el
    // token sin recrear el cliente (evita un bucle: refresh token →
    // upsertSpotifyConnection → notifyListeners → _rebuildClient → nuevo cliente).
    if (_client != null && _client!.connection.id == conn.id) {
      _client!.updateConnection(conn);
      return;
    }
    _client = SpotifyApiClient(
      connection: conn,
      onConnectionUpdated: (updated) async {
        session.upsertSpotifyConnection(updated);
        return updated;
      },
    );
    if (_listeners > 0) {
      unawaited(refresh());
      _startPolling();
    }
  }

  void addListenerRef() {
    _listeners++;
    if (_listeners == 1 && _client != null) {
      unawaited(refresh());
      _startPolling();
    }
  }

  void removeListenerRef() {
    if (_listeners > 0) _listeners--;
    if (_listeners == 0) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(refresh());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    try {
      // /me/player incluye volume_percent del dispositivo; better que currently-playing.
      final snap = await client.getPlaybackState();
      _snapshot = snap;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    try {
      if (_snapshot.isPlaying) {
        await client.pause();
      } else if (_snapshot.trackName == null || _snapshot.noContent) {
        // Nada en reproducción: preferir playlist de enfoque, si no reanudar.
        final focusUri = activeConnection?.focusPlaylistUri?.trim() ?? '';
        if (focusUri.isNotEmpty) {
          await client.play(contextUri: focusUri);
        } else {
          await client.play();
        }
      } else {
        await client.play();
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await refresh();
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> skipNext() async {
    final client = _client;
    if (client == null) return;
    await client.skipNext();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refresh();
  }

  Future<void> skipPrevious() async {
    final client = _client;
    if (client == null) return;
    await client.skipPrevious();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refresh();
  }

  Future<void> setVolume(int volumePercent) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    final percent = volumePercent.clamp(0, 100);
    // Actualización optimista para que el slider no salte.
    _snapshot = _snapshot.copyWith(volumePercent: percent);
    notifyListeners();
    try {
      await client.setVolume(percent);
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> seek(int positionMs) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    final duration = _snapshot.durationMs;
    final pos = positionMs.clamp(0, duration > 0 ? duration : positionMs);
    _snapshot = _snapshot.copyWith(progressMs: pos);
    notifyListeners();
    try {
      await client.seek(pos);
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startFocusPlaylist() async {
    final conn = activeConnection;
    final uri = conn?.focusPlaylistUri?.trim() ?? '';
    if (uri.isEmpty) return;
    // Si no hay cliente todavía, intentar construirlo ahora (puede pasar si
    // se activa el modo zen antes de que algún widget haya hecho addListenerRef).
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    // Asegurarse de que el polling está corriendo aunque no haya listeners de UI.
    if (_pollTimer == null) _startPolling();
    await client.play(contextUri: uri);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await refresh();
  }

  /// Reproduce un recurso Spotify (`track`/`episode` como uris; resto como context).
  Future<void> playSpotifyRef({
    required String type,
    required String id,
  }) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) {
      throw StateError('No Spotify connection');
    }
    if (_pollTimer == null) _startPolling();
    final spotifyUri = 'spotify:$type:$id';
    if (type == 'track' || type == 'episode') {
      await client.play(uris: [spotifyUri]);
    } else {
      await client.play(contextUri: spotifyUri);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await refresh();
  }

  Future<void> pause() async {
    final client = _client;
    if (client == null) return;
    await client.pause();
    await refresh();
  }

  SpotifyApiClient? apiClientForSettings() => _client;

  @override
  void dispose() {
    _stopPolling();
    detachSession();
    super.dispose();
  }
}
