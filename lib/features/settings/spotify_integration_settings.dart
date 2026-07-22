import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/spotify/spotify_auth_service.dart';
import '../../services/spotify/spotify_playback_controller.dart';
import '../../session/vault_session.dart';
import 'spotify_playlist_picker.dart';

class SpotifyIntegrationCard extends StatelessWidget {
  const SpotifyIntegrationCard({
    super.key,
    required this.session,
  });

  final VaultSession session;

  static const _brandColor = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.spotifyConnections;
        return IntegrationCard(
          logoAsset: 'appLogos/spotify.png',
          brandColor: _brandColor,
          title: 'Spotify',
          subtitle: l10n.spotifyCardSubtitle,
          configureLabel: l10n.spotifyConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => SpotifyIntegrationConfigDialog(session: session),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: Icons.music_note_rounded,
              label: l10n.spotifyConnectionCount(connections.length),
            ),
          ],
        );
      },
    );
  }
}

class SpotifyIntegrationConfigDialog extends StatefulWidget {
  const SpotifyIntegrationConfigDialog({super.key, required this.session});

  final VaultSession session;

  @override
  State<SpotifyIntegrationConfigDialog> createState() =>
      _SpotifyIntegrationConfigDialogState();
}

class _SpotifyIntegrationConfigDialogState extends State<SpotifyIntegrationConfigDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IntegrationConfigDialogShell(
      logoAsset: 'appLogos/spotify.png',
      brandColor: SpotifyIntegrationCard._brandColor,
      title: l10n.spotifyIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.spotifyConnectionsTab,
      sourcesTabLabel: l10n.spotifyPlaybackTab,
      commandsTabLabel: l10n.spotifyZenTab,
      connectionsTab: _ConnectionsTab(session: widget.session),
      sourcesTab: _PlaybackTab(session: widget.session),
      commandsTab: _ZenTab(session: widget.session),
    );
  }
}

class _ConnectionsTab extends StatefulWidget {
  const _ConnectionsTab({required this.session});
  final VaultSession session;

  @override
  State<_ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends State<_ConnectionsTab> {
  bool _busy = false;
  String? _error;
  SpotifyAuthCancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context);
    if (kIsWeb &&
        Firebase.apps.isNotEmpty &&
        FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _error = l10n.spotifyConnectionFailed(
          'Inicia sesión en Folio Cloud para conectar Spotify.',
        );
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _cancelToken?.cancel();
    _cancelToken = SpotifyAuthCancelToken();
    try {
      final auth = SpotifyAuthService();
      final conn = await auth.connect(
        label: 'Spotify',
        cancelToken: _cancelToken,
      );
      widget.session.upsertSpotifyConnection(conn);
    } on SpotifyAuthCancelledException {
      // Usuario canceló.
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.spotifyConnectionFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conns = widget.session.spotifyConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.spotifyNoConnections)
              : ListView.separated(
                  itemCount: conns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = conns[i];
                    final subtitle = c.displayName ?? c.label;
                    return IntegrationEntryRow(
                      icon: Icons.music_note_rounded,
                      title: l10n.spotifyConnectedAs(subtitle),
                      subtitle: c.spotifyUserId ?? c.id,
                      trailing: [
                        IconButton(
                          tooltip: l10n.spotifyDisconnect,
                          icon: Icon(Icons.link_off_rounded, color: scheme.error),
                          onPressed: _busy
                              ? null
                              : () => widget.session.removeSpotifyConnection(c.id),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.spotifyAuthHelp,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        if (conns.isEmpty)
          ElevatedButton.icon(
            onPressed: _busy ? null : _connect,
            icon: _busy
                ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                : const Icon(Icons.link_rounded),
            label: Text(_busy ? l10n.spotifyConnecting : l10n.spotifyConnectAccount),
          ),
      ],
    );
  }
}

class _PlaybackTab extends StatefulWidget {
  const _PlaybackTab({required this.session});
  final VaultSession session;

  @override
  State<_PlaybackTab> createState() => _PlaybackTabState();
}

class _PlaybackTabState extends State<_PlaybackTab> {
  @override
  void initState() {
    super.initState();
    SpotifyPlaybackController.instance.addListenerRef();
    SpotifyPlaybackController.instance.addListener(_onPlayback);
  }

  @override
  void dispose() {
    SpotifyPlaybackController.instance.removeListener(_onPlayback);
    SpotifyPlaybackController.instance.removeListenerRef();
    super.dispose();
  }

  void _onPlayback() {
    if (mounted) setState(() {});
  }

  Future<void> _openPlaylistPicker() async {
    final conn = widget.session.spotifyConnections.isNotEmpty
        ? widget.session.spotifyConnections.first
        : null;
    if (conn == null) return;
    final picked = await showSpotifyPlaylistPicker(
      context: context,
      session: widget.session,
      selectedUri: conn.focusPlaylistUri,
    );
    if (picked == null || !mounted) return;
    widget.session.upsertSpotifyConnection(
      conn.copyWith(
        focusPlaylistUri: picked.uri,
        focusPlaylistName: picked.name,
      ),
    );
  }

  Future<void> _clearPlaylist() async {
    final conn = widget.session.spotifyConnections.isNotEmpty
        ? widget.session.spotifyConnections.first
        : null;
    if (conn == null) return;
    widget.session.upsertSpotifyConnection(
      conn.copyWith(clearFocusPlaylist: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conns = widget.session.spotifyConnections;
    if (conns.isEmpty) {
      return IntegrationEmptyState(text: l10n.spotifyNoConnections);
    }
    final conn = conns.first;
    final playback = SpotifyPlaybackController.instance;
    final snap = playback.snapshot;
    final hasFocusPlaylist =
        conn.focusPlaylistName != null && conn.focusPlaylistName!.isNotEmpty;

    return ListView(
      children: [
        Text(
          l10n.spotifyNowPlaying,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (snap.premiumRequired)
          Text(l10n.spotifyPremiumRequired, style: TextStyle(color: scheme.error))
        else if (snap.noActiveDevice)
          Text(l10n.spotifyNoActiveDevice, style: TextStyle(color: scheme.onSurfaceVariant))
        else if (snap.noContent || snap.trackName == null)
          Text(l10n.spotifyNothingPlaying, style: TextStyle(color: scheme.onSurfaceVariant))
        else
          IntegrationEntryRow(
            icon: Icons.album_rounded,
            title: snap.trackName!,
            subtitle: snap.artistName ?? '',
            trailing: [
              IconButton(
                tooltip: snap.isPlaying ? l10n.spotifyPause : l10n.spotifyPlay,
                icon: Icon(snap.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: () => unawaited(playback.togglePlayPause()),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          l10n.spotifyFocusPlaylist,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.spotifyFocusPlaylistHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (hasFocusPlaylist)
          IntegrationEntryRow(
            icon: Icons.queue_music_rounded,
            title: conn.focusPlaylistName!,
            subtitle: l10n.spotifySelectedPlaylist,
            trailing: [
              IconButton(
                tooltip: l10n.spotifyChangePlaylist,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => unawaited(_openPlaylistPicker()),
              ),
              IconButton(
                tooltip: l10n.spotifyClearPlaylist,
                icon: Icon(Icons.close_rounded, size: 20, color: scheme.error),
                onPressed: () => unawaited(_clearPlaylist()),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: () => unawaited(_openPlaylistPicker()),
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(l10n.spotifySelectPlaylist),
          ),
      ],
    );
  }
}

class _ZenTab extends StatelessWidget {
  const _ZenTab({required this.session});
  final VaultSession session;

  Future<void> _openPlaylistPicker(BuildContext context) async {
    final conn = session.spotifyConnections.isNotEmpty
        ? session.spotifyConnections.first
        : null;
    if (conn == null) return;
    final picked = await showSpotifyPlaylistPicker(
      context: context,
      session: session,
      selectedUri: conn.focusPlaylistUri,
    );
    if (picked == null) return;
    session.upsertSpotifyConnection(
      conn.copyWith(
        focusPlaylistUri: picked.uri,
        focusPlaylistName: picked.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conns = session.spotifyConnections;
    if (conns.isEmpty) {
      return IntegrationEmptyState(text: l10n.spotifyNoConnections);
    }
    final conn = conns.first;
    final hasFocusPlaylist =
        conn.focusPlaylistName != null && conn.focusPlaylistName!.isNotEmpty;

    return ListView(
      children: [
        if (!hasFocusPlaylist) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: scheme.tertiary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.spotifyNoPlaylistSelected,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(_openPlaylistPicker(context)),
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(l10n.spotifySelectPlaylist),
          ),
          const SizedBox(height: 16),
        ] else ...[
          IntegrationEntryRow(
            icon: Icons.queue_music_rounded,
            title: conn.focusPlaylistName!,
            subtitle: l10n.spotifyFocusPlaylist,
            trailing: [
              IconButton(
                tooltip: l10n.spotifyChangePlaylist,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => unawaited(_openPlaylistPicker(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          title: Text(l10n.spotifyZenAutoPlay),
          subtitle: hasFocusPlaylist
              ? null
              : Text(
                  l10n.spotifyNoPlaylistSelected,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
          value: conn.zenAutoPlay,
          onChanged: hasFocusPlaylist
              ? (v) => session.upsertSpotifyConnection(
                    conn.copyWith(zenAutoPlay: v),
                  )
              : null,
        ),
        SwitchListTile(
          title: Text(l10n.spotifyZenPauseOnExit),
          value: conn.zenPauseOnExit,
          onChanged: (v) => session.upsertSpotifyConnection(
            conn.copyWith(zenPauseOnExit: v),
          ),
        ),
      ],
    );
  }
}
