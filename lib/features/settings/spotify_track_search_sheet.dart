import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/spotify/spotify_api_client.dart';
import '../../services/spotify/spotify_playback_controller.dart';

/// Abre una hoja de búsqueda de canciones; al tocar un resultado, lo
/// reproduce en el dispositivo Spotify activo (local o remoto).
Future<void> showSpotifyTrackSearchSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: FolioDesktop.editorMaxWidth),
    builder: (ctx) => const _SpotifyTrackSearchSheet(),
  );
}

class _SpotifyTrackSearchSheet extends StatefulWidget {
  const _SpotifyTrackSearchSheet();

  @override
  State<_SpotifyTrackSearchSheet> createState() => _SpotifyTrackSearchSheetState();
}

class _SpotifyTrackSearchSheetState extends State<_SpotifyTrackSearchSheet> {
  final _searchController = TextEditingController();
  final List<SpotifyTrackSummary> _results = [];
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  String? _playingTrackId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results.clear();
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(_search(query)));
  }

  Future<void> _search(String query) async {
    final playback = SpotifyPlaybackController.instance;
    final client = playback.apiClientForSettings();
    if (client == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await client.search(query);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _results
          ..clear()
          ..addAll(results);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playTrack(SpotifyTrackSummary track) async {
    setState(() => _playingTrackId = track.id);
    try {
      await SpotifyPlaybackController.instance.playSpotifyRef(
        type: 'track',
        id: track.id,
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.spotifyPlayTrackFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _playingTrackId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.82;

    return SizedBox(
      height: maxH,
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
              l10n.spotifySearchTracks,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.spotifySearchTracksHint,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: FolioSpace.sm),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.spotifySearchPlaceholder,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
              ),
            ),
            const SizedBox(height: FolioSpace.sm),
            Expanded(child: _buildBody(context, l10n, scheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n, ColorScheme scheme) {
    if (_loading && _results.isEmpty) {
      return const Center(child: FolioLoadingIndicator());
    }
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: scheme.error, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_searchController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          l10n.spotifyNoTracksFound,
          style: TextStyle(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final track = _results[index];
        return _TrackTile(
          track: track,
          busy: _playingTrackId == track.id,
          onTap: () => unawaited(_playTrack(track)),
        );
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.track, required this.busy, required this.onTap});

  final SpotifyTrackSummary track;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(FolioRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: track.albumArtUrl != null
                    ? Image.network(
                        track.albumArtUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackArt(scheme),
                      )
                    : _fallbackArt(scheme),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(4),
                  child: FolioLoadingIndicator(size: FolioLoadingSize.small),
                )
              else
                Icon(Icons.play_circle_outline_rounded, color: scheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackArt(ColorScheme scheme) {
    return Container(
      width: 48,
      height: 48,
      color: scheme.surfaceContainerHigh,
      child: Icon(Icons.music_note_rounded, color: scheme.onSurfaceVariant),
    );
  }
}
