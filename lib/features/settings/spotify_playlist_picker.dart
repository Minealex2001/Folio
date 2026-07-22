import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/spotify_integration_state.dart';
import '../../services/spotify/spotify_api_client.dart';
import '../../services/spotify/spotify_playback_controller.dart';
import '../../session/vault_session.dart';

/// Abre un selector de playlist con búsqueda, paginación y vista previa.
Future<SpotifyPlaylistSummary?> showSpotifyPlaylistPicker({
  required BuildContext context,
  required VaultSession session,
  String? selectedUri,
}) {
  return showModalBottomSheet<SpotifyPlaylistSummary>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: FolioDesktop.editorMaxWidth),
    builder: (ctx) => _SpotifyPlaylistPickerSheet(
      session: session,
      selectedUri: selectedUri,
    ),
  );
}

class _SpotifyPlaylistPickerSheet extends StatefulWidget {
  const _SpotifyPlaylistPickerSheet({
    required this.session,
    this.selectedUri,
  });

  final VaultSession session;
  final String? selectedUri;

  @override
  State<_SpotifyPlaylistPickerSheet> createState() =>
      _SpotifyPlaylistPickerSheetState();
}

class _SpotifyPlaylistPickerSheetState extends State<_SpotifyPlaylistPickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<SpotifyPlaylistSummary> _playlists = [];
  String _searchQuery = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextOffset = 0;
  String? _error;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_loadPage(reset: true));
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    unawaited(_loadPage(reset: false));
  }

  SpotifyConnection? get _connection =>
      widget.session.spotifyConnections.isNotEmpty
          ? widget.session.spotifyConnections.first
          : null;

  SpotifyApiClient? _buildClient() {
    final conn = _connection;
    if (conn == null) return null;
    return SpotifyApiClient(
      connection: conn,
      onConnectionUpdated: (updated) async {
        widget.session.upsertSpotifyConnection(updated);
        return updated;
      },
    );
  }

  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _playlists.clear();
        _nextOffset = 0;
        _hasMore = false;
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final client = _buildClient();
    if (client == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
      return;
    }

    try {
      final page = await client.listUserPlaylists(
        limit: _pageSize,
        offset: reset ? 0 : _nextOffset,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _playlists
            ..clear()
            ..addAll(page.items);
        } else {
          _playlists.addAll(page.items);
        }
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<SpotifyPlaylistSummary> get _visiblePlaylists {
    if (_searchQuery.isEmpty) return _playlists;
    return _playlists
        .where((p) => p.name.toLowerCase().contains(_searchQuery))
        .toList(growable: false);
  }

  Future<void> _previewPlaylist(SpotifyPlaylistSummary playlist) async {
    final client = _buildClient();
    if (client == null) return;
    try {
      await client.play(contextUri: playlist.uri);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await SpotifyPlaybackController.instance.refresh();
    } catch (_) {
      // Vista previa best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.82;
    final visible = _visiblePlaylists;

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
              l10n.spotifySelectPlaylist,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: FolioSpace.sm),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.spotifySearchPlaylists,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
              ),
            ),
            const SizedBox(height: FolioSpace.sm),
            Expanded(
              child: _buildBody(context, l10n, scheme, visible),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    List<SpotifyPlaylistSummary> visible,
  ) {
    if (_loading) {
      return const Center(child: FolioLoadingIndicator());
    }
    if (_error != null && _playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FolioSpace.sm),
            TextButton.icon(
              onPressed: () => unawaited(_loadPage(reset: true)),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Text(
          l10n.spotifyNoPlaylistsFound,
          style: TextStyle(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount: visible.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: FolioSpace.sm),
            child: Center(child: FolioLoadingIndicator(size: FolioLoadingSize.small)),
          );
        }
        final playlist = visible[index];
        final selected = widget.selectedUri == playlist.uri;
        return _PlaylistTile(
          playlist: playlist,
          selected: selected,
          onSelect: () => Navigator.of(context).pop(playlist),
          onPreview: () => unawaited(_previewPlaylist(playlist)),
          trackCountLabel: playlist.trackCount != null
              ? l10n.spotifyPlaylistTrackCount(playlist.trackCount!)
              : null,
          previewTooltip: l10n.spotifyPreviewPlaylist,
        );
      },
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.selected,
    required this.onSelect,
    required this.onPreview,
    required this.previewTooltip,
    this.trackCountLabel,
  });

  final SpotifyPlaylistSummary playlist;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPreview;
  final String previewTooltip;
  final String? trackCountLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(FolioRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: playlist.imageUrl != null
                    ? Image.network(
                        playlist.imageUrl!,
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
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (trackCountLabel != null)
                      Text(
                        trackCountLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: previewTooltip,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
                onPressed: onPreview,
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22)
              else
                const SizedBox(width: 22),
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
      child: Icon(Icons.queue_music_rounded, color: scheme.onSurfaceVariant),
    );
  }
}
