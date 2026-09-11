import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/media/media_playback_router.dart';
import '../../../services/ytmusic/ytmusic_api_client.dart';
import '../../../services/ytmusic/ytmusic_playback_controller.dart';
import '../spotify/spotify_right_now_playing.dart';

const _kYtRed = Color(0xFFFF0000);

Future<void> openYtMusicLibraryPage({required BuildContext context}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const YtMusicLibraryPage(),
    ),
  );
}

class YtMusicLibraryPage extends StatefulWidget {
  const YtMusicLibraryPage({super.key});

  @override
  State<YtMusicLibraryPage> createState() => _YtMusicLibraryPageState();
}

enum _Tab { home, search, library }

class _YtMusicLibraryPageState extends State<YtMusicLibraryPage> {
  _Tab _tab = _Tab.home;
  bool _loading = true;
  String? _error;
  List<YtMusicPlaylistSummary> _playlists = const [];
  List<YtMusicTrack> _liked = const [];
  final _searchCtrl = TextEditingController();
  YtMusicSearchResults? _search;
  bool _searching = false;
  bool _fullPlayerOpen = false;

  YtMusicApiClient? _client() {
    final conn = YtMusicPlaybackController.instance.activeConnection;
    if (conn == null) return null;
    // Persistence of refreshed tokens requires vault; controller holds connection.
    return YtMusicApiClient(
      connection: conn,
      onConnectionUpdated: (_) {},
    );
  }

  @override
  void initState() {
    super.initState();
    MediaPlaybackRouter.instance.addListenerRef();
    MediaPlaybackRouter.instance.addListener(_onPlayback);
    unawaited(_loadHome());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    MediaPlaybackRouter.instance.removeListener(_onPlayback);
    MediaPlaybackRouter.instance.removeListenerRef();
    super.dispose();
  }

  void _onPlayback() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = _client();
      if (client == null) {
        setState(() {
          _loading = false;
          _error = 'no_connection';
        });
        return;
      }
      final playlists = await client.libraryPlaylists();
      List<YtMusicTrack> liked = const [];
      try {
        liked = await client.likedSongs();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _liked = liked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _runSearch(String q) async {
    final client = _client();
    if (client == null) return;
    setState(() => _searching = true);
    try {
      final res = await client.search(q);
      if (!mounted) return;
      setState(() {
        _search = res;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final wide =
        MediaQuery.sizeOf(context).width >= FolioDesktop.compactBreakpoint;
    final showRail = wide && MediaPlaybackRouter.instance.shouldShowBar;

    if (_fullPlayerOpen && !wide) {
      return SpotifyRightNowPlaying(
        asOverlay: true,
        onClose: () => setState(() => _fullPlayerOpen = false),
      );
    }

    Widget body;
    if (_loading) {
      body = const Center(child: FolioLoadingIndicator());
    } else if (_error != null && _playlists.isEmpty && _liked.isEmpty) {
      body = Center(child: Text(_error!, textAlign: TextAlign.center));
    } else {
      body = switch (_tab) {
        _Tab.home => _buildHome(l10n),
        _Tab.search => _buildSearch(l10n),
        _Tab.library => _buildLibrary(l10n),
      };
    }

    final main = Column(
      children: [
        Expanded(child: body),
        if (!wide && MediaPlaybackRouter.instance.shouldShowBar)
          Material(
            color: scheme.surfaceContainerHighest,
            child: ListTile(
              leading: const Icon(Icons.play_circle_fill, color: _kYtRed),
              title: Text(
                MediaPlaybackRouter.instance.snapshot.title ??
                    l10n.ytmusicReadyIdle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                MediaPlaybackRouter.instance.snapshot.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => setState(() => _fullPlayerOpen = true),
              trailing: IconButton(
                icon: Icon(
                  MediaPlaybackRouter.instance.snapshot.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                onPressed: () =>
                    unawaited(MediaPlaybackRouter.instance.togglePlayPause()),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'appLogos/ytMusic.png',
              width: 22,
              height: 22,
              errorBuilder: (_, _, _) => const Icon(
                Icons.play_circle_filled_rounded,
                color: _kYtRed,
                size: 22,
              ),
            ),
            const SizedBox(width: FolioSpace.xs),
            Text(l10n.ytmusicLibraryTitle),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: showRail
          ? Row(
              children: [
                Expanded(child: main),
                const VerticalDivider(width: 1),
                const SpotifyRightNowPlaying(),
              ],
            )
          : main,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) =>
            setState(() => _tab = _Tab.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.ytmusicHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            label: l10n.ytmusicSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_music_outlined),
            selectedIcon: const Icon(Icons.library_music_rounded),
            label: l10n.ytmusicYourLibrary,
          ),
        ],
      ),
    );
  }

  Widget _buildHome(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(FolioSpace.md),
      children: [
        Text(
          l10n.ytmusicLikedSongs,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        if (_liked.isEmpty)
          Text(l10n.ytmusicEmpty)
        else
          ..._liked.take(20).map(_trackTile),
        const SizedBox(height: 24),
        Text(
          l10n.ytmusicPlaylists,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        ..._playlists.map(_playlistTile),
      ],
    );
  }

  Widget _buildLibrary(AppLocalizations l10n) => _buildHome(l10n);

  Widget _buildSearch(AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(FolioSpace.md),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: l10n.ytmusicSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (q) => unawaited(_runSearch(q)),
          ),
        ),
        if (_searching)
          const Expanded(child: Center(child: FolioLoadingIndicator()))
        else if (_search == null)
          Expanded(child: Center(child: Text(l10n.ytmusicSearchHint)))
        else
          Expanded(
            child: ListView(
              children: [
                ..._search!.songs.map(_trackTile),
                ..._search!.playlists.map(_playlistTile),
              ],
            ),
          ),
      ],
    );
  }

  Widget _trackTile(YtMusicTrack t) {
    return ListTile(
      leading: t.albumArtUrl != null
          ? Image.network(t.albumArtUrl!, width: 48, height: 48, fit: BoxFit.cover)
          : const Icon(Icons.music_note_rounded),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(t.artistLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => unawaited(
        YtMusicPlaybackController.instance.playTrack(t, queue: _liked),
      ),
    );
  }

  Widget _playlistTile(YtMusicPlaylistSummary p) {
    return ListTile(
      leading: p.thumbUrl != null
          ? Image.network(p.thumbUrl!, width: 48, height: 48, fit: BoxFit.cover)
          : const Icon(Icons.queue_music_rounded),
      title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => unawaited(
        YtMusicPlaybackController.instance.playPlaylist(p.id),
      ),
    );
  }
}
