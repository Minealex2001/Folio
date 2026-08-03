import '../ytmusic/ytmusic_playback_controller.dart';
import 'now_playing_snapshot.dart';
import 'now_playing_source.dart';

/// Adaptador de [YtMusicPlaybackController] a [NowPlayingSource].
class YtMusicNowPlayingSource extends NowPlayingSource {
  YtMusicNowPlayingSource({YtMusicPlaybackController? controller})
      : _playback = controller ?? YtMusicPlaybackController.instance {
    _playback.addListener(_onChanged);
  }

  final YtMusicPlaybackController _playback;

  void _onChanged() => notifyListeners();

  @override
  NowPlayingSourceId get id => NowPlayingSourceId.youtubeMusic;

  @override
  bool get isAvailable => _playback.hasConnection;

  @override
  bool get hasActiveContent {
    final s = _playback.snapshot;
    return s.track != null &&
        ((s.track!.title.trim().isNotEmpty) || s.isPlaying);
  }

  @override
  NowPlayingSnapshot get snapshot {
    final s = _playback.snapshot;
    final t = s.track;
    return NowPlayingSnapshot(
      title: t?.title,
      artist: t?.artistLabel,
      albumArtUrl: t?.albumArtUrl,
      isPlaying: s.isPlaying,
      progressMs: s.progressMs,
      durationMs: s.durationMs,
      sourceId: NowPlayingSourceId.youtubeMusic,
      sourceLabel: 'YouTube Music',
      externalUrl: t?.watchUrl,
      canSeek: true,
      canSkip: true,
      canSetVolume: false,
      canOpenExternal: true,
      canInsertBlock: false,
      noContent: s.noContent || t == null,
    );
  }

  @override
  Future<void> togglePlayPause() => _playback.togglePlayPause();

  @override
  Future<void> skipNext() => _playback.skipNext();

  @override
  Future<void> skipPrevious() => _playback.skipPrevious();

  @override
  Future<void> seek(int positionMs) => _playback.seek(positionMs);

  @override
  Future<void> setVolume(int volumePercent) async {}

  @override
  Future<void> pause() => _playback.pause();

  @override
  Future<void> openExternal() => _playback.openExternal();

  @override
  void addListenerRef() {}

  @override
  void removeListenerRef() {}
}
