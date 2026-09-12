import 'dart:async';
import 'dart:ui' show FontFeature;  // ignore: unnecessary_import

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../services/media/media_playback_router.dart';
import '../../../services/media/now_playing_snapshot.dart';
import '../../../services/media/system_media_block.dart';
import '../../../services/spotify/spotify_art_color.dart';
import '../../../session/vault_session.dart';
import '../spotify/spotify_library_page.dart';
import '../ytmusic/ytmusic_library_page.dart';

/// Densidad visual del reproductor now playing.
enum NowPlayingBarDensity {
  /// Arte + título + play/pause (+ chevron opcional). Para sidebar colapsado.
  mini,

  /// Pastilla flotante de modo zen: arte + play, ancho intrínseco.
  zen,

  /// Barra completa: arte, título, subtítulo, prev/play/next (+ abrir).
  expanded,
}

/// Alias de compatibilidad.
typedef SpotifyBarDensity = NowPlayingBarDensity;

/// Barra de reproducción genérica (Spotify o media del sistema).
class NowPlayingBar extends StatefulWidget {
  const NowPlayingBar({
    super.key,
    required this.session,
    this.density = NowPlayingBarDensity.expanded,
    this.opacity = 1.0,
    this.onToggleExpanded,
  });

  final VaultSession session;
  final NowPlayingBarDensity density;
  final double opacity;

  /// Si no es null, muestra chevron para alternar mini ↔ expandido.
  final VoidCallback? onToggleExpanded;

  @override
  State<NowPlayingBar> createState() => _NowPlayingBarState();
}

/// Alias de compatibilidad.
typedef SpotifyNowPlayingBar = NowPlayingBar;

class _NowPlayingBarState extends State<NowPlayingBar>
    with TickerProviderStateMixin {
  bool _busy = false;
  bool _zenExpanded = false;
  bool _miniCardHovered = false;
  bool _zenCardHovered = false;
  double? _volumeDrag;
  double? _progressDrag;
  Timer? _progressTicker;
  int _localProgressMs = 0;
  DateTime? _progressAnchor;

  // Color dominante de la carátula.
  Color? _artColor;
  Color? _prevArtColor;
  late final AnimationController _colorAnim;
  late Animation<double> _colorT;

  @override
  void initState() {
    super.initState();
    _colorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _colorT = CurvedAnimation(parent: _colorAnim, curve: Curves.easeInOut);

    MediaPlaybackRouter.instance.addListenerRef();
    MediaPlaybackRouter.instance.addListener(_onPlayback);
    _syncLocalProgress();
    _maybeUpdateArtColor();
  }

  @override
  void didUpdateWidget(covariant NowPlayingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.density == NowPlayingBarDensity.expanded &&
        widget.density == NowPlayingBarDensity.mini) {
      _miniCardHovered = false;
    }
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    _colorAnim.dispose();
    MediaPlaybackRouter.instance.removeListener(_onPlayback);
    MediaPlaybackRouter.instance.removeListenerRef();
    super.dispose();
  }

  void _onPlayback() {
    _syncLocalProgress();
    _maybeUpdateArtColor();
    if (mounted) setState(() {});
  }

  MediaPlaybackRouter get _router => MediaPlaybackRouter.instance;

  NowPlayingSnapshot get _snap => _router.snapshot;

  void _syncLocalProgress() {
    final snap = _snap;
    if (_progressDrag != null) return;
    final base = snap.progressMs;
    _localProgressMs = base;
    _progressAnchor = DateTime.now();
    _progressTicker?.cancel();
    if (snap.isPlaying && snap.durationMs > 0) {
      final duration = snap.durationMs;
      _progressTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted || _progressDrag != null) return;
        final playing = _snap.isPlaying;
        if (!playing) {
          _progressTicker?.cancel();
          return;
        }
        final elapsed =
            DateTime.now().difference(_progressAnchor!).inMilliseconds;
        final next = (base + elapsed).clamp(0, duration);
        if (next != _localProgressMs) {
          setState(() => _localProgressMs = next);
        }
      });
    }
  }

  Object? _artKey;

  void _maybeUpdateArtColor() {
    final snap = _snap;
    final key = snap.albumArtUrl ??
        (snap.albumArtBytes != null
            ? Object.hashAll(snap.albumArtBytes!)
            : null);
    if (key == _artKey) return;
    _artKey = key;
    if (snap.albumArtUrl != null && snap.albumArtUrl!.isNotEmpty) {
      extractSpotifyArtColor(snap.albumArtUrl).then((color) {
        if (!mounted || _artKey != key) return;
        setState(() {
          _prevArtColor = _artColor;
          _artColor = color;
        });
        _colorAnim.forward(from: 0);
      });
      return;
    }
    if (snap.albumArtBytes != null && snap.albumArtBytes!.isNotEmpty) {
      extractArtColorFromBytes(snap.albumArtBytes).then((color) {
        if (!mounted || _artKey != key) return;
        setState(() {
          _prevArtColor = _artColor;
          _artColor = color;
        });
        _colorAnim.forward(from: 0);
      });
      return;
    }
    if (_artColor != null) {
      setState(() {
        _prevArtColor = _artColor;
        _artColor = null;
      });
      _colorAnim.forward(from: 0);
    }
  }

  /// Color de fondo interpolado entre la pista anterior y la actual.
  Color? _currentBg(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final def = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHigh;

    Color from = _prevArtColor != null
        ? spotifyArtColorBackground(_prevArtColor!)
        : def;
    Color to = _artColor != null
        ? spotifyArtColorBackground(_artColor!)
        : def;

    return Color.lerp(from, to, _colorT.value);
  }

  String _formatMs(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 999 * 60);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openLibraryOrExternal() async {
    final snap = _snap;
    if (snap.sourceId == NowPlayingSourceId.spotify) {
      if (!mounted) return;
      await openSpotifyLibraryPage(context: context, session: widget.session);
      return;
    }
    if (snap.sourceId == NowPlayingSourceId.youtubeMusic) {
      if (!mounted) return;
      await openYtMusicLibraryPage(context: context);
      return;
    }
    await _router.openExternal();
  }

  Future<void> _insertCurrentTrack() async {
    final snap = _snap;
    if (!snap.canInsertBlock || !snap.hasTrack) return;
    final pageId = widget.session.selectedPageId;
    if (pageId == null) return;
    final blockId = '${pageId}_${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'title': snap.title,
      'artist': snap.artist,
      'appName': snap.sourceLabel,
      'appId': snap.appId,
      'capturedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
    widget.session.appendBlock(
      pageId: pageId,
      block: FolioBlock(
        id: blockId,
        type: 'systemMedia',
        text: encodeSystemMediaBlockText(payload),
        url: snap.externalUrl,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {}
    finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_router.shouldShowBar) return const SizedBox.shrink();

    if (widget.density == NowPlayingBarDensity.zen) {
      return _buildZenPlayer(context);
    }
    return _buildBar(context);
  }

  /// En Android/iOS no hay hover: el expandir debe ser siempre accesible al toque.
  bool get _touchPrimary {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  /// Overlay de expandir visible: hover en escritorio, siempre en móvil.
  bool _expandOverlayVisible(bool hovered) => hovered || _touchPrimary;

  // ── ZEN ─────────────────────────────────────────────────────────────────

  Widget _buildZenPlayer(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomLeft,
      child: _zenExpanded
          ? _buildZenExpanded(context)
          : _buildZenCollapsed(context),
    );
  }

  Widget _buildZenCollapsed(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snap = _snap;
    final hasTrack = snap.hasTrack;
    final idle = snap.isIdle;
    final title = hasTrack
        ? snap.title!
        : (snap.idleTitle?.trim().isNotEmpty == true
            ? snap.idleTitle!
            : l10n.spotifyReadyIdle);

    return AnimatedBuilder(
      animation: _colorT,
      builder: (context, child) {
        final bg = _currentBg(theme) ??
            scheme.surface.withValues(alpha: 0.78);
        final fg = spotifyArtColorForeground(bg);
        return AnimatedOpacity(
          opacity: widget.opacity,
          duration: const Duration(milliseconds: 200),
          child: MouseRegion(
            onEnter: (_) => setState(() => _zenCardHovered = true),
            onExit: (_) => setState(() => _zenCardHovered = false),
            child: Material(
              color: bg.withValues(alpha: 0.88),
              elevation: 1,
              shadowColor: scheme.shadow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sourceMarkButton(
                      snap,
                      size: 16,
                      tooltip: snap.sourceId == NowPlayingSourceId.spotify
                          ? l10n.spotifyLibraryOpenTooltip
                          : (snap.canOpenExternal
                              ? l10n.systemMediaOpenSource
                              : ''),
                    ),
                    const SizedBox(width: 6),
                    _artWithExpandOverlay(
                      snap: snap,
                      size: 26,
                      radius: 6,
                      showOverlay: _expandOverlayVisible(_zenCardHovered),
                      expandTooltip: l10n.spotifyExpandPlayer,
                      onExpand: () => setState(() {
                        _zenCardHovered = false;
                        _zenExpanded = true;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: fg.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    _zenIconButton(
                      tooltip:
                          snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                      icon: snap.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      showBusy: true,
                      fg: fg,
                      onPressed: () =>
                          unawaited(_run(_router.togglePlayPause)),
                    ),
                    _zenIconButton(
                      tooltip: l10n.spotifySkipNext,
                      icon: Icons.skip_next_rounded,
                      fg: fg,
                      onPressed: idle || !snap.canSkip
                          ? null
                          : () => unawaited(_run(_router.skipNext)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildZenExpanded(BuildContext context) {
    return _buildExpandedPanel(
      context: context,
      artSize: 160,
      onCollapse: () => setState(() {
        _zenExpanded = false;
        _zenCardHovered = false;
        _volumeDrag = null;
        _progressDrag = null;
      }),
      width: 280,
    );
  }

  // ── SIDEBAR BAR (mini / expanded) ────────────────────────────────────────

  Widget _buildBar(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.hardEdge,
      child: widget.density == NowPlayingBarDensity.mini
          ? _buildMiniBar(context)
          : _buildExpandedPanel(
              context: context,
              artSize: 168,
              onCollapse: () {
                setState(() {
                  _volumeDrag = null;
                  _progressDrag = null;
                  _miniCardHovered = false;
                });
                widget.onToggleExpanded?.call();
              },
            ),
    );
  }

  Widget _buildMiniBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snap = _snap;
    final idle = snap.isIdle;

    final String title;
    if (snap.premiumRequired) {
      title = l10n.spotifyPremiumRequired;
    } else if (snap.noActiveDevice && idle) {
      title = l10n.spotifyNoActiveDevice;
    } else if (idle) {
      title = snap.sourceId == NowPlayingSourceId.system
          ? l10n.systemMediaReadyIdle
          : l10n.spotifyReadyIdle;
    } else {
      title = snap.title!;
    }

    final bg = _currentBg(theme) ??
        scheme.surfaceContainerHighest.withValues(alpha: 0.92);
    final fg = spotifyArtColorForeground(bg);

    return MouseRegion(
      onEnter: (_) => setState(() => _miniCardHovered = true),
      onExit: (_) => setState(() => _miniCardHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedOpacity(
          opacity: widget.opacity,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _sourceMarkButton(
                  snap,
                  size: 16,
                  tooltip: snap.sourceId == NowPlayingSourceId.spotify
                      ? l10n.spotifyLibraryOpenTooltip
                      : (snap.canOpenExternal
                          ? l10n.systemMediaOpenSource
                          : ''),
                ),
                const SizedBox(width: 6),
                if (widget.onToggleExpanded != null)
                  _artWithExpandOverlay(
                    snap: snap,
                    size: 28,
                    radius: 6,
                    showOverlay: _expandOverlayVisible(_miniCardHovered),
                    expandTooltip: l10n.spotifyExpandPlayer,
                    onExpand: () {
                      setState(() => _miniCardHovered = false);
                      widget.onToggleExpanded?.call();
                    },
                  )
                else
                  _zenArt(snap, size: 28, radius: 6),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: fg,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip:
                      snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                  icon: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      : Icon(
                          snap.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 20,
                          color: fg,
                        ),
                  onPressed: _busy
                      ? null
                      : () => unawaited(_run(_router.togglePlayPause)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.spotifySkipNext,
                  icon: Icon(Icons.skip_next_rounded, size: 20, color: fg),
                  onPressed: _busy || idle || !snap.canSkip
                      ? null
                      : () => unawaited(_run(_router.skipNext)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── PANEL EXPANDIDO ─────────────────────────────────────────────────────

  Widget _buildExpandedPanel({
    required BuildContext context,
    required double artSize,
    required VoidCallback onCollapse,
    double? width,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snap = _snap;
    final hasTrack = snap.hasTrack;
    final idle = snap.isIdle;

    final String title;
    if (snap.premiumRequired) {
      title = l10n.spotifyPremiumRequired;
    } else if (snap.noActiveDevice && idle) {
      title = l10n.spotifyNoActiveDevice;
    } else if (idle) {
      title = snap.idleTitle?.trim().isNotEmpty == true
          ? snap.idleTitle!
          : (snap.sourceId == NowPlayingSourceId.system
              ? l10n.systemMediaReadyIdle
              : l10n.spotifyReadyIdle);
    } else {
      title = snap.title!;
    }

    final String subtitle;
    if (hasTrack) {
      subtitle = snap.artist ?? '';
    } else if (snap.noActiveDevice) {
      subtitle = l10n.spotifyNoActiveDevice;
    } else if (snap.sourceId == NowPlayingSourceId.system) {
      subtitle = l10n.systemMediaNothingPlaying;
    } else {
      subtitle = l10n.spotifyNothingPlaying;
    }

    final volume = (_volumeDrag ?? (snap.volumePercent?.toDouble() ?? 70))
        .clamp(0.0, 100.0);
    final duration = snap.durationMs > 0 ? snap.durationMs.toDouble() : 1.0;
    final progress = (_progressDrag ?? _localProgressMs.toDouble())
        .clamp(0.0, duration);
    final canSeek = snap.canSeek && !idle && snap.durationMs > 0;

    final bg = _currentBg(theme) ??
        scheme.surfaceContainerHighest.withValues(alpha: 0.95);
    final fg = spotifyArtColorForeground(bg);
    final fgSubtle = fg.withValues(alpha: 0.65);

    final openTooltip = snap.sourceId == NowPlayingSourceId.spotify
        ? l10n.spotifyOpenInSpotify
        : l10n.systemMediaOpenSource;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera: abrir origen / insertar + chevron colapsar.
          Row(
            children: [
              if (snap.sourceId == NowPlayingSourceId.spotify ||
                  snap.canOpenExternal)
                _sourceOpenButton(
                  snap: snap,
                  tooltip: snap.sourceId == NowPlayingSourceId.spotify
                      ? l10n.spotifyLibraryOpenTooltip
                      : openTooltip,
                  size: 18,
                  fg: fg,
                ),
              if (snap.canInsertBlock && hasTrack)
                _zenIconButton(
                  tooltip: l10n.systemMediaInsertTrack,
                  icon: Icons.note_add_rounded,
                  ignoreBusy: true,
                  fg: fg,
                  onPressed: () => unawaited(_insertCurrentTrack()),
                ),
              const Spacer(),
              _zenIconButton(
                tooltip: l10n.spotifyCollapsePlayer,
                icon: Icons.keyboard_arrow_down_rounded,
                ignoreBusy: true,
                fg: fg,
                onPressed: onCollapse,
              ),
            ],
          ),
          // Carátula.
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxArt = constraints.maxWidth.isFinite
                    ? constraints.maxWidth.clamp(96.0, artSize)
                    : artSize;
                return _zenArt(snap, size: maxArt, radius: 12);
              },
            ),
          ),
          const SizedBox(height: 12),
          // Título.
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: fgSubtle),
            ),
          ],
          const SizedBox(height: 8),
          // Seek bar.
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: fg.withValues(alpha: 0.9),
              inactiveTrackColor: fg.withValues(alpha: 0.25),
              thumbColor: fg,
              overlayColor: fg.withValues(alpha: 0.12),
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
                      unawaited(_run(() => _router.seek(v.round())));
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  _formatMs(progress.round()),
                  style: TextStyle(
                    fontSize: 11,
                    color: fgSubtle,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatMs(snap.durationMs),
                  style: TextStyle(
                    fontSize: 11,
                    color: fgSubtle,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Controles: prev / play / next.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _zenIconButton(
                tooltip: l10n.spotifySkipPrevious,
                icon: Icons.skip_previous_rounded,
                fg: fg,
                onPressed: idle || !snap.canSkip
                    ? null
                    : () => unawaited(_run(_router.skipPrevious)),
              ),
              const SizedBox(width: 8),
              _zenIconButton(
                tooltip:
                    snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                icon: snap.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 34,
                showBusy: true,
                fg: fg,
                onPressed: () => unawaited(_run(_router.togglePlayPause)),
              ),
              const SizedBox(width: 8),
              _zenIconButton(
                tooltip: l10n.spotifySkipNext,
                icon: Icons.skip_next_rounded,
                fg: fg,
                onPressed: idle || !snap.canSkip
                    ? null
                    : () => unawaited(_run(_router.skipNext)),
              ),
            ],
          ),
          if (snap.canSetVolume) ...[
            const SizedBox(height: 4),
            // Volumen.
            Row(
              children: [
                Icon(
                  volume <= 0
                      ? Icons.volume_off_rounded
                      : volume < 40
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  size: 18,
                  color: fgSubtle,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: fg.withValues(alpha: 0.85),
                      inactiveTrackColor: fg.withValues(alpha: 0.2),
                      thumbColor: fg,
                      overlayColor: fg.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 100,
                      label: '${volume.round()}%',
                      onChanged: (v) => setState(() => _volumeDrag = v),
                      onChangeEnd: (v) {
                        setState(() => _volumeDrag = null);
                        unawaited(_run(() => _router.setVolume(v.round())));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return AnimatedOpacity(
      opacity: widget.opacity,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: width != null ? SizedBox(width: width, child: body) : body,
      ),
    );
  }

  // ── WIDGETS AUXILIARES ──────────────────────────────────────────────────

  /// Carátula con botón de expandir superpuesto.
  /// En escritorio: visible al hover. En móvil: siempre visible y tappable.
  Widget _artWithExpandOverlay({
    required NowPlayingSnapshot snap,
    required double size,
    required double radius,
    required bool showOverlay,
    required String expandTooltip,
    required VoidCallback? onExpand,
  }) {
    final iconSize = (size * 0.42).clamp(12.0, 22.0);
    // En móvil un overlay completo oscurece demasiado la carátula pequeña:
    // usar un badge en la esquina. En desktop (hover) overlay completo.
    final cornerBadge = _touchPrimary;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _zenArt(snap, size: size, radius: radius),
            if (cornerBadge)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onExpand,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: iconSize.clamp(10.0, 14.0),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !showOverlay,
                  child: AnimatedOpacity(
                    opacity: showOverlay ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: Tooltip(
                      message: expandTooltip,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: InkWell(
                          onTap: onExpand,
                          child: Center(
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: iconSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _zenArt(
    NowPlayingSnapshot snap, {
    required double size,
    double radius = 999,
  }) {
    if (snap.albumArtUrl != null && snap.albumArtUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          snap.albumArtUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _artPlaceholder(size, radius),
        ),
      );
    }
    if (snap.albumArtBytes != null && snap.albumArtBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          snap.albumArtBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Sin esto, cada snapshot nuevo (nuevo Uint8List, aunque el
          // contenido sea idéntico) borra el frame anterior antes de
          // decodificar el siguiente, y se ve como un parpadeo en cada
          // poll de media del sistema (~1s).
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _artPlaceholder(size, radius),
        ),
      );
    }
    return _artPlaceholder(size, radius);
  }

  Widget _artPlaceholder(double size, double radius) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1DB954).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.35,
          color: const Color(0xFF1DB954),
        ),
      );

  Widget _sourceMark(NowPlayingSnapshot snap, {double size = 16}) {
    if (snap.sourceId == NowPlayingSourceId.spotify) {
      return Image.asset(
        'appLogos/spotify.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Icon(
          Icons.music_note_rounded,
          size: size,
          color: const Color(0xFF1DB954),
        ),
      );
    }
    if (snap.sourceId == NowPlayingSourceId.youtubeMusic) {
      return Image.asset(
        'appLogos/ytMusic.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Icon(
          Icons.play_circle_filled_rounded,
          size: size,
          color: const Color(0xFFFF0000),
        ),
      );
    }
    return Icon(
      Icons.headphones_rounded,
      size: size,
      color: const Color(0xFF1DB954),
    );
  }

  Widget _sourceMarkButton(
    NowPlayingSnapshot snap, {
    double size = 16,
    required String tooltip,
  }) {
    final canTap = snap.sourceId == NowPlayingSourceId.spotify ||
        snap.canOpenExternal;
    final mark = _sourceMark(snap, size: size);
    if (!canTap || tooltip.isEmpty) return mark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => unawaited(_openLibraryOrExternal()),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: mark,
        ),
      ),
    );
  }

  Widget _sourceOpenButton({
    required NowPlayingSnapshot snap,
    required String tooltip,
    double size = 18,
    Color? fg,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: () => unawaited(_openLibraryOrExternal()),
        icon: _sourceMark(snap, size: size),
      ),
    );
  }

  Widget _zenIconButton({
    required String tooltip,
    required IconData icon,
    VoidCallback? onPressed,
    double size = 20,
    bool showBusy = false,
    bool ignoreBusy = false,
    Color? fg,
  }) {
    final disabled = onPressed == null || (_busy && !ignoreBusy);
    final iconColor = fg ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        icon: showBusy && _busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            : Icon(icon, size: size, color: iconColor),
        onPressed: disabled ? null : onPressed,
      ),
    );
  }
}
