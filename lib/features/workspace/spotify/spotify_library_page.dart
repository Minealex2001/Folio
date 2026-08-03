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
import '../../../services/spotify/spotify_auth_service.dart';
import '../../../services/spotify/spotify_playback_controller.dart';
import '../../../session/vault_session.dart';
import 'spotify_right_now_playing.dart';

const _kSpotifyGreen = Color(0xFF1DB954);

/// Abre la biblioteca Spotify como pantalla completa.
Future<void> openSpotifyLibraryPage({
  required BuildContext context,
  required VaultSession session,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => SpotifyLibraryPage(session: session),
    ),
  );
}

enum _LibraryTab { home, search, library }

enum _HomeFilter { all, music, podcasts }

enum _DetailKind { liked, playlist, album, artist }

class _DetailTarget {
  const _DetailTarget({
    required this.kind,
    required this.title,
    this.id,
    this.uri,
    this.imageUrl,
    this.subtitle,
  });

  final _DetailKind kind;
  final String title;
  final String? id;
  final String? uri;
  final String? imageUrl;
  final String? subtitle;
}

class SpotifyLibraryPage extends StatefulWidget {
  const SpotifyLibraryPage({super.key, required this.session});

  final VaultSession session;

  @override
  State<SpotifyLibraryPage> createState() => _SpotifyLibraryPageState();
}

class _SpotifyLibraryPageState extends State<SpotifyLibraryPage> {
  _LibraryTab _tab = _LibraryTab.home;
  _HomeFilter _homeFilter = _HomeFilter.all;
  _DetailTarget? _detail;
  bool _reconnecting = false;
  String _displayName = '';

  // Home
  bool _homeLoading = true;
  String? _homeError;
  List<SpotifyTrackSummary> _recent = const [];
  List<SpotifyPlaylistSummary> _playlists = const [];

  // Library tab playlists (paginated)
  bool _libLoading = false;
  bool _libHasMore = false;
  int _libOffset = 0;
  final List<SpotifyPlaylistSummary> _libPlaylists = [];

  // Search
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searchLoading = false;
  SpotifySearchResults _searchResults = const SpotifySearchResults();

  // Detail
  bool _detailLoading = false;
  bool _detailHasMore = false;
  int _detailOffset = 0;
  final List<SpotifyTrackSummary> _detailTracks = [];
  String? _playingId;
  Color? _detailArtColor;
  bool _fullPlayerOpen = false;

  SpotifyApiClient? get _client =>
      SpotifyPlaybackController.instance.apiClientForSettings();

  @override
  void initState() {
    super.initState();
    SpotifyPlaybackController.instance.addListenerRef();
    MediaPlaybackRouter.instance.addListenerRef();
    MediaPlaybackRouter.instance.addListener(_onPlayback);
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadHome());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    MediaPlaybackRouter.instance.removeListener(_onPlayback);
    MediaPlaybackRouter.instance.removeListenerRef();
    SpotifyPlaybackController.instance.removeListenerRef();
    super.dispose();
  }

  void _onPlayback() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHome() async {
    final client = _client;
    if (client == null) {
      setState(() {
        _homeLoading = false;
        _homeError = 'No Spotify connection';
      });
      return;
    }
    setState(() {
      _homeLoading = true;
      _homeError = null;
    });
    try {
      final recent = await client.getRecentlyPlayed(limit: 20);
      final page = await client.listUserPlaylists(limit: 30);
      var name = SpotifyPlaybackController.instance.activeConnection
              ?.displayName
              ?.trim() ??
          '';
      if (name.isEmpty) {
        try {
          final profile = await client.getProfile();
          name = (profile['display_name'] as String? ?? '').trim();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _recent = recent;
        _playlists = page.items;
        if (name.isNotEmpty) _displayName = name;
        _homeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _homeLoading = false;
        _homeError = '$e';
      });
    }
  }

  Future<void> _ensureLibraryLoaded() async {
    if (_libPlaylists.isNotEmpty || _libLoading) return;
    await _loadMoreLibrary(reset: true);
  }

  Future<void> _loadMoreLibrary({bool reset = false}) async {
    final client = _client;
    if (client == null) return;
    if (_libLoading) return;
    setState(() => _libLoading = true);
    try {
      final offset = reset ? 0 : _libOffset;
      final page = await client.listUserPlaylists(limit: 40, offset: offset);
      if (!mounted) return;
      setState(() {
        if (reset) _libPlaylists.clear();
        _libPlaylists.addAll(page.items);
        _libHasMore = page.hasMore;
        _libOffset = page.nextOffset;
      });
    } finally {
      if (mounted) setState(() => _libLoading = false);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = const SpotifySearchResults();
        _searchLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_runSearch(q));
    });
  }

  Future<void> _runSearch(String query) async {
    final client = _client;
    if (client == null) return;
    setState(() => _searchLoading = true);
    try {
      final results = await client.searchCatalog(query);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() => _searchResults = results);
    } catch (_) {
      if (mounted && _searchController.text.trim() == query) {
        setState(() => _searchResults = const SpotifySearchResults());
      }
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _openDetail(_DetailTarget target) async {
    setState(() {
      _detail = target;
      _detailTracks.clear();
      _detailOffset = 0;
      _detailHasMore = false;
      _detailArtColor = null;
    });
    if (target.imageUrl != null && target.imageUrl!.isNotEmpty) {
      unawaited(
        extractSpotifyArtColor(target.imageUrl).then((c) {
          if (!mounted || _detail?.id != target.id) return;
          setState(() => _detailArtColor = c);
        }),
      );
    }
    await _loadDetailTracks(reset: true);
  }

  Future<void> _loadDetailTracks({bool reset = false}) async {
    final client = _client;
    final detail = _detail;
    if (client == null || detail == null) return;
    if (_detailLoading) return;
    setState(() => _detailLoading = true);
    try {
      final offset = reset ? 0 : _detailOffset;
      SpotifyTrackPage page;
      switch (detail.kind) {
        case _DetailKind.liked:
          page = await client.getSavedTracks(limit: 50, offset: offset);
        case _DetailKind.playlist:
          page = await client.getPlaylistTracks(
            detail.id ?? '',
            limit: 50,
            offset: offset,
          );
        case _DetailKind.album:
          page = await client.getAlbumTracks(
            detail.id ?? '',
            limit: 50,
            offset: offset,
            albumArtUrl: detail.imageUrl,
            albumName: detail.title,
          );
        case _DetailKind.artist:
          final tracks = await client.getArtistTopTracks(detail.id ?? '');
          page = SpotifyTrackPage(
            items: tracks,
            hasMore: false,
            nextOffset: tracks.length,
          );
      }
      if (!mounted) return;
      setState(() {
        if (reset) _detailTracks.clear();
        _detailTracks.addAll(page.items);
        _detailHasMore = page.hasMore;
        _detailOffset = page.nextOffset;
      });
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  Future<void> _playTrack(
    SpotifyTrackSummary track, {
    String? contextUri,
  }) async {
    setState(() => _playingId = track.id);
    try {
      final playback = SpotifyPlaybackController.instance;
      if (contextUri != null && contextUri.isNotEmpty) {
        await playback.playContext(
          contextUri: contextUri,
          offsetUri: track.uri,
        );
      } else {
        await playback.playSpotifyRef(type: 'track', id: track.id);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.spotifyPlayTrackFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _playingId = null);
    }
  }

  Future<void> _playAll() async {
    final detail = _detail;
    if (detail == null) return;
    setState(() => _playingId = '__all__');
    try {
      final playback = SpotifyPlaybackController.instance;
      switch (detail.kind) {
        case _DetailKind.liked:
          if (_detailTracks.isEmpty) return;
          await playback.playUris(
            _detailTracks.take(50).map((t) => t.uri).toList(),
          );
        case _DetailKind.playlist:
        case _DetailKind.album:
          final uri = detail.uri;
          if (uri == null || uri.isEmpty) return;
          await playback.playContext(contextUri: uri);
        case _DetailKind.artist:
          if (_detailTracks.isEmpty) return;
          await playback.playUris(
            _detailTracks.take(50).map((t) => t.uri).toList(),
          );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.spotifyPlayTrackFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _playingId = null);
    }
  }

  Future<void> _openExternalSpotify() async {
    final snap = MediaPlaybackRouter.instance.snapshot;
    final trackUri = snap.externalUrl;
    Uri web;
    if (trackUri != null && trackUri.startsWith('spotify:')) {
      final parts = trackUri.split(':');
      if (parts.length >= 3) {
        web = Uri.https('open.spotify.com', '/${parts[1]}/${parts[2]}');
      } else {
        web = Uri.https('open.spotify.com', '/');
      }
    } else if (trackUri != null && trackUri.startsWith('http')) {
      web = Uri.tryParse(trackUri) ?? Uri.https('open.spotify.com', '/');
    } else {
      web = Uri.https('open.spotify.com', '/');
    }
    if (!await launchUrl(web, mode: LaunchMode.externalApplication)) {
      await launchUrl(web, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _reconnect() async {
    final conns = widget.session.spotifyConnections;
    if (conns.isEmpty) return;
    final conn = conns.first;
    setState(() => _reconnecting = true);
    try {
      final auth = SpotifyAuthService();
      final fresh = await auth.connect(label: conn.label);
      widget.session.upsertSpotifyConnection(
        conn.copyWith(
          accessToken: fresh.accessToken,
          refreshToken: fresh.refreshToken,
          expiresAt: fresh.expiresAt,
          grantedScopes: fresh.grantedScopes,
          spotifyUserId: fresh.spotifyUserId,
          displayName: fresh.displayName,
        ),
      );
      await _loadHome();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  void _selectTab(_LibraryTab tab) {
    setState(() {
      _detail = null;
      _tab = tab;
    });
    if (tab == _LibraryTab.library) {
      unawaited(_ensureLibraryLoaded());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final missing =
        SpotifyPlaybackController.instance.missingLibraryScopes;
    final wide =
        MediaQuery.sizeOf(context).width >= FolioDesktop.compactBreakpoint;
    final showRightRail = wide && MediaPlaybackRouter.instance.shouldShowBar;

    final mainContent = Column(
      children: [
        if (missing.isNotEmpty)
          Material(
            color: scheme.tertiaryContainer.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FolioSpace.md,
                vertical: FolioSpace.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: FolioSpace.xs),
                  Expanded(
                    child: Text(
                      l10n.spotifyLibraryReconnectRequired,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reconnecting
                        ? null
                        : () => unawaited(_reconnect()),
                    child: _reconnecting
                        ? const FolioLoadingIndicator(
                            size: FolioLoadingSize.small,
                          )
                        : Text(l10n.spotifyReconnectButton),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _detail != null
              ? _buildDetail(context, l10n, scheme)
              : switch (_tab) {
                  _LibraryTab.home => _buildHome(context, l10n, scheme),
                  _LibraryTab.search => _buildSearch(context, l10n, scheme),
                  _LibraryTab.library =>
                    _buildLibraryTab(context, l10n, scheme),
                },
        ),
        if (!wide)
          _LibraryMiniPlayer(
            scheme: scheme,
            l10n: l10n,
            onOpenFullPlayer: () => setState(() => _fullPlayerOpen = true),
          ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
      backgroundColor: scheme.surface,
      appBar: _detail != null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                tooltip: l10n.spotifyCloseLibrary,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Row(
                children: [
                  Image.asset(
                    'appLogos/spotify.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.music_note_rounded,
                      color: _kSpotifyGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: FolioSpace.xs),
                  Text(
                    _tab == _LibraryTab.home
                        ? l10n.spotifyLibraryGoodEvening
                        : l10n.spotifyLibraryTitle,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.spotifyOpenInSpotify,
                  icon: const Icon(Icons.open_in_new_rounded),
                  onPressed: () => unawaited(_openExternalSpotify()),
                ),
              ],
            ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _detail != null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.14),
                    scheme.surface,
                    scheme.surface,
                  ],
                  stops: const [0, 0.28, 1],
                ),
          color: _detail != null ? scheme.surface : null,
        ),
        child: showRightRail
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: mainContent),
                  const VerticalDivider(width: 1),
                  const SpotifyRightNowPlaying(),
                ],
              )
            : mainContent,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _selectTab(_LibraryTab.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.spotifyLibraryHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: const Icon(Icons.search_rounded),
            label: l10n.spotifyLibrarySearchTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_music_outlined),
            selectedIcon: const Icon(Icons.library_music_rounded),
            label: l10n.spotifyLibraryYourLibrary,
          ),
        ],
      ),
        ),
        if (!wide)
          Positioned.fill(
            child: SpotifyFullPlayerReveal(
              visible: _fullPlayerOpen,
              child: SpotifyRightNowPlaying(
                asOverlay: true,
                onClose: () => setState(() => _fullPlayerOpen = false),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHome(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    if (_homeLoading) {
      return const Center(child: FolioLoadingIndicator());
    }
    if (_homeError != null && _recent.isEmpty && _playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(FolioSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _homeError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: FolioSpace.sm),
              FilledButton.tonal(
                onPressed: () => unawaited(_loadHome()),
                child: Text(l10n.spotifyReconnectButton),
              ),
            ],
          ),
        ),
      );
    }

    if (_homeFilter == _HomeFilter.podcasts) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHomeFilterChips(l10n, scheme),
          Expanded(
            child: Center(
              child: Text(
                l10n.spotifyLibraryPodcastsEmpty,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      );
    }

    final quickItems = _buildQuickAccessItems(l10n);
    final madeForName =
        _displayName.isNotEmpty ? _displayName : l10n.spotifyBrandName;
    final playingUri = MediaPlaybackRouter.instance.snapshot.externalUrl;

    return RefreshIndicator(
      onRefresh: _loadHome,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHomeFilterChips(l10n, scheme)),
          if (quickItems.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.md,
                FolioSpace.xs,
                FolioSpace.md,
                FolioSpace.md,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 58,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = quickItems[i];
                    final isPlaying = item.playingMatch != null &&
                        playingUri != null &&
                        playingUri.contains(item.playingMatch!);
                    final scheme = Theme.of(context).colorScheme;
                    return _QuickAccessTile(
                      title: item.title,
                      imageUrl: item.imageUrl,
                      leading: item.liked
                          ? Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.secondary.withValues(alpha: 0.9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: scheme.onPrimary,
                                size: 22,
                              ),
                            )
                          : null,
                      isPlaying: isPlaying,
                      busy: item.busyId != null && _playingId == item.busyId,
                      onTap: item.onTap,
                    );
                  },
                  childCount: quickItems.length.clamp(0, 8),
                ),
              ),
            ),
          if (_playlists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _ShelfHeader(
                title: l10n.spotifyLibraryMadeFor(madeForName),
                actionLabel: l10n.spotifyLibraryShowAll,
                onAction: () => _selectTab(_LibraryTab.library),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: FolioSpace.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: _playlists.length.clamp(0, 12),
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: FolioSpace.sm),
                  itemBuilder: (context, i) {
                    final p = _playlists[i];
                    return _ShelfCard(
                      title: p.name,
                      subtitle: p.trackCount != null
                          ? l10n.spotifyPlaylistTrackCount(p.trackCount!)
                          : '',
                      imageUrl: p.imageUrl,
                      accentColor: _shelfAccent(i, scheme),
                      onTap: () => unawaited(
                        _openDetail(
                          _DetailTarget(
                            kind: _DetailKind.playlist,
                            title: p.name,
                            id: p.id,
                            uri: p.uri,
                            imageUrl: p.imageUrl,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: FolioSpace.lg)),
          ],
          if (_recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _ShelfHeader(
                title: l10n.spotifyLibraryDiveBack,
                actionLabel: l10n.spotifyLibraryShowAll,
                onAction: () => _selectTab(_LibraryTab.library),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: FolioSpace.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: _recent.length.clamp(0, 12),
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: FolioSpace.sm),
                  itemBuilder: (context, i) {
                    final t = _recent[i];
                    return _ShelfCard(
                      title: t.name,
                      subtitle: t.artistName,
                      imageUrl: t.albumArtUrl,
                      accentColor: _shelfAccent(i + 3, scheme),
                      onTap: () => unawaited(_playTrack(t)),
                      busy: _playingId == t.id,
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: FolioSpace.lg)),
          ],
          if (_playlists.isEmpty && _recent.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  l10n.spotifyLibraryEmpty,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeFilterChips(AppLocalizations l10n, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FolioSpace.md,
        FolioSpace.xs,
        FolioSpace.md,
        FolioSpace.sm,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FilterChip(
            label: l10n.spotifyLibraryFilterAll,
            selected: _homeFilter == _HomeFilter.all,
            onTap: () => setState(() => _homeFilter = _HomeFilter.all),
          ),
          _FilterChip(
            label: l10n.spotifyLibraryFilterMusic,
            selected: _homeFilter == _HomeFilter.music,
            onTap: () => setState(() => _homeFilter = _HomeFilter.music),
          ),
          _FilterChip(
            label: l10n.spotifyLibraryFilterPodcasts,
            selected: _homeFilter == _HomeFilter.podcasts,
            onTap: () => setState(() => _homeFilter = _HomeFilter.podcasts),
          ),
        ],
      ),
    );
  }

  List<_QuickAccessItem> _buildQuickAccessItems(AppLocalizations l10n) {
    final items = <_QuickAccessItem>[];
    items.add(
      _QuickAccessItem(
        title: l10n.spotifyLibraryLikedSongs,
        liked: true,
        onTap: () => unawaited(
          _openDetail(
            _DetailTarget(
              kind: _DetailKind.liked,
              title: l10n.spotifyLibraryLikedSongs,
            ),
          ),
        ),
      ),
    );

    final seen = <String>{};
    for (final t in _recent) {
      if (items.length >= 8) break;
      if (!seen.add(t.id)) continue;
      items.add(
        _QuickAccessItem(
          title: t.name,
          imageUrl: t.albumArtUrl,
          busyId: t.id,
          playingMatch: t.id,
          onTap: () => unawaited(_playTrack(t)),
        ),
      );
    }
    for (final p in _playlists) {
      if (items.length >= 8) break;
      if (!seen.add(p.id)) continue;
      items.add(
        _QuickAccessItem(
          title: p.name,
          imageUrl: p.imageUrl,
          playingMatch: p.id,
          onTap: () => unawaited(
            _openDetail(
              _DetailTarget(
                kind: _DetailKind.playlist,
                title: p.name,
                id: p.id,
                uri: p.uri,
                imageUrl: p.imageUrl,
              ),
            ),
          ),
        ),
      );
    }
    return items;
  }

  Color _shelfAccent(int index, ColorScheme scheme) {
    final accents = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      _kSpotifyGreen,
      scheme.primaryContainer,
    ];
    return accents[index % accents.length];
  }

  Widget _buildSearch(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final q = _searchController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FolioSpace.md,
            FolioSpace.sm,
            FolioSpace.md,
            FolioSpace.sm,
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: l10n.spotifyLibrarySearchPrompt,
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ),
        ),
        Expanded(
          child: _searchLoading && _searchResults.isEmpty
              ? const Center(child: FolioLoadingIndicator())
              : q.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(FolioSpace.lg),
                        child: Text(
                          l10n.spotifyLibrarySearchPrompt,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            l10n.spotifyLibraryNoResults,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            FolioSpace.md,
                            0,
                            FolioSpace.md,
                            FolioSpace.md,
                          ),
                          children: [
                            if (_searchResults.tracks.isNotEmpty) ...[
                              _SectionTitle(l10n.spotifyLibraryTracks),
                              const SizedBox(height: FolioSpace.xs),
                              ..._searchResults.tracks.map(
                                (t) => _PlaylistTrackRow(
                                  index: null,
                                  track: t,
                                  showAlbumArt: true,
                                  showAlbumName: true,
                                  busy: _playingId == t.id,
                                  isActive: _isTrackActive(t),
                                  onTap: () => unawaited(_playTrack(t)),
                                ),
                              ),
                              const SizedBox(height: FolioSpace.md),
                            ],
                            if (_searchResults.albums.isNotEmpty) ...[
                              _SectionTitle(l10n.spotifyLibraryAlbums),
                              const SizedBox(height: FolioSpace.xs),
                              SizedBox(
                                height: 200,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _searchResults.albums.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: FolioSpace.sm),
                                  itemBuilder: (context, i) {
                                    final a = _searchResults.albums[i];
                                    return _ShelfCard(
                                      title: a.name,
                                      subtitle: a.artistName,
                                      imageUrl: a.imageUrl,
                                      accentColor: _shelfAccent(i, scheme),
                                      onTap: () => unawaited(
                                        _openDetail(
                                          _DetailTarget(
                                            kind: _DetailKind.album,
                                            title: a.name,
                                            id: a.id,
                                            uri: a.uri,
                                            imageUrl: a.imageUrl,
                                            subtitle: a.artistName,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: FolioSpace.md),
                            ],
                            if (_searchResults.artists.isNotEmpty) ...[
                              _SectionTitle(l10n.spotifyLibraryArtists),
                              const SizedBox(height: FolioSpace.xs),
                              ..._searchResults.artists.map(
                                (a) => _MediaRow(
                                  title: a.name,
                                  subtitle: l10n.spotifyLibraryArtists,
                                  imageUrl: a.imageUrl,
                                  circular: true,
                                  onTap: () => unawaited(
                                    _openDetail(
                                      _DetailTarget(
                                        kind: _DetailKind.artist,
                                        title: a.name,
                                        id: a.id,
                                        uri: a.uri,
                                        imageUrl: a.imageUrl,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: FolioSpace.md),
                            ],
                            if (_searchResults.playlists.isNotEmpty) ...[
                              _SectionTitle(l10n.spotifyLibraryPlaylists),
                              const SizedBox(height: FolioSpace.xs),
                              SizedBox(
                                height: 200,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _searchResults.playlists.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: FolioSpace.sm),
                                  itemBuilder: (context, i) {
                                    final p = _searchResults.playlists[i];
                                    return _ShelfCard(
                                      title: p.name,
                                      subtitle: p.trackCount != null
                                          ? l10n.spotifyPlaylistTrackCount(
                                              p.trackCount!,
                                            )
                                          : '',
                                      imageUrl: p.imageUrl,
                                      accentColor: _shelfAccent(i + 2, scheme),
                                      onTap: () => unawaited(
                                        _openDetail(
                                          _DetailTarget(
                                            kind: _DetailKind.playlist,
                                            title: p.name,
                                            id: p.id,
                                            uri: p.uri,
                                            imageUrl: p.imageUrl,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }

  bool _isTrackActive(SpotifyTrackSummary track) {
    final uri = MediaPlaybackRouter.instance.snapshot.externalUrl;
    if (uri == null || uri.isEmpty) return false;
    return uri.contains(track.id);
  }

  String _detailTypeLabel(AppLocalizations l10n, _DetailKind kind) {
    return switch (kind) {
      _DetailKind.album => l10n.spotifyLibraryTypeAlbum,
      _DetailKind.playlist || _DetailKind.liked =>
        l10n.spotifyLibraryTypePlaylist,
      _DetailKind.artist => l10n.spotifyLibraryTypeArtist,
    };
  }

  String _formatCollectionDuration(AppLocalizations l10n) {
    final totalMs =
        _detailTracks.fold<int>(0, (sum, t) => sum + t.durationMs);
    final totalMin = totalMs ~/ 60000;
    if (totalMin >= 60) {
      return l10n.spotifyLibraryDurationHours(totalMin ~/ 60, totalMin % 60);
    }
    return l10n.spotifyLibraryDurationTotal(totalMin);
  }

  Widget _buildDetail(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final detail = _detail!;
    final headerBg = _detailArtColor != null
        ? spotifyArtColorBackground(_detailArtColor!, darkness: 0.35)
        : scheme.surfaceContainerHighest;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final showAlbumCol = wide &&
        (detail.kind == _DetailKind.playlist ||
            detail.kind == _DetailKind.liked);
    final showArtInRows = detail.kind != _DetailKind.album;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 200 &&
            _detailHasMore &&
            !_detailLoading) {
          unawaited(_loadDetailTracks());
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    headerBg,
                    scheme.surface,
                    scheme.surface,
                  ],
                  stops: const [0, 0.85, 1],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FolioSpace.md,
                    FolioSpace.xs,
                    FolioSpace.md,
                    FolioSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: l10n.spotifyCloseLibrary,
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => setState(() {
                            _detail = null;
                            _detailArtColor = null;
                          }),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final artSize =
                              (constraints.maxWidth < 520 ? 160.0 : 208.0);
                          final meta = Column(
                            crossAxisAlignment: wide
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.center,
                            children: [
                              Text(
                                _detailTypeLabel(l10n, detail.kind),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                detail.title,
                                textAlign:
                                    wide ? TextAlign.start : TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                      fontSize: wide ? 48 : 32,
                                    ),
                              ),
                              if (detail.subtitle != null &&
                                  detail.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  detail.subtitle!,
                                  textAlign: wide
                                      ? TextAlign.start
                                      : TextAlign.center,
                                  style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                [
                                  if (_detailTracks.isNotEmpty)
                                    l10n.spotifyPlaylistTrackCount(
                                      _detailTracks.length,
                                    ),
                                  if (_detailTracks.isNotEmpty)
                                    _formatCollectionDuration(l10n),
                                ].join(' • '),
                                textAlign:
                                    wide ? TextAlign.start : TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          );

                          final cover = ClipRRect(
                            borderRadius:
                                BorderRadius.circular(FolioRadius.sm),
                            child: detail.imageUrl != null
                                ? Image.network(
                                    detail.imageUrl!,
                                    width: artSize,
                                    height: artSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _artFallback(scheme, artSize),
                                  )
                                : detail.kind == _DetailKind.liked
                                    ? Container(
                                        width: artSize,
                                        height: artSize,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              scheme.primary,
                                              scheme.secondary,
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.favorite_rounded,
                                          size: artSize * 0.35,
                                          color: scheme.onPrimary,
                                        ),
                                      )
                                    : _artFallback(scheme, artSize),
                          );

                          if (!wide) {
                            return Column(
                              children: [
                                cover,
                                const SizedBox(height: FolioSpace.md),
                                meta,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              cover,
                              const SizedBox(width: FolioSpace.lg),
                              Expanded(child: meta),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: FolioSpace.md),
                      Row(
                        children: [
                          Material(
                            color: _kSpotifyGreen,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _playingId == '__all__'
                                  ? null
                                  : () => unawaited(_playAll()),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Center(
                                  child: _playingId == '__all__'
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 36,
                                          color: Colors.black,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: FolioSpace.sm),
                          IconButton(
                            tooltip: l10n.spotifyOpenInSpotify,
                            onPressed: () =>
                                unawaited(_openExternalSpotify()),
                            icon: const Icon(Icons.open_in_new_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_detailLoading && _detailTracks.isEmpty)
            const SliverFillRemaining(
              child: Center(child: FolioLoadingIndicator()),
            )
          else if (_detailTracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  l10n.spotifyLibraryEmpty,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.md,
                  FolioSpace.sm,
                  FolioSpace.md,
                  FolioSpace.xs,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: showAlbumCol ? 3 : 1,
                      child: Text(
                        l10n.spotifyLibraryTitleColumn,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (showAlbumCol)
                      Expanded(
                        flex: 2,
                        child: Text(
                          l10n.spotifyLibraryAlbumColumn,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 52,
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i >= _detailTracks.length) {
                    return const Padding(
                      padding: EdgeInsets.all(FolioSpace.md),
                      child: Center(
                        child: FolioLoadingIndicator(
                          size: FolioLoadingSize.small,
                        ),
                      ),
                    );
                  }
                  final t = _detailTracks[i];
                  return _PlaylistTrackRow(
                    index: i + 1,
                    track: t,
                    showAlbumArt: showArtInRows,
                    showAlbumName: showAlbumCol,
                    busy: _playingId == t.id,
                    isActive: _isTrackActive(t),
                    onTap: () => unawaited(
                      _playTrack(t, contextUri: detail.uri),
                    ),
                  );
                },
                childCount:
                    _detailTracks.length + (_detailLoading ? 1 : 0),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: FolioSpace.lg)),
          ],
        ],
      ),
    );
  }

  Widget _buildLibraryTab(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 200 &&
            _libHasMore &&
            !_libLoading) {
          unawaited(_loadMoreLibrary());
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.md,
          FolioSpace.sm,
          FolioSpace.md,
          FolioSpace.md,
        ),
        children: [
          _MediaRow(
            title: l10n.spotifyLibraryLikedSongs,
            subtitle: l10n.spotifyLibraryTracks,
            leading: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FolioRadius.sm),
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.secondary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: scheme.onPrimary,
                size: 24,
              ),
            ),
            onTap: () => unawaited(
              _openDetail(
                _DetailTarget(
                  kind: _DetailKind.liked,
                  title: l10n.spotifyLibraryLikedSongs,
                ),
              ),
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          _SectionTitle(l10n.spotifyLibraryYourPlaylists),
          const SizedBox(height: FolioSpace.xs),
          if (_libPlaylists.isEmpty && _libLoading)
            const Padding(
              padding: EdgeInsets.all(FolioSpace.lg),
              child: Center(child: FolioLoadingIndicator()),
            )
          else if (_libPlaylists.isEmpty)
            _EmptyHint(l10n.spotifyLibraryEmpty, scheme)
          else
            ..._libPlaylists.map(
              (p) => _MediaRow(
                title: p.name,
                subtitle: p.trackCount != null
                    ? l10n.spotifyPlaylistTrackCount(p.trackCount!)
                    : '',
                imageUrl: p.imageUrl,
                onTap: () => unawaited(
                  _openDetail(
                    _DetailTarget(
                      kind: _DetailKind.playlist,
                      title: p.name,
                      id: p.id,
                      uri: p.uri,
                      imageUrl: p.imageUrl,
                    ),
                  ),
                ),
              ),
            ),
          if (_libLoading && _libPlaylists.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(FolioSpace.md),
              child: Center(
                child: FolioLoadingIndicator(size: FolioLoadingSize.small),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Mini player sticky ──────────────────────────────────────────────────────

class _LibraryMiniPlayer extends StatelessWidget {
  const _LibraryMiniPlayer({
    required this.scheme,
    required this.l10n,
    this.onOpenFullPlayer,
  });

  final ColorScheme scheme;
  final AppLocalizations l10n;
  final VoidCallback? onOpenFullPlayer;

  @override
  Widget build(BuildContext context) {
    final router = MediaPlaybackRouter.instance;
    final snap = router.snapshot;
    if (!router.shouldShowBar || !snap.hasTrack) {
      return const SizedBox.shrink();
    }
    final title = snap.title ?? '';
    final artist = snap.artist ?? '';
    final onFolio = snap.sourceId == NowPlayingSourceId.spotify;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.97),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onFolio)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.spotifyLibraryPlayingOnFolio,
                    style: const TextStyle(
                      color: _kSpotifyGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FolioSpace.sm,
                vertical: FolioSpace.xxs,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: onOpenFullPlayer,
                    borderRadius: BorderRadius.circular(FolioRadius.xs),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(FolioRadius.xs),
                      child: snap.albumArtUrl != null
                          ? Image.network(
                              snap.albumArtUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _artFallback(scheme, 40),
                            )
                          : snap.albumArtBytes != null
                              ? Image.memory(
                                  snap.albumArtBytes!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                )
                              : _artFallback(scheme, 40),
                    ),
                  ),
                  const SizedBox(width: FolioSpace.xs),
                  Expanded(
                    child: InkWell(
                      onTap: onOpenFullPlayer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: onFolio ? _kSpotifyGreen : null,
                            ),
                          ),
                          if (artist.isNotEmpty)
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                    icon: Icon(
                      snap.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: () => unawaited(router.togglePlayPause()),
                  ),
                  IconButton(
                    tooltip: l10n.spotifySkipNext,
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: !snap.canSkip
                        ? null
                        : () => unawaited(router.skipNext()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _QuickAccessItem {
  const _QuickAccessItem({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.busyId,
    this.playingMatch,
    this.liked = false,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? busyId;
  final String? playingMatch;
  final bool liked;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.onSurface
          : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.surface : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.leading,
    this.isPlaying = false,
    this.busy = false,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageUrl;
  final Widget? leading;
  final bool isPlaying;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(FolioRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Row(
          children: [
            leading ??
                (imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _artFallback(scheme, 58),
                      )
                    : _artFallback(scheme, 58)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: FolioLoadingIndicator(size: FolioLoadingSize.small),
              )
            else if (isPlaying)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 18,
                  color: _kSpotifyGreen,
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FolioSpace.md,
        FolioSpace.xs,
        FolioSpace.sm,
        FolioSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accentColor,
    this.imageUrl,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final Color accentColor;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 148,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(FolioRadius.md),
          onTap: busy ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(FolioRadius.md),
                    child: SizedBox(
                      width: 148,
                      height: 148,
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _artFallback(scheme, 148),
                            )
                          : _artFallback(scheme, 148),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Image.asset(
                      'appLogos/spotify.png',
                      width: 16,
                      height: 16,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.music_note_rounded,
                        size: 14,
                        color: _kSpotifyGreen,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor.withValues(alpha: 0),
                            accentColor.withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (busy)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: const Center(
                          child: FolioLoadingIndicator(
                            size: FolioLoadingSize.small,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text, this.scheme);
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FolioSpace.sm),
      child: Text(
        text,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      ),
    );
  }
}

class _PlaylistTrackRow extends StatelessWidget {
  const _PlaylistTrackRow({
    required this.track,
    required this.onTap,
    this.index,
    this.showAlbumArt = true,
    this.showAlbumName = false,
    this.busy = false,
    this.isActive = false,
  });

  final int? index;
  final SpotifyTrackSummary track;
  final VoidCallback onTap;
  final bool showAlbumArt;
  final bool showAlbumName;
  final bool busy;
  final bool isActive;

  String _formatMs(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 999 * 60);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = isActive ? _kSpotifyGreen : scheme.onSurface;
    final indexColor = isActive ? _kSpotifyGreen : scheme.onSurfaceVariant;

    return Material(
      color: isActive
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
          : Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FolioSpace.md,
            vertical: 8,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: busy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : isActive
                        ? Icon(
                            Icons.graphic_eq_rounded,
                            size: 18,
                            color: indexColor,
                          )
                        : Text(
                            index?.toString() ?? '',
                            style: TextStyle(
                              color: indexColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
              ),
              if (showAlbumArt) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: track.albumArtUrl != null
                      ? Image.network(
                          track.albumArtUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _artFallback(scheme, 40),
                        )
                      : _artFallback(scheme, 40),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: showAlbumName ? 3 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      track.artistName,
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
              if (showAlbumName)
                Expanded(
                  flex: 2,
                  child: Text(
                    track.albumName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              SizedBox(
                width: 52,
                child: Text(
                  _formatMs(track.durationMs),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.imageUrl,
    this.leading,
    this.circular = false,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final Widget? leading;
  final VoidCallback onTap;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius =
        circular ? BorderRadius.circular(999) : BorderRadius.circular(6);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              leading ??
                  ClipRRect(
                    borderRadius: radius,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _artFallback(scheme, 48, circular: circular),
                          )
                        : _artFallback(scheme, 48, circular: circular),
                  ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
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
            ],
          ),
        ),
      ),
    );
  }
}

Widget _artFallback(ColorScheme scheme, double size, {bool circular = false}) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius:
          circular ? BorderRadius.circular(999) : BorderRadius.circular(6),
    ),
    child: Icon(
      Icons.music_note_rounded,
      color: scheme.onSurfaceVariant,
      size: size * 0.4,
    ),
  );
}
