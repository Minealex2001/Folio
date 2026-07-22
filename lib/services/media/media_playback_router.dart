import 'package:flutter/foundation.dart';

import '../../session/vault_session.dart';
import 'now_playing_snapshot.dart';
import 'now_playing_source.dart';
import 'spotify_now_playing_source.dart';
import 'system_media_controller.dart';

/// Elige la fuente activa (Spotify vs media del sistema) para la barra única.
class MediaPlaybackRouter extends ChangeNotifier {
  MediaPlaybackRouter._();
  static final MediaPlaybackRouter instance = MediaPlaybackRouter._();

  final SpotifyNowPlayingSource spotify = SpotifyNowPlayingSource();
  final SystemMediaController system = SystemMediaController.instance;

  VaultSession? _session;
  int _listeners = 0;
  NowPlayingSource? _active;

  NowPlayingSource? get activeSource => _active;

  NowPlayingSnapshot get snapshot =>
      _active?.snapshot ?? NowPlayingSnapshot.emptySpotify;

  /// Mostrar la barra si hay Spotify conectado o media del sistema habilitada.
  bool get shouldShowBar {
    if (spotify.isAvailable) return true;
    if (system.isAvailable) return true;
    return false;
  }

  void attachSession(VaultSession session) {
    if (identical(_session, session)) return;
    _session = session;
    system.attachSession(session);
    spotify.addListener(_recompute);
    system.addListener(_recompute);
    _recompute();
  }

  void detachSession() {
    spotify.removeListener(_recompute);
    system.removeListener(_recompute);
    system.detachSession();
    _session = null;
    _active = null;
    notifyListeners();
  }

  void addListenerRef() {
    _listeners++;
    if (_listeners == 1) {
      spotify.addListenerRef();
      system.addListenerRef();
    }
  }

  void removeListenerRef() {
    if (_listeners > 0) _listeners--;
    if (_listeners == 0) {
      spotify.removeListenerRef();
      system.removeListenerRef();
    }
  }

  void _recompute() {
    final next = _pickActive();
    final changed = !identical(next, _active);
    _active = next;
    if (changed || true) {
      notifyListeners();
    }
  }

  NowPlayingSource? _pickActive() {
    final spotifyOn = spotify.isAvailable;
    final systemOn = system.isAvailable;
    final systemActive = system.hasActiveContent;

    // 1) Spotify con contenido activo → Spotify.
    if (spotifyOn && spotify.hasActiveContent) return spotify;

    // 2) Sistema con sesión no-Spotify → sistema.
    if (systemOn && systemActive) return system;

    // 3) Spotify conectado (idle) y sin sesión de sistema útil → Spotify idle.
    if (spotifyOn && !systemActive) return spotify;

    // 4) Solo sistema.
    if (systemOn) return system;

    if (spotifyOn) return spotify;
    return null;
  }

  Future<void> togglePlayPause() async {
    await _active?.togglePlayPause();
  }

  Future<void> skipNext() async {
    await _active?.skipNext();
  }

  Future<void> skipPrevious() async {
    await _active?.skipPrevious();
  }

  Future<void> seek(int positionMs) async {
    await _active?.seek(positionMs);
  }

  Future<void> setVolume(int volumePercent) async {
    await _active?.setVolume(volumePercent);
  }

  Future<void> openExternal() async {
    await _active?.openExternal();
  }

  Future<void> pauseActive() async {
    await _active?.pause();
  }

  /// Pausa media del sistema si está habilitado el zen pause (sin tocar Spotify).
  Future<void> pauseSystemIfZenExit() async {
    final st = system.state;
    if (st.enabled && st.zenPauseOnExit) {
      await system.pause();
    }
  }
}
