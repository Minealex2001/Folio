import 'package:flutter/foundation.dart';

import '../../models/active_music_provider.dart';
import '../../session/vault_session.dart';
import 'now_playing_snapshot.dart';
import 'now_playing_source.dart';
import 'spotify_now_playing_source.dart';
import 'system_media_controller.dart';
import 'ytmusic_now_playing_source.dart';

/// Elige la fuente activa (proveedor de música + media del sistema).
class MediaPlaybackRouter extends ChangeNotifier {
  MediaPlaybackRouter._();
  static final MediaPlaybackRouter instance = MediaPlaybackRouter._();

  final SpotifyNowPlayingSource spotify = SpotifyNowPlayingSource();
  final YtMusicNowPlayingSource youtubeMusic = YtMusicNowPlayingSource();
  final SystemMediaController system = SystemMediaController.instance;

  VaultSession? _session;
  int _listeners = 0;
  NowPlayingSource? _active;
  ActiveMusicProvider _musicProvider = ActiveMusicProvider.none;

  NowPlayingSource? get activeSource => _active;
  ActiveMusicProvider get musicProvider => _musicProvider;

  NowPlayingSnapshot get snapshot =>
      _active?.snapshot ?? NowPlayingSnapshot.emptySpotify;

  bool get shouldShowBar {
    if (_spotifyLive || _ytLive) return true;
    if (system.isAvailable) return true;
    return false;
  }

  bool get _spotifyLive =>
      _musicProvider == ActiveMusicProvider.spotify && spotify.isAvailable;

  bool get _ytLive =>
      _musicProvider == ActiveMusicProvider.youtubeMusic &&
      youtubeMusic.isAvailable;

  void setMusicProvider(ActiveMusicProvider provider) {
    if (_musicProvider == provider) {
      _recompute();
      return;
    }
    _musicProvider = provider;
    _recompute();
  }

  void attachSession(VaultSession session) {
    if (identical(_session, session)) return;
    _session = session;
    system.attachSession(session);
    spotify.addListener(_recompute);
    youtubeMusic.addListener(_recompute);
    system.addListener(_recompute);
    _recompute();
  }

  void detachSession() {
    spotify.removeListener(_recompute);
    youtubeMusic.removeListener(_recompute);
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
      youtubeMusic.addListenerRef();
      system.addListenerRef();
    }
  }

  void removeListenerRef() {
    if (_listeners > 0) _listeners--;
    if (_listeners == 0) {
      spotify.removeListenerRef();
      youtubeMusic.removeListenerRef();
      system.removeListenerRef();
    }
  }

  void _recompute() {
    final next = _pickActive();
    _active = next;
    notifyListeners();
  }

  NowPlayingSource? _pickActive() {
    final systemOn = system.isAvailable;
    final systemActive = system.hasActiveContent;

    if (_spotifyLive && spotify.hasActiveContent) return spotify;
    if (_ytLive && youtubeMusic.hasActiveContent) return youtubeMusic;

    if (systemOn && systemActive) return system;

    if (_spotifyLive && !systemActive) return spotify;
    if (_ytLive && !systemActive) return youtubeMusic;

    if (systemOn) return system;
    if (_spotifyLive) return spotify;
    if (_ytLive) return youtubeMusic;
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

  Future<void> pauseSystemIfZenExit() async {
    final st = system.state;
    if (st.enabled && st.zenPauseOnExit) {
      await system.pause();
    }
  }
}
