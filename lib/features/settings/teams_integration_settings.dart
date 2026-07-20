import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/teams_integration_state.dart';
import '../../services/teams/teams_api_client.dart';
import '../../session/vault_session.dart';
import 'integration_commands_tab.dart';

class TeamsIntegrationCard extends StatelessWidget {
  const TeamsIntegrationCard({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.teamsConnections;
        return IntegrationCard(
          logoAsset: 'appLogos/microsoftTeams.png',
          brandColor: const Color(0xFF6264A7),
          beta: true,
          title: 'Microsoft Teams',
          subtitle: l10n.teamsCardSubtitle,
          configureLabel: l10n.teamsConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => TeamsIntegrationConfigDialog(session: session),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: Icons.link_rounded,
              label: l10n.teamsConnectionCount(connections.length),
            ),
          ],
        );
      },
    );
  }
}

class TeamsIntegrationConfigDialog extends StatefulWidget {
  const TeamsIntegrationConfigDialog({super.key, required this.session});

  final VaultSession session;

  @override
  State<TeamsIntegrationConfigDialog> createState() => _TeamsIntegrationConfigDialogState();
}

class _TeamsIntegrationConfigDialogState extends State<TeamsIntegrationConfigDialog>
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
      logoAsset: 'appLogos/microsoftTeams.png',
      brandColor: const Color(0xFF6264A7),
      beta: true,
      title: l10n.teamsIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.teamsConnectionsTab,
      sourcesTabLabel: l10n.teamsNotificationsTab,
      commandsTabLabel: l10n.teamsCommandsTab,
      connectionsTab: _ConnectionsTab(session: widget.session),
      sourcesTab: _NotificationsTab(session: widget.session),
      commandsTab: TeamsIntegrationCommandsTab(session: widget.session),
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
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    if (_adding) {
      return _AddConnectionForm(
        session: widget.session,
        onCancel: () => setState(() => _adding = false),
        onDone: () => setState(() => _adding = false),
      );
    }

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conns = widget.session.teamsConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.teamsNoConnections)
              : ListView.separated(
                  itemCount: conns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = conns[i];
                    return IntegrationEntryRow(
                      icon: Icons.groups_rounded,
                      title: c.label,
                      subtitle: c.webhookUrl,
                      trailing: [
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeTeamsConnection(c.id),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => setState(() => _adding = true),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.teamsAddConnection),
        ),
      ],
    );
  }
}

class _AddConnectionForm extends StatefulWidget {
  const _AddConnectionForm({
    required this.session,
    required this.onCancel,
    required this.onDone,
  });
  final VaultSession session;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_AddConnectionForm> createState() => _AddConnectionFormState();
}

class _AddConnectionFormState extends State<_AddConnectionForm> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _webhookCtrl = TextEditingController();
  final _outgoingTokenCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _webhookCtrl.dispose();
    _outgoingTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWebhookDocs() async {
    final uri = Uri.parse(
      'https://support.microsoft.com/en-us/office/'
      'create-incoming-webhooks-with-workflows-for-microsoft-teams-8ae491c7-0394-4861-ba59-055e33f75498',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.teamsNewConnectionTitle,
            onBack: _busy ? () {} : widget.onCancel,
          ),
          const SizedBox(height: 10),
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _labelCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.teamsConnectionName,
                    hintText: l10n.teamsConnectionNameHint,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.teamsRequired : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _webhookCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.teamsWebhookUrlLabel,
                    suffixIcon: IconButton(
                      tooltip: l10n.teamsGetWebhookUrl,
                      icon: const Icon(Icons.open_in_new_rounded),
                      onPressed: _openWebhookDocs,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.teamsRequired : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _outgoingTokenCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.integrationTeamsOutgoingTokenLabel,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.teamsAuthHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : widget.onCancel,
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : Text(l10n.teamsConnectAndSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    final label = _labelCtrl.text.trim();
    final webhookUrl = _webhookCtrl.text.trim();

    final tempConn = TeamsConnection(
      id: const Uuid().v4(),
      label: label,
      webhookUrl: webhookUrl,
      outgoingWebhookToken: _outgoingTokenCtrl.text.trim(),
    );

    try {
      final client = TeamsApiClient(connection: tempConn);
      await client.verifyConnection(testMessage: l10n.integrationWebhookVerifyConnected);

      widget.session.upsertTeamsConnection(tempConn);
      if (mounted) {
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = l10n.integrationWebhookConnectionFailed('$e');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({required this.session});
  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conns = session.teamsConnections;
    if (conns.isEmpty) {
      return IntegrationEmptyState(text: l10n.teamsNoConnections);
    }
    return ListView.separated(
      itemCount: conns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = conns[i];
        return IntegrationEntryRow(
          icon: Icons.groups_rounded,
          title: c.label,
          subtitle: c.webhookUrl,
          subtitleMaxLines: 1,
          extra: IntegrationImportOptionsChips(
            options: [
              IntegrationImportOption(
                label: l10n.teamsNotifyOnStatusChange,
                selected: c.notifyOnStatusChange,
                onChanged: (v) => session.upsertTeamsConnection(
                  c.copyWith(notifyOnStatusChange: v),
                ),
              ),
              IntegrationImportOption(
                label: l10n.teamsNotifyOnNewTask,
                selected: c.notifyOnNewTask,
                onChanged: (v) => session.upsertTeamsConnection(
                  c.copyWith(notifyOnNewTask: v),
                ),
              ),
              IntegrationImportOption(
                label: l10n.teamsNotifyOnComment,
                selected: c.notifyOnComment,
                onChanged: (v) => session.upsertTeamsConnection(
                  c.copyWith(notifyOnComment: v),
                ),
              ),
            ],
          ),
          trailing: const [],
        );
      },
    );
  }
}
