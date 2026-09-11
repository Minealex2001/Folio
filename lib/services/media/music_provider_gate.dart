import 'dart:async';

import '../../app/app_settings.dart';
import '../../models/active_music_provider.dart';
import '../../session/vault_session.dart';
import '../spotify/spotify_playback_controller.dart';
import '../ytmusic/ytmusic_playback_controller.dart';
import 'media_playback_router.dart';

/// Coordina la exclusividad Spotify ↔ YouTube Music.
class MusicProviderGate {
  MusicProviderGate._();
  static final MusicProviderGate instance = MusicProviderGate._();

  AppSettings? _settings;
  VaultSession? _session;

  void bind({
    required AppSettings settings,
    required VaultSession session,
  }) {
    if (!identical(_settings, settings)) {
      _settings?.removeListener(_sync);
      _settings = settings;
      settings.addListener(_sync);
    }
    _session = session;
    _migrateIfNeeded();
    _sync();
  }

  void unbind() {
    _settings?.removeListener(_sync);
    _settings = null;
    _session = null;
    YtMusicPlaybackController.instance.setActive(false);
    MediaPlaybackRouter.instance.setMusicProvider(ActiveMusicProvider.none);
  }

  Future<void> activate(ActiveMusicProvider provider) async {
    final settings = _settings;
    if (settings == null) return;
    if (provider == ActiveMusicProvider.spotify) {
      await YtMusicPlaybackController.instance.pause();
      YtMusicPlaybackController.instance.setActive(false);
    } else if (provider == ActiveMusicProvider.youtubeMusic) {
      try {
        await SpotifyPlaybackController.instance.pause();
      } catch (_) {}
      YtMusicPlaybackController.instance.setActive(true);
    } else {
      try {
        await SpotifyPlaybackController.instance.pause();
      } catch (_) {}
      await YtMusicPlaybackController.instance.pause();
      YtMusicPlaybackController.instance.setActive(false);
    }
    await settings.setActiveMusicProvider(provider);
    MediaPlaybackRouter.instance.setMusicProvider(provider);
  }

  void _migrateIfNeeded() {
    final settings = _settings;
    final session = _session;
    if (settings == null || session == null) return;
    if (settings.activeMusicProvider != ActiveMusicProvider.none) return;
    if (session.spotifyConnections.isNotEmpty) {
      unawaited(settings.setActiveMusicProvider(ActiveMusicProvider.spotify));
    } else if (session.ytMusicConnections.isNotEmpty) {
      unawaited(
        settings.setActiveMusicProvider(ActiveMusicProvider.youtubeMusic),
      );
    }
  }

  void _sync() {
    final provider =
        _settings?.activeMusicProvider ?? ActiveMusicProvider.none;
    YtMusicPlaybackController.instance
        .setActive(provider == ActiveMusicProvider.youtubeMusic);
    MediaPlaybackRouter.instance.setMusicProvider(provider);
  }
}
