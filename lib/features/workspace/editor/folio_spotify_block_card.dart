import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/spotify/spotify_playback_controller.dart';
import 'folio_spotify.dart';

/// Tarjeta Spotify sin WebView (evita corrupción del árbol en Windows/ListView).
class FolioSpotifyBlockCard extends StatefulWidget {
  const FolioSpotifyBlockCard({
    super.key,
    required this.url,
    required this.title,
    required this.scheme,
  });

  final String url;
  final String title;
  final ColorScheme scheme;

  @override
  State<FolioSpotifyBlockCard> createState() => _FolioSpotifyBlockCardState();
}

class _FolioSpotifyBlockCardState extends State<FolioSpotifyBlockCard> {
  String? _thumbnailUrl;
  String? _resolvedTitle;
  var _loadingMeta = false;
  var _playing = false;

  FolioSpotifyRef? get _ref => folioSpotifyRefFromUrl(widget.url);

  @override
  void initState() {
    super.initState();
    unawaited(_loadMeta());
  }

  @override
  void didUpdateWidget(covariant FolioSpotifyBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _thumbnailUrl = null;
      _resolvedTitle = null;
      unawaited(_loadMeta());
    }
  }

  Future<void> _loadMeta() async {
    final url = widget.url.trim();
    if (url.isEmpty) return;
    setState(() => _loadingMeta = true);
    final meta = await fetchSpotifyOEmbed(url);
    if (!mounted) return;
    setState(() {
      _loadingMeta = false;
      _thumbnailUrl = meta?.thumbnailUrl;
      _resolvedTitle = meta?.title;
    });
  }

  Future<void> _openExternal() async {
    final ref = _ref;
    final target = ref != null
        ? folioSpotifyOpenUrl(ref.type, ref.id)
        : widget.url.trim();
    final u = Uri.tryParse(target);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  Future<void> _playInFolio() async {
    final ref = _ref;
    if (ref == null) return;
    final playback = SpotifyPlaybackController.instance;
    if (!playback.hasConnection) {
      await _openExternal();
      return;
    }
    setState(() => _playing = true);
    try {
      await playback.playSpotifyRef(type: ref.type, id: ref.id);
    } catch (_) {
      if (mounted) await _openExternal();
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = widget.scheme;
    final title = (widget.title.trim().isNotEmpty
            ? widget.title.trim()
            : (_resolvedTitle ?? '').trim())
        .trim();
    final displayTitle =
        title.isNotEmpty ? title : l10n.spotifyPasteUrlOption;

    return ListenableBuilder(
      listenable: SpotifyPlaybackController.instance,
      builder: (context, _) {
        final canPlay = SpotifyPlaybackController.instance.hasConnection &&
            _ref != null;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => unawaited(_openExternal()),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Cover(
                    scheme: scheme,
                    thumbnailUrl: _thumbnailUrl,
                    loading: _loadingMeta && _thumbnailUrl == null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.music_note_rounded,
                              size: 16,
                              color: Color(0xFF1DB954),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.spotifyBrandName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF1DB954),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (canPlay)
                              FilledButton.tonalIcon(
                                onPressed: _playing
                                    ? null
                                    : () => unawaited(_playInFolio()),
                                icon: _playing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 18,
                                      ),
                                label: Text(l10n.spotifyPlay),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: () => unawaited(_openExternal()),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                              ),
                              label: Text(l10n.spotifyOpenInSpotify),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.scheme,
    required this.thumbnailUrl,
    required this.loading,
  });

  final ColorScheme scheme;
  final String? thumbnailUrl;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    final url = thumbnailUrl?.trim() ?? '';
    Widget child;
    if (url.isNotEmpty) {
      child = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else if (loading) {
      child = const SizedBox(
        width: size,
        height: size,
        child: FolioLoadingIndicator(centered: true),
      );
    } else {
      child = _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          size: 36,
          color: Color(0xFF1DB954),
        ),
      ),
    );
  }
}
