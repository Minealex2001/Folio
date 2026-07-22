import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/discord_integration_state.dart';
import '../../services/discord/discord_api_client.dart';
import '../../session/vault_session.dart';

class DiscordIntegrationCard extends StatelessWidget {
  const DiscordIntegrationCard({super.key, required this.session});

  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.discordConnections;
        return IntegrationCard(
          brandIcon: Icons.forum_rounded,
          brandColor: const Color(0xFF5865F2),
          beta: true,
          title: 'Discord',
          subtitle: l10n.discordCardSubtitle,
          configureLabel: l10n.discordConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) =>
                        DiscordIntegrationConfigDialog(session: session),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: Icons.link_rounded,
              label: l10n.discordConnectionCount(connections.length),
            ),
          ],
        );
      },
    );
  }
}

class DiscordIntegrationConfigDialog extends StatefulWidget {
  const DiscordIntegrationConfigDialog({super.key, required this.session});

  final VaultSession session;

  @override
  State<DiscordIntegrationConfigDialog> createState() =>
      _DiscordIntegrationConfigDialogState();
}

class _DiscordIntegrationConfigDialogState
    extends State<DiscordIntegrationConfigDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      brandIcon: Icons.forum_rounded,
      brandColor: const Color(0xFF5865F2),
      beta: true,
      title: l10n.discordIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.discordConnectionsTab,
      sourcesTabLabel: l10n.discordNotificationsTab,
      connectionsTab: _ConnectionsTab(session: widget.session),
      sourcesTab: _NotificationsTab(session: widget.session),
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
    final conns = widget.session.discordConnections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.discordNoConnections)
              : ListView.separated(
                  itemCount: conns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = conns[i];
                    return IntegrationEntryRow(
                      icon: Icons.tag_rounded,
                      title: c.label,
                      subtitle: maskIntegrationSecret(c.webhookUrl),
                      trailing: [
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: scheme.error,
                          ),
                          onPressed: () =>
                              widget.session.removeDiscordConnection(c.id),
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
          label: Text(l10n.discordAddConnection),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final l10n = AppLocalizations.of(context);
      final conn = DiscordConnection(
        id: const Uuid().v4(),
        label: _labelCtrl.text.trim(),
        webhookUrl: _webhookCtrl.text.trim(),
      );
      await DiscordApiClient(connection: conn).verifyConnection(
        testMessage: l10n.discordTestMessage,
      );
      widget.session.upsertDiscordConnection(conn);
      widget.onDone();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _labelCtrl,
            decoration: InputDecoration(labelText: l10n.discordConnectionLabel),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.discordRequired : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _webhookCtrl,
            decoration: InputDecoration(labelText: l10n.discordWebhookUrl),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return l10n.discordRequired;
              if (!t.startsWith('https://')) return l10n.discordInvalidWebhook;
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(onPressed: widget.onCancel, child: Text(l10n.cancel)),
              const Spacer(),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({required this.session});
  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conns = session.discordConnections;
    if (conns.isEmpty) {
      return IntegrationEmptyState(text: l10n.discordNoConnections);
    }
    return ListView.separated(
      itemCount: conns.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = conns[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(c.label),
              subtitle: Text(l10n.discordNotificationsForChannel),
            ),
            SwitchListTile(
              title: Text(l10n.discordNotifyStatus),
              value: c.notifyOnStatusChange,
              onChanged: (v) => session.upsertDiscordConnection(
                c.copyWith(notifyOnStatusChange: v),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.discordNotifyNewTask),
              value: c.notifyOnNewTask,
              onChanged: (v) => session.upsertDiscordConnection(
                c.copyWith(notifyOnNewTask: v),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.discordNotifyComment),
              value: c.notifyOnComment,
              onChanged: (v) => session.upsertDiscordConnection(
                c.copyWith(notifyOnComment: v),
              ),
            ),
          ],
        );
      },
    );
  }
}
