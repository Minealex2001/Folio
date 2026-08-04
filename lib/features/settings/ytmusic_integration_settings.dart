import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/active_music_provider.dart';
import '../../models/ytmusic_integration_state.dart';
import '../../services/media/music_provider_gate.dart';
import '../../services/ytmusic/ytmusic_auth_service.dart';
import '../../session/vault_session.dart';
import '../workspace/ytmusic/ytmusic_library_page.dart';

class YtMusicIntegrationCard extends StatelessWidget {
  const YtMusicIntegrationCard({super.key, required this.session});

  final VaultSession session;
  static const brandColor = Color(0xFFFF0000);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.ytMusicConnections;
        return IntegrationCard(
          logoAsset: 'appLogos/ytMusic.png',
          brandColor: brandColor,
          alpha: true,
          title: 'YouTube Music',
          subtitle: l10n.ytmusicCardSubtitle,
          configureLabel: l10n.ytmusicConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) =>
                        YtMusicIntegrationConfigDialog(session: session),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: Icons.music_note_rounded,
              label: l10n.ytmusicConnectionCount(connections.length),
            ),
          ],
        );
      },
    );
  }
}

class YtMusicIntegrationConfigDialog extends StatefulWidget {
  const YtMusicIntegrationConfigDialog({super.key, required this.session});

  final VaultSession session;

  @override
  State<YtMusicIntegrationConfigDialog> createState() =>
      _YtMusicIntegrationConfigDialogState();
}

class _YtMusicIntegrationConfigDialogState
    extends State<YtMusicIntegrationConfigDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _busy = false;
  String? _userCode;
  String? _error;

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

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.ytmusicExclusiveTitle),
            content: Text(l10n.ytmusicExclusiveBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.ytmusicActivate),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _userCode = null;
    });
    try {
      final auth = YtMusicAuthService();
      final conn = await auth.connect(
        label: 'YouTube Music',
        onUserCode: (code, url) {
          if (mounted) setState(() => _userCode = code);
        },
      );
      widget.session.upsertYtMusicConnection(conn);
      await MusicProviderGate.instance.activate(ActiveMusicProvider.youtubeMusic);
      if (mounted) {
        setState(() {
          _busy = false;
          _userCode = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _activateExisting() async {
    await MusicProviderGate.instance.activate(ActiveMusicProvider.youtubeMusic);
    if (mounted) setState(() {});
  }

  Future<void> _remove(YtMusicConnection c) async {
    widget.session.removeYtMusicConnection(c.id);
    if (widget.session.ytMusicConnections.isEmpty) {
      await MusicProviderGate.instance.activate(ActiveMusicProvider.none);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final connections = widget.session.ytMusicConnections;

    return IntegrationConfigDialogShell(
      logoAsset: 'appLogos/ytMusic.png',
      brandColor: YtMusicIntegrationCard.brandColor,
      alpha: true,
      title: l10n.ytmusicIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.ytmusicConnectionsTab,
      sourcesTabLabel: l10n.ytmusicLibraryTab,
      commandsTabLabel: l10n.ytmusicAboutTab,
      connectionsTab: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(FolioSpace.md),
            children: [
              Text(
                l10n.ytmusicExperimentalNotice,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              if (_userCode != null) ...[
                Text(l10n.ytmusicEnterCode),
                const SizedBox(height: 8),
                SelectableText(
                  _userCode!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _userCode!)),
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(l10n.ytmusicCopyCode),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: scheme.error)),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: FolioLoadingIndicator()),
                )
              else
                FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: Text(l10n.ytmusicConnect),
                ),
              const SizedBox(height: 16),
              for (final c in connections)
                ListTile(
                  leading: const Icon(Icons.account_circle_rounded),
                  title: Text(c.displayName ?? c.label),
                  subtitle: Text(l10n.ytmusicConnectedAccount),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => unawaited(_remove(c)),
                  ),
                ),
              if (connections.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => unawaited(_activateExisting()),
                  child: Text(l10n.ytmusicActivate),
                ),
              ],
            ],
          );
        },
      ),
      sourcesTab: Padding(
        padding: const EdgeInsets.all(FolioSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.ytmusicLibraryHint),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: connections.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      unawaited(openYtMusicLibraryPage(context: context));
                    },
              icon: const Icon(Icons.library_music_rounded),
              label: Text(l10n.ytmusicOpenLibrary),
            ),
          ],
        ),
      ),
      commandsTab: Padding(
        padding: const EdgeInsets.all(FolioSpace.md),
        child: Text(l10n.ytmusicAboutBody),
      ),
    );
  }
}
