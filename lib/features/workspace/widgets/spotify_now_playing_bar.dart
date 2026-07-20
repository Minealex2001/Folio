import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/spotify_integration_state.dart';
import '../../../services/spotify/spotify_api_client.dart';
import '../../../services/spotify/spotify_playback_controller.dart';
import '../../../session/vault_session.dart';
import '../editor/folio_spotify.dart';

/// Densidad visual del reproductor Spotify.
enum SpotifyBarDensity {
  /// Arte + título + play/pause (+ chevron opcional). Para sidebar colapsado.
  mini,

  /// Pastilla flotante de modo zen: arte + play, ancho intrínseco.
  zen,

  /// Barra completa: arte, título, subtítulo, prev/play/next (+ abrir).
  expanded,
}

/// Barra de reproducción Spotify (now playing + controles).
///
/// Visible siempre que haya una cuenta conectada: si no hay pista activa,
/// muestra un estado idle y permite iniciar reproducción (playlist de
/// enfoque o reanudar) sin esperar a que Spotify ya esté sonando.
class SpotifyNowPlayingBar extends StatefulWidget {
  const SpotifyNowPlayingBar({
    super.key,
    required this.session,
    this.density = SpotifyBarDensity.expanded,
    this.opacity = 1.0,
    this.onToggleExpanded,
  });

  final VaultSession session;
  final SpotifyBarDensity density;
  final double opacity;

  /// Si no es null, muestra chevron para alternar mini ↔ expandido.
  final VoidCallback? onToggleExpanded;

  @override
  State<SpotifyNowPlayingBar> createState() => _SpotifyNowPlayingBarState();
}

class _SpotifyNowPlayingBarState extends State<SpotifyNowPlayingBar> {
  bool _busy = false;
  bool _zenExpanded = false;
  double? _volumeDrag;
  double? _progressDrag;
  Timer? _progressTicker;
  int _localProgressMs = 0;
  DateTime? _progressAnchor;

  @override
  void initState() {
    super.initState();
    SpotifyPlaybackController.instance.addListenerRef();
    SpotifyPlaybackController.instance.addListener(_onPlayback);
    _syncLocalProgress();
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    SpotifyPlaybackController.instance.removeListener(_onPlayback);
    SpotifyPlaybackController.instance.removeListenerRef();
    super.dispose();
  }

  void _onPlayback() {
    _syncLocalProgress();
    if (mounted) setState(() {});
  }

  void _syncLocalProgress() {
    final snap = SpotifyPlaybackController.instance.snapshot;
    if (_progressDrag != null) return;
    final base = snap.progressMs;
    _localProgressMs = base;
    _progressAnchor = DateTime.now();
    _progressTicker?.cancel();
    if (snap.isPlaying && snap.durationMs > 0) {
      final duration = snap.durationMs;
      _progressTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted || _progressDrag != null) return;
        final playing = SpotifyPlaybackController.instance.snapshot.isPlaying;
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

  String _formatMs(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 999 * 60);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openSpotify() async {
    // Convertir `spotify:track:id` → https://open.spotify.com/track/id
    // (el replaceAll(':','/') rompía el esquema https:).
    final trackUri = SpotifyPlaybackController.instance.snapshot.trackUri;
    final ref = folioSpotifyRefFromUrl(trackUri);
    final web = ref != null
        ? Uri.https('open.spotify.com', '/${ref.type}/${ref.id}')
        : Uri.https('open.spotify.com', '/');

    // En Windows canLaunchUrl a menudo falla; intentar launch directo.
    try {
      final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    try {
      await launchUrl(web, mode: LaunchMode.platformDefault);
    } catch (_) {}

    // Último recurso: esquema nativo spotify: si tenemos URI de pista.
    if (trackUri != null && trackUri.startsWith('spotify:')) {
      final native = Uri.tryParse(trackUri);
      if (native != null) {
        try {
          await launchUrl(native, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      // El error queda en lastError del controlador; la UI lo refleja.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conns = widget.session.spotifyConnections;
    if (conns.isEmpty) return const SizedBox.shrink();

    if (widget.density == SpotifyBarDensity.zen) {
      return _buildZenPlayer(context, conns.first);
    }
    return _buildBar(context, conns.first);
  }

  Widget _buildZenPlayer(BuildContext context, SpotifyConnection conn) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomLeft,
      child: _zenExpanded
          ? _buildZenExpanded(context, conn)
          : _buildZenCollapsed(context, conn),
    );
  }

  Widget _buildZenCollapsed(BuildContext context, SpotifyConnection conn) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final playback = SpotifyPlaybackController.instance;
    final snap = playback.snapshot;
    final hasTrack = snap.trackName != null && snap.trackName!.isNotEmpty;
    final idle = !hasTrack && !snap.isPlaying;
    final title = hasTrack
        ? snap.trackName!
        : ((conn.focusPlaylistName?.trim().isNotEmpty ?? false)
            ? conn.focusPlaylistName!
            : l10n.spotifyReadyIdle);

    return AnimatedOpacity(
      opacity: widget.opacity,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: scheme.surface.withValues(alpha: 0.78),
        elevation: 1,
        shadowColor: scheme.shadow.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _spotifyMark(size: 16),
              const SizedBox(width: 6),
              _zenArt(snap, size: 26),
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
                    color: scheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              _zenIconButton(
                tooltip: snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                icon: snap.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                showBusy: true,
                onPressed: () => unawaited(_run(playback.togglePlayPause)),
              ),
              _zenIconButton(
                tooltip: l10n.spotifySkipNext,
                icon: Icons.skip_next_rounded,
                onPressed: idle
                    ? null
                    : () => unawaited(_run(playback.skipNext)),
              ),
              _zenIconButton(
                tooltip: l10n.spotifyExpandPlayer,
                icon: Icons.keyboard_arrow_up_rounded,
                ignoreBusy: true,
                onPressed: () => setState(() => _zenExpanded = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZenExpanded(BuildContext context, SpotifyConnection conn) {
    return _buildExpandedPanel(
      context: context,
      conn: conn,
      width: 280,
      artSize: 160,
      onCollapse: () => setState(() {
        _zenExpanded = false;
        _volumeDrag = null;
        _progressDrag = null;
      }),
      surfaceAlpha: 0.88,
    );
  }

  /// Panel extendido compartido (zen y sidebar): carátula grande + transport + volumen.
  Widget _buildExpandedPanel({
    required BuildContext context,
    required SpotifyConnection conn,
    required double artSize,
    required VoidCallback onCollapse,
    double? width,
    double surfaceAlpha = 0.92,
  }) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final playback = SpotifyPlaybackController.instance;
    final snap = playback.snapshot;
    final hasTrack = snap.trackName != null && snap.trackName!.isNotEmpty;
    final idle = !hasTrack && !snap.isPlaying;
    final title = hasTrack
        ? snap.trackName!
        : ((conn.focusPlaylistName?.trim().isNotEmpty ?? false)
            ? conn.focusPlaylistName!
            : l10n.spotifyReadyIdle);
    final subtitle = hasTrack
        ? (snap.artistName ?? '')
        : (snap.noActiveDevice
            ? l10n.spotifyNoActiveDevice
            : l10n.spotifyNothingPlaying);
    final volume = (_volumeDrag ?? (snap.volumePercent?.toDouble() ?? 70))
        .clamp(0.0, 100.0);
    final duration = snap.durationMs > 0 ? snap.durationMs.toDouble() : 1.0;
    final progress = (_progressDrag ?? _localProgressMs.toDouble())
        .clamp(0.0, duration);

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _spotifyOpenButton(
                tooltip: l10n.spotifyOpenInSpotify,
                size: 18,
              ),
              const Spacer(),
              _zenIconButton(
                tooltip: l10n.spotifyCollapsePlayer,
                icon: Icons.keyboard_arrow_down_rounded,
                ignoreBusy: true,
                onPressed: onCollapse,
              ),
            ],
          ),
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
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Barra de tiempo / seek.
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: progress,
              min: 0,
              max: duration,
              onChanged: idle || snap.durationMs <= 0
                  ? null
                  : (v) => setState(() => _progressDrag = v),
              onChangeEnd: idle || snap.durationMs <= 0
                  ? null
                  : (v) {
                      setState(() {
                        _progressDrag = null;
                        _localProgressMs = v.round();
                        _progressAnchor = DateTime.now();
                      });
                      unawaited(_run(() => playback.seek(v.round())));
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
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatMs(snap.durationMs),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Controles centrados: solo prev / play / next.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _zenIconButton(
                tooltip: l10n.spotifySkipPrevious,
                icon: Icons.skip_previous_rounded,
                onPressed: idle
                    ? null
                    : () => unawaited(_run(playback.skipPrevious)),
              ),
              const SizedBox(width: 8),
              _zenIconButton(
                tooltip: snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                icon: snap.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 34,
                showBusy: true,
                onPressed: () => unawaited(_run(playback.togglePlayPause)),
              ),
              const SizedBox(width: 8),
              _zenIconButton(
                tooltip: l10n.spotifySkipNext,
                icon: Icons.skip_next_rounded,
                onPressed: idle
                    ? null
                    : () => unawaited(_run(playback.skipNext)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                volume <= 0
                    ? Icons.volume_off_rounded
                    : volume < 40
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
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
                  ),
                  child: Slider(
                    value: volume,
                    min: 0,
                    max: 100,
                    label: '${volume.round()}%',
                    onChanged: (v) => setState(() => _volumeDrag = v),
                    onChangeEnd: (v) {
                      setState(() => _volumeDrag = null);
                      unawaited(_run(() => playback.setVolume(v.round())));
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return AnimatedOpacity(
      opacity: widget.opacity,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: surfaceAlpha),
        elevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        child: width != null ? SizedBox(width: width, child: body) : body,
      ),
    );
  }

  Widget _zenArt(
    SpotifyPlaybackSnapshot snap, {
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
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            color: const Color(0xFF1DB954).withValues(alpha: 0.12),
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.35,
              color: const Color(0xFF1DB954),
            ),
          ),
        ),
      );
    }
    return Container(
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
  }

  /// Logo de marca (solo visual, sin acción).
  Widget _spotifyMark({double size = 16}) {
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

  /// Botón «Abrir en Spotify» con el logo de marca.
  Widget _spotifyOpenButton({
    required String tooltip,
    double size = 18,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: () => unawaited(_openSpotify()),
        icon: _spotifyMark(size: size),
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
  }) {
    final disabled = onPressed == null || (_busy && !ignoreBusy);
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
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Icon(icon, size: size),
        onPressed: disabled ? null : onPressed,
      ),
    );
  }

  Widget _buildBar(BuildContext context, SpotifyConnection conn) {
    final isMini = widget.density == SpotifyBarDensity.mini;
    if (!isMini) {
      return _buildExpandedPanel(
        context: context,
        conn: conn,
        artSize: 168,
        onCollapse: () {
          _volumeDrag = null;
          _progressDrag = null;
          widget.onToggleExpanded?.call();
        },
        surfaceAlpha: 0.95,
      );
    }

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final playback = SpotifyPlaybackController.instance;
    final snap = playback.snapshot;
    final hasTrack = snap.trackName != null && snap.trackName!.isNotEmpty;
    final idle = !hasTrack && !snap.isPlaying;

    final String title;
    if (snap.premiumRequired) {
      title = l10n.spotifyPremiumRequired;
    } else if (snap.noActiveDevice && idle) {
      title = l10n.spotifyReadyIdle;
    } else if (idle) {
      title = l10n.spotifyReadyIdle;
    } else {
      title = snap.trackName!;
    }

    return AnimatedOpacity(
      opacity: widget.opacity,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
        elevation: 0,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _spotifyMark(size: 16),
              const SizedBox(width: 6),
              _zenArt(snap, size: 28, radius: 6),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : Icon(
                        snap.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                onPressed: _busy
                    ? null
                    : () => unawaited(_run(playback.togglePlayPause)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l10n.spotifySkipNext,
                icon: const Icon(Icons.skip_next_rounded, size: 20),
                onPressed: _busy || idle
                    ? null
                    : () => unawaited(_run(playback.skipNext)),
              ),
              if (widget.onToggleExpanded != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.spotifyExpandPlayer,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  onPressed: widget.onToggleExpanded,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
