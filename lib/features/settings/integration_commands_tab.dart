import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../firebase_options.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/slack_integration_state.dart';
import '../../models/teams_integration_state.dart';
import '../../services/folio_cloud/folio_cloud_callable.dart';
import '../../services/integrations/integration_link_service.dart';
import '../../session/vault_session.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';

/// URL pública del endpoint de comandos Teams (Outgoing Webhook).
String buildTeamsCommandEndpointUrl() {
  const region = kFolioCloudFunctionsRegion;
  final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
  return 'https://$region-$projectId.cloudfunctions.net/folioTeamsCommand';
}

class SlackIntegrationCommandsTab extends StatelessWidget {
  const SlackIntegrationCommandsTab({super.key, required this.session});

  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    return IntegrationCommandsTab(
      provider: 'slack',
      vaultId: session.activeVaultId,
      connections: session.slackConnections,
    );
  }
}

class TeamsIntegrationCommandsTab extends StatelessWidget {
  const TeamsIntegrationCommandsTab({super.key, required this.session});

  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    return IntegrationCommandsTab(
      provider: 'teams',
      vaultId: session.activeVaultId,
      connections: session.teamsConnections,
      teamsCommandBaseUrl: buildTeamsCommandEndpointUrl(),
      onTeamsTokenChanged: (connectionId, token) {
        TeamsConnection? match;
        for (final c in session.teamsConnections) {
          if (c.id == connectionId) {
            match = c;
            break;
          }
        }
        if (match == null) return;
        session.upsertTeamsConnection(match.copyWith(outgoingWebhookToken: token));
      },
    );
  }
}

class IntegrationCommandsTab extends StatefulWidget {
  const IntegrationCommandsTab({
    super.key,
    required this.provider,
    required this.vaultId,
    required this.connections,
    this.teamsCommandBaseUrl,
    this.onTeamsTokenChanged,
  });

  final String provider;
  final String? vaultId;
  final List<dynamic> connections;
  final String? teamsCommandBaseUrl;
  final void Function(String connectionId, String token)? onTeamsTokenChanged;

  @override
  State<IntegrationCommandsTab> createState() => _IntegrationCommandsTabState();
}

class _IntegrationCommandsTabState extends State<IntegrationCommandsTab> {
  final _linkService = const IntegrationLinkService();
  String? _selectedConnectionId;
  String? _generatedCode;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.connections.isNotEmpty) {
      _selectedConnectionId = _connectionId(widget.connections.first);
    }
  }

  @override
  void didUpdateWidget(covariant IntegrationCommandsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connections.isEmpty) {
      _selectedConnectionId = null;
    } else if (_selectedConnectionId == null ||
        !widget.connections.any((c) => _connectionId(c) == _selectedConnectionId)) {
      _selectedConnectionId = _connectionId(widget.connections.first);
    }
  }

  String _connectionId(dynamic c) {
    if (c is SlackConnection) return c.id;
    if (c is TeamsConnection) return c.id;
    return '';
  }

  String _connectionLabel(dynamic c) {
    if (c is SlackConnection) return c.label;
    if (c is TeamsConnection) return c.label;
    return '';
  }

  String _webhookUrl(dynamic c) {
    if (c is SlackConnection) return c.webhookUrl;
    if (c is TeamsConnection) return c.webhookUrl;
    return '';
  }

  String? _teamsToken(dynamic c) {
    if (c is TeamsConnection) return c.outgoingWebhookToken;
    return null;
  }

  dynamic _selectedConnection() {
    final id = _selectedConnectionId;
    if (id == null) return null;
    for (final c in widget.connections) {
      if (_connectionId(c) == id) return c;
    }
    return null;
  }

  String _teamsEndpointFor(dynamic c) {
    final base = widget.teamsCommandBaseUrl ?? '';
    final id = _connectionId(c);
    if (base.isEmpty || id.isEmpty) return '';
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}connectionId=$id';
  }

  Future<void> _generateCode() async {
    final l10n = AppLocalizations.of(context);
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() => _error = l10n.integrationCommandNeedsSignIn);
      return;
    }
    final vaultId = widget.vaultId?.trim() ?? '';
    if (vaultId.isEmpty) {
      setState(() => _error = l10n.integrationCommandNeedsVault);
      return;
    }
    final conn = _selectedConnection();
    if (conn == null) {
      setState(() => _error = l10n.integrationSelectConnection);
      return;
    }
    if (widget.provider == 'teams' && (_teamsToken(conn) ?? '').trim().isEmpty) {
      setState(() => _error = l10n.integrationTeamsOutgoingTokenRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final code = _linkService.generateCode();
      await _linkService.registerLinkCode(
        code: code,
        vaultId: vaultId,
        connectionId: _connectionId(conn),
        provider: widget.provider,
        webhookUrl: _webhookUrl(conn),
        teamsSecurityToken: _teamsToken(conn),
      );
      if (mounted) setState(() => _generatedCode = code);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conn = _selectedConnection();

    if (widget.connections.isEmpty) {
      return IntegrationEmptyState(text: l10n.integrationCommandsNeedConnection);
    }

    return ListView(
      children: [
        Text(
          l10n.integrationCommandsHelp,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedConnectionId,
          decoration: InputDecoration(labelText: l10n.integrationSelectConnection),
          items: [
            for (final c in widget.connections)
              DropdownMenuItem(
                value: _connectionId(c),
                child: Text(_connectionLabel(c)),
              ),
          ],
          onChanged: (v) => setState(() {
            _selectedConnectionId = v;
            _generatedCode = null;
          }),
        ),
        if (widget.provider == 'teams' && conn is TeamsConnection) ...[
          const SizedBox(height: 12),
          Text(
            l10n.integrationTeamsOutgoingTokenHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey(conn.id),
            initialValue: conn.outgoingWebhookToken,
            decoration: InputDecoration(
              labelText: l10n.integrationTeamsOutgoingTokenLabel,
            ),
            onChanged: (v) => widget.onTeamsTokenChanged?.call(conn.id, v),
          ),
          if (_teamsEndpointFor(conn).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.integrationTeamsCommandEndpoint,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SelectableText(
              _teamsEndpointFor(conn),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _generateCode,
          icon: _busy
              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
              : const Icon(Icons.link_rounded),
          label: Text(l10n.integrationGenerateLinkCode),
        ),
        if (_generatedCode != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.integrationLinkCodeReady,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _generatedCode!,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.aiCopyMessage,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _generatedCode!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.integrationLinkCodeCopied)),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.provider == 'slack'
                      ? l10n.integrationLinkCodeInstructionSlack(_generatedCode!)
                      : l10n.integrationLinkCodeInstructionTeams(_generatedCode!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
        ],
      ],
    );
  }
}
