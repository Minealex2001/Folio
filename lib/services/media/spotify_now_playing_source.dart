import 'package:url_launcher/url_launcher.dart';

import '../../features/workspace/editor/folio_spotify.dart';
import '../spotify/spotify_api_client.dart';
import '../spotify/spotify_playback_controller.dart';
import 'now_playing_snapshot.dart';
import 'now_playing_source.dart';

/// Adaptador de [SpotifyPlaybackController] a [NowPlayingSource].
class SpotifyNowPlayingSource extends NowPlayingSource {
  SpotifyNowPlayingSource({SpotifyPlaybackController? controller})
      : _playback = controller ?? SpotifyPlaybackController.instance {
    _playback.addListener(_onPlaybackChanged);
  }

  final SpotifyPlaybackController _playback;

  void _onPlaybackChanged() => notifyListeners();

  @override
  NowPlayingSourceId get id => NowPlayingSourceId.spotify;

  @override
  bool get isAvailable => _playback.hasConnection;

  @override
  bool get hasActiveContent {
    final s = _playback.snapshot;
    if (s.premiumRequired || s.noActiveDevice) return false;
    return s.isPlaying ||
        (s.trackName != null && s.trackName!.trim().isNotEmpty);
  }

  @override
  NowPlayingSnapshot get snapshot {
    final s = _playback.snapshot;
    final conn = _playback.activeConnection;
    final idleTitle = conn?.focusPlaylistName?.trim();
    return NowPlayingSnapshot(
      title: s.trackName,
      artist: s.artistName,
      albumArtUrl: s.albumArtUrl,
      isPlaying: s.isPlaying,
      progressMs: s.progressMs,
      durationMs: s.durationMs,
      volumePercent: s.volumePercent,
      sourceId: NowPlayingSourceId.spotify,
      sourceLabel: 'Spotify',
      externalUrl: s.trackUri,
      canSeek: true,
      canSkip: true,
      canSetVolume: true,
      canOpenExternal: true,
      canInsertBlock: false,
      premiumRequired: s.premiumRequired,
      noActiveDevice: s.noActiveDevice,
      noContent: s.noContent,
      idleTitle: (idleTitle != null && idleTitle.isNotEmpty) ? idleTitle : null,
    );
  }

  /// Acceso al snapshot Spotify nativo (bloques / API existentes).
  SpotifyPlaybackSnapshot get spotifySnapshot => _playback.snapshot;

  @override
  Future<void> togglePlayPause() => _playback.togglePlayPause();

  @override
  Future<void> skipNext() => _playback.skipNext();

  @override
  Future<void> skipPrevious() => _playback.skipPrevious();

  @override
  Future<void> seek(int positionMs) => _playback.seek(positionMs);

  @override
  Future<void> setVolume(int volumePercent) =>
      _playback.setVolume(volumePercent);

  @override
  Future<void> pause() => _playback.pause();

  @override
  Future<void> openExternal() async {
    final trackUri = _playback.snapshot.trackUri;
    final ref = folioSpotifyRefFromUrl(trackUri);
    final web = ref != null
        ? Uri.https('open.spotify.com', '/${ref.type}/${ref.id}')
        : Uri.https('open.spotify.com', '/');
    try {
      final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    try {
      await launchUrl(web, mode: LaunchMode.platformDefault);
    } catch (_) {}
    if (trackUri != null && trackUri.startsWith('spotify:')) {
      final native = Uri.tryParse(trackUri);
      if (native != null) {
        try {
          await launchUrl(native, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
  }

  @override
  void addListenerRef() => _playback.addListenerRef();

  @override
  void removeListenerRef() => _playback.removeListenerRef();

  @override
  void dispose() {
    _playback.removeListener(_onPlaybackChanged);
    super.dispose();
  }
}
