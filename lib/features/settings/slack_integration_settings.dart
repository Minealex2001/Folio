import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/slack_integration_state.dart';
import '../../services/slack/slack_api_client.dart';
import '../../session/vault_session.dart';
import 'integration_commands_tab.dart';

class SlackIntegrationCard extends StatelessWidget {
  const SlackIntegrationCard({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.slackConnections;
        return IntegrationCard(
          logoAsset: 'appLogos/slack.png',
          brandColor: const Color(0xFF4A154B),
          beta: true,
          title: 'Slack',
          subtitle: l10n.slackCardSubtitle,
          configureLabel: l10n.slackConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => SlackIntegrationConfigDialog(session: session),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: Icons.link_rounded,
              label: l10n.slackConnectionCount(connections.length),
            ),
          ],
        );
      },
    );
  }
}

class SlackIntegrationConfigDialog extends StatefulWidget {
  const SlackIntegrationConfigDialog({super.key, required this.session});

  final VaultSession session;

  @override
  State<SlackIntegrationConfigDialog> createState() => _SlackIntegrationConfigDialogState();
}

class _SlackIntegrationConfigDialogState extends State<SlackIntegrationConfigDialog>
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
      logoAsset: 'appLogos/slack.png',
      brandColor: const Color(0xFF4A154B),
      beta: true,
      title: l10n.slackIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.slackConnectionsTab,
      sourcesTabLabel: l10n.slackNotificationsTab,
      commandsTabLabel: l10n.slackCommandsTab,
      connectionsTab: _ConnectionsTab(session: widget.session),
      sourcesTab: _NotificationsTab(session: widget.session),
      commandsTab: SlackIntegrationCommandsTab(session: widget.session),
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
    final conns = widget.session.slackConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.slackNoConnections)
              : ListView.separated(
                  itemCount: conns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = conns[i];
                    return IntegrationEntryRow(
                      icon: Icons.tag_rounded,
                      title: c.label,
                      subtitle: c.webhookUrl,
                      trailing: [
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeSlackConnection(c.id),
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
          label: Text(l10n.slackAddConnection),
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

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _webhookCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWebhookDocs() async {
    final uri = Uri.parse('https://api.slack.com/messaging/webhooks');
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
            title: l10n.slackNewConnectionTitle,
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
                    labelText: l10n.slackConnectionName,
                    hintText: l10n.slackConnectionNameHint,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.slackRequired : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _webhookCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.slackWebhookUrlLabel,
                    suffixIcon: IconButton(
                      tooltip: l10n.slackGetWebhookUrl,
                      icon: const Icon(Icons.open_in_new_rounded),
                      onPressed: _openWebhookDocs,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.slackRequired : null,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.slackAuthHelp,
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
                    : Text(l10n.slackConnectAndSave),
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

    final tempConn = SlackConnection(
      id: const Uuid().v4(),
      label: label,
      webhookUrl: webhookUrl,
    );

    try {
      final client = SlackApiClient(connection: tempConn);
      await client.verifyConnection(testMessage: l10n.integrationWebhookVerifyConnected);

      widget.session.upsertSlackConnection(tempConn);
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
    final conns = session.slackConnections;
    if (conns.isEmpty) {
      return IntegrationEmptyState(text: l10n.slackNoConnections);
    }
    return ListView.separated(
      itemCount: conns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = conns[i];
        return IntegrationEntryRow(
          icon: Icons.tag_rounded,
          title: c.label,
          subtitle: c.webhookUrl,
          subtitleMaxLines: 1,
          extra: IntegrationImportOptionsChips(
            options: [
              IntegrationImportOption(
                label: l10n.slackNotifyOnStatusChange,
                selected: c.notifyOnStatusChange,
                onChanged: (v) => session.upsertSlackConnection(
                  c.copyWith(notifyOnStatusChange: v),
                ),
              ),
              IntegrationImportOption(
                label: l10n.slackNotifyOnNewTask,
                selected: c.notifyOnNewTask,
                onChanged: (v) => session.upsertSlackConnection(
                  c.copyWith(notifyOnNewTask: v),
                ),
              ),
              IntegrationImportOption(
                label: l10n.slackNotifyOnComment,
                selected: c.notifyOnComment,
                onChanged: (v) => session.upsertSlackConnection(
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
