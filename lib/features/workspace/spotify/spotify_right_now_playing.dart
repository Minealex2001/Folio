import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/media/media_playback_router.dart';
import '../../../services/media/now_playing_snapshot.dart';
import '../../../services/spotify/spotify_api_client.dart';
import '../../../services/spotify/spotify_art_color.dart';
import '../../../services/spotify/spotify_lyrics_service.dart';
import '../../../services/spotify/spotify_local_device_service.dart';
import '../../../services/spotify/spotify_playback_controller.dart';
import '../../../services/ytmusic/ytmusic_playback_controller.dart';

const _kSpotifyGreen = Color(0xFF1DB954);

/// Reveal animado del Now Playing completo (slide + fade) sobre el sidebar.
class SpotifyFullPlayerReveal extends StatelessWidget {
  const SpotifyFullPlayerReveal({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  static const _in = Duration(milliseconds: 360);
  static const _out = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSwitcher(
        duration: _in,
        reverseDuration: _out,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: visible
            ? KeyedSubtree(
                key: const ValueKey('spotify-full-player-open'),
                child: child,
              )
            : const SizedBox.shrink(
                key: ValueKey('spotify-full-player-closed'),
              ),
      ),
    );
  }
}

/// Panel Now Playing (rail derecho wide, overlay de sidebar, u overlay phone).
class SpotifyRightNowPlaying extends StatefulWidget {
  const SpotifyRightNowPlaying({
    super.key,
    this.asOverlay = false,
    this.onClose,
  });

  final bool asOverlay;
  final VoidCallback? onClose;

  @override
  State<SpotifyRightNowPlaying> createState() => _SpotifyRightNowPlayingState();
}

class _SpotifyRightNowPlayingState extends State<SpotifyRightNowPlaying>
    with TickerProviderStateMixin {
  final _lyrics = SpotifyLyricsService();
  final _lyricsScroll = ScrollController();

  Color? _artColor;
  String? _artKey;
  List<SpotifyLyricLine> _lyricLines = const [];
  bool _lyricsLoading = false;
  bool _lyricsExpanded = false;
  String? _lyricsTrackKey;

  double? _progressDrag;
  Timer? _progressTicker;
  int _localProgressMs = 0;
  DateTime? _progressAnchor;
  int _lastLyricIndex = -1;

  late final AnimationController _enter;
  late final Animation<double> _artFade;
  late final Animation<double> _artScale;
  late final Animation<double> _metaFade;
  late final Animation<Offset> _metaSlide;
  late final Animation<double> _lyricsFade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _artFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _artScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _metaFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.18, 0.78, curve: Curves.easeOut),
    );
    _metaSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.18, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _lyricsFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.38, 1.0, curve: Curves.easeOut),
    );

    MediaPlaybackRouter.instance.addListenerRef();
    MediaPlaybackRouter.instance.addListener(_onPlayback);
    SpotifyPlaybackController.instance.addListenerRef();
    SpotifyPlaybackController.instance.addListener(_onPlayback);
    _syncProgress();
    _maybeArtColor();
    unawaited(_loadLyrics());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enter.forward();
    });
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    _enter.dispose();
    _lyricsScroll.dispose();
    MediaPlaybackRouter.instance.removeListener(_onPlayback);
    MediaPlaybackRouter.instance.removeListenerRef();
    SpotifyPlaybackController.instance.removeListener(_onPlayback);
    SpotifyPlaybackController.instance.removeListenerRef();
    super.dispose();
  }

  void _onPlayback() {
    _syncProgress();
    _maybeArtColor();
    unawaited(_loadLyrics());
    _scrollLyricsToActive();
    if (mounted) setState(() {});
  }

  MediaPlaybackRouter get _router => MediaPlaybackRouter.instance;
  NowPlayingSnapshot get _snap => _router.snapshot;
  SpotifyPlaybackSnapshot get _spotifySnap =>
      SpotifyPlaybackController.instance.snapshot;

  void _syncProgress() {
    if (_progressDrag != null) return;
    final snap = _snap;
    final base = snap.progressMs;
    _localProgressMs = base;
    _progressAnchor = DateTime.now();
    _progressTicker?.cancel();
    if (snap.isPlaying && snap.durationMs > 0) {
      final duration = snap.durationMs;
      _progressTicker = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted || _progressDrag != null) return;
        if (!_snap.isPlaying) {
          _progressTicker?.cancel();
          return;
        }
        final elapsed =
            DateTime.now().difference(_progressAnchor!).inMilliseconds;
        final next = (base + elapsed).clamp(0, duration);
        if (next != _localProgressMs) {
          setState(() => _localProgressMs = next);
          _scrollLyricsToActive();
        }
      });
    }
  }

  void _maybeArtColor() {
    final url = _snap.albumArtUrl;
    if (url == _artKey) return;
    _artKey = url;
    if (url == null || url.isEmpty) {
      setState(() => _artColor = null);
      return;
    }
    extractSpotifyArtColor(url).then((c) {
      if (!mounted || _artKey != url) return;
      setState(() => _artColor = c);
    });
  }

  Future<void> _loadLyrics() async {
    final snap = _snap;
    if (!snap.hasTrack) {
      _lyricLines = const [];
      return;
    }
    final key =
        '${snap.title}|${snap.artist}|${snap.durationMs}|${_spotifySnap.trackId}';
    if (key == _lyricsTrackKey) return;
    _lyricsTrackKey = key;
    setState(() => _lyricsLoading = true);
    final lines = await _lyrics.fetchSyncedLyrics(
      trackId: _spotifySnap.trackId ?? key,
      title: snap.title ?? '',
      artist: snap.artist ?? '',
      durationMs: snap.durationMs,
    );
    if (!mounted || _lyricsTrackKey != key) return;
    setState(() {
      _lyricLines = lines;
      _lyricsLoading = false;
      _lastLyricIndex = -1;
    });
  }

  void _scrollLyricsToActive() {
    if (_lyricLines.isEmpty) return;
    final idx =
        SpotifyLyricsService.activeLineIndex(_lyricLines, _localProgressMs);
    if (idx < 0 || idx == _lastLyricIndex) return;
    _lastLyricIndex = idx;
    void doScroll() {
      if (!mounted || !_lyricsScroll.hasClients) return;
      // padding vertical 6*2 + ~16–20 line ≈ 32–36
      const lineExtent = 34.0;
      final viewport = _lyricsScroll.position.viewportDimension;
      final target = (idx * lineExtent) - (viewport * 0.35);
      _lyricsScroll.animateTo(
        target.clamp(0.0, _lyricsScroll.position.maxScrollExtent),
        duration: FolioMotion.short2,
        curve: FolioMotion.emphasized,
      );
    }

    if (_lyricsScroll.hasClients) {
      doScroll();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    }
  }

  String _formatMs(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 999 * 60);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openExternal() async {
    final url = _snap.externalUrl;
    Uri web;
    if (url != null && url.startsWith('spotify:')) {
      final parts = url.split(':');
      web = parts.length >= 3
          ? Uri.https('open.spotify.com', '/${parts[1]}/${parts[2]}')
          : Uri.https('open.spotify.com', '/');
    } else if (url != null && url.startsWith('http')) {
      web = Uri.tryParse(url) ?? Uri.https('open.spotify.com', '/');
    } else {
      web = Uri.https('open.spotify.com', '/');
    }
    if (!await launchUrl(web, mode: LaunchMode.externalApplication)) {
      await launchUrl(web, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _showQueue(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (_snap.sourceId == NowPlayingSourceId.youtubeMusic) {
      final tracks = YtMusicPlaybackController.instance.getQueue();
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.spotifyNowPlayingQueue,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (tracks.isEmpty)
                Text(l10n.spotifyNowPlayingNoQueue)
              else
                ...tracks.map(
                  (t) => ListTile(
                    title: Text(t.title),
                    subtitle: Text(t.artistLabel),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(
                        YtMusicPlaybackController.instance.playTrack(t),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _QueueSheet(l10n: l10n),
    );
  }

  Future<void> _showDevices(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _DevicesSheet(l10n: l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final snap = _snap;
    final spotify = _spotifySnap;
    final bg = _artColor != null
        ? spotifyArtColorBackground(_artColor!, darkness: 0.45)
        : scheme.surfaceContainerHighest;
    final duration = snap.durationMs > 0 ? snap.durationMs.toDouble() : 1.0;
    final progress =
        (_progressDrag ?? _localProgressMs.toDouble()).clamp(0.0, duration);
    final canSeek = snap.canSeek && snap.hasTrack && snap.durationMs > 0;
    final onFolio = snap.sourceId == NowPlayingSourceId.spotify &&
        SpotifyLocalDeviceService.instance.isReady;
    final isYt = snap.sourceId == NowPlayingSourceId.youtubeMusic;

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      color: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeTransition(
              opacity: _metaFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                child: Row(
                  children: [
                    if (widget.asOverlay)
                      IconButton(
                        tooltip: l10n.spotifyNowPlayingCloseOverlay,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        onPressed: widget.onClose,
                      ),
                    Expanded(
                      child: Text(
                        snap.hasTrack
                            ? l10n.spotifyNowPlayingContext
                            : l10n.spotifyReadyIdle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.spotifyOpenInSpotify,
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: () => unawaited(_openExternal()),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: _lyricsExpanded ? 2 : 3,
              child: FadeTransition(
                opacity: _artFade,
                child: ScaleTransition(
                  scale: _artScale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(FolioRadius.md),
                          child: snap.albumArtUrl != null
                              ? Image.network(
                                  snap.albumArtUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _fallbackArt(scheme),
                                )
                              : snap.albumArtBytes != null
                                  ? Image.memory(
                                      snap.albumArtBytes!,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  : _fallbackArt(scheme),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            FadeTransition(
              opacity: _metaFade,
              child: SlideTransition(
                position: _metaSlide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snap.hasTrack
                        ? (snap.title ?? '')
                        : l10n.spotifyNothingPlaying,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((snap.artist ?? '').isNotEmpty)
                    Text(
                      snap.artist!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  if (onFolio) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.spotifyLibraryPlayingOnFolio,
                      style: const TextStyle(
                        color: _kSpotifyGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: progress,
                      min: 0,
                      max: duration,
                      onChanged: !canSeek
                          ? null
                          : (v) => setState(() => _progressDrag = v),
                      onChangeEnd: !canSeek
                          ? null
                          : (v) {
                              setState(() {
                                _progressDrag = null;
                                _localProgressMs = v.round();
                                _progressAnchor = DateTime.now();
                              });
                              unawaited(_router.seek(v.round()));
                            },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          _formatMs(progress.round()),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatMs(snap.durationMs),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: l10n.spotifyNowPlayingShuffle,
                    onPressed: isYt
                        ? null
                        : () => unawaited(
                              SpotifyPlaybackController.instance
                                  .setShuffle(!spotify.shuffleState),
                            ),
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: !isYt && spotify.shuffleState
                          ? _kSpotifyGreen
                          : scheme.onSurface,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.spotifySkipPrevious,
                    onPressed: !snap.canSkip
                        ? null
                        : () => unawaited(_router.skipPrevious()),
                    icon: const Icon(Icons.skip_previous_rounded, size: 32),
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => unawaited(_router.togglePlayPause()),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          snap.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.spotifySkipNext,
                    onPressed: !snap.canSkip
                        ? null
                        : () => unawaited(_router.skipNext()),
                    icon: const Icon(Icons.skip_next_rounded, size: 32),
                  ),
                  IconButton(
                    tooltip: l10n.spotifyNowPlayingRepeat,
                    onPressed: isYt
                        ? null
                        : () => unawaited(
                              SpotifyPlaybackController.instance.cycleRepeat(),
                            ),
                    icon: Icon(
                      spotify.repeatState == 'track'
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: !isYt && spotify.repeatState != 'off'
                          ? _kSpotifyGreen
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.spotifyNowPlayingDevices,
                    onPressed: isYt
                        ? null
                        : () => unawaited(_showDevices(context)),
                    icon: const Icon(Icons.speaker_group_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.spotifyOpenInSpotify,
                    onPressed: () => unawaited(_openExternal()),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.spotifyNowPlayingQueue,
                    onPressed: () => unawaited(_showQueue(context)),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                ],
              ),
            ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: _lyricsExpanded ? 3 : 2,
              child: FadeTransition(
                opacity: _lyricsFade,
                child: _LyricsPane(
                  l10n: l10n,
                  scheme: scheme,
                  artColor: _artColor,
                  lines: _lyricLines,
                  loading: _lyricsLoading,
                  progressMs: _localProgressMs,
                  expanded: _lyricsExpanded,
                  scrollController: _lyricsScroll,
                  onToggleExpand: () {
                    setState(() => _lyricsExpanded = !_lyricsExpanded);
                    _lastLyricIndex = -1;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollLyricsToActive();
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.asOverlay) {
      return Material(color: bg, child: body);
    }
    return SizedBox(
      width: 360,
      child: Material(
        color: bg,
        elevation: 0,
        child: body,
      ),
    );
  }

  Widget _fallbackArt(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Icon(
        Icons.music_note_rounded,
        size: 64,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _LyricsPane extends StatelessWidget {
  const _LyricsPane({
    required this.l10n,
    required this.scheme,
    required this.lines,
    required this.loading,
    required this.progressMs,
    required this.expanded,
    required this.scrollController,
    required this.onToggleExpand,
    this.artColor,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final Color? artColor;
  final List<SpotifyLyricLine> lines;
  final bool loading;
  final int progressMs;
  final bool expanded;
  final ScrollController scrollController;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final tint = artColor != null
        ? spotifyArtColorBackground(artColor!, darkness: 0.25)
        : scheme.primary.withValues(alpha: 0.25);
    final active = SpotifyLyricsService.activeLineIndex(lines, progressMs);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(FolioRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.spotifyNowPlayingLyrics,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: expanded
                    ? l10n.spotifyNowPlayingCollapseLyrics
                    : l10n.spotifyNowPlayingExpandLyrics,
                icon: Icon(
                  expanded
                      ? Icons.unfold_less_rounded
                      : Icons.open_in_full_rounded,
                  size: 18,
                ),
                onPressed: onToggleExpand,
              ),
            ],
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: FolioLoadingIndicator(size: FolioLoadingSize.small),
                  )
                : lines.isEmpty
                    ? Center(
                        child: Text(
                          l10n.spotifyNowPlayingNoLyrics,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: lines.length,
                        itemBuilder: (context, i) {
                          final line = lines[i];
                          final isActive = i == active;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: AnimatedDefaultTextStyle(
                              duration: FolioMotion.short2,
                              curve: FolioMotion.emphasized,
                              style: TextStyle(
                                fontSize: isActive ? 16 : 14,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isActive
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                              child: Text(line.text),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _QueueSheet extends StatefulWidget {
  const _QueueSheet({required this.l10n});
  final AppLocalizations l10n;

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  SpotifyQueueSnapshot _queue = const SpotifyQueueSnapshot();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = await SpotifyPlaybackController.instance.getQueue();
    if (!mounted) return;
    setState(() {
      _queue = q;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.md,
          0,
          FolioSpace.md,
          FolioSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.l10n.spotifyNowPlayingQueue,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: FolioSpace.sm),
            Expanded(
              child: _loading
                  ? const Center(child: FolioLoadingIndicator())
                  : (_queue.currentlyPlaying == null && _queue.queue.isEmpty)
                      ? Center(
                          child: Text(
                            widget.l10n.spotifyNowPlayingNoQueue,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView(
                          children: [
                            if (_queue.currentlyPlaying != null) ...[
                              Text(
                                widget.l10n.spotifyNowPlayingContext,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              _queueTile(_queue.currentlyPlaying!, active: true),
                              const SizedBox(height: FolioSpace.sm),
                            ],
                            if (_queue.queue.isNotEmpty)
                              Text(
                                widget.l10n.spotifyNowPlayingQueue,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ..._queue.queue.map(
                              (t) => _queueTile(t, active: false),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueTile(SpotifyTrackSummary track, {required bool active}) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: track.albumArtUrl != null
            ? Image.network(
                track.albumArtUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              )
            : Container(
                width: 44,
                height: 44,
                color: scheme.surfaceContainerHigh,
                child: const Icon(Icons.music_note_rounded, size: 20),
              ),
      ),
      title: Text(
        track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: active ? _kSpotifyGreen : null,
        ),
      ),
      subtitle: Text(
        track.artistName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: active
          ? null
          : () async {
              await SpotifyPlaybackController.instance
                  .playSpotifyRef(type: 'track', id: track.id);
              if (mounted) Navigator.pop(context);
            },
    );
  }
}

class _DevicesSheet extends StatefulWidget {
  const _DevicesSheet({required this.l10n});
  final AppLocalizations l10n;

  @override
  State<_DevicesSheet> createState() => _DevicesSheetState();
}

class _DevicesSheetState extends State<_DevicesSheet> {
  List<SpotifyDevice> _devices = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final devices = await SpotifyPlaybackController.instance.listDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playback = SpotifyPlaybackController.instance;
    final localReady = SpotifyLocalDeviceService.instance.isReady;
    final height = MediaQuery.sizeOf(context).height * 0.55;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.md,
          0,
          FolioSpace.md,
          FolioSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.l10n.spotifyNowPlayingDevices,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: FolioSpace.sm),
            if (localReady)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.laptop_rounded, color: _kSpotifyGreen),
                title: const Text('Folio'),
                subtitle: Text(widget.l10n.spotifyLibraryPlayingOnFolio),
                trailing: TextButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await playback.activateLocalDevice(play: true);
                    if (!mounted) return;
                    nav.pop();
                  },
                  child: Text(widget.l10n.spotifyActivateDevice),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: FolioLoadingIndicator())
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, i) {
                        final d = _devices[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            d.isActive
                                ? Icons.check_circle_rounded
                                : Icons.speaker_rounded,
                            color: d.isActive ? _kSpotifyGreen : null,
                          ),
                          title: Text(d.name),
                          subtitle: Text(d.type),
                          trailing: d.isActive
                              ? Text(widget.l10n.spotifyThisDeviceActive)
                              : TextButton(
                                  onPressed: () async {
                                    final nav = Navigator.of(context);
                                    await playback.activateDevice(d.id);
                                    if (!mounted) return;
                                    nav.pop();
                                  },
                                  child: Text(widget.l10n.spotifyActivateDevice),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
