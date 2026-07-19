import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/jira_integration_state.dart';
import '../../services/jira/jira_auth_service.dart';
import '../../services/jira/jira_api_client.dart';
import '../../session/vault_session.dart';

class JiraIntegrationCard extends StatelessWidget {
  const JiraIntegrationCard({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.jiraConnections;
        final sources = session.jiraSources;
        return IntegrationCard(
          logoAsset: 'appLogos/jira.png',
          title: 'Jira',
          subtitle: isEs
              ? 'Conecta Jira Cloud o Server/DC para sincronizar issues con Kanban.'
              : 'Connect Jira Cloud or Server/DC to sync issues with Kanban.',
          configureLabel: l10n.jiraConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => JiraIntegrationConfigDialog(
                      session: session,
                      appSettings: appSettings,
                    ),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: Icons.link_rounded,
              label: isEs
                  ? '${connections.length} conexiones'
                  : '${connections.length} connections',
            ),
            IntegrationStatChip(
              icon: Icons.filter_alt_outlined,
              label: isEs ? '${sources.length} fuentes' : '${sources.length} sources',
            ),
          ],
        );
      },
    );
  }
}

class JiraIntegrationConfigDialog extends StatefulWidget {
  const JiraIntegrationConfigDialog({
    super.key,
    required this.session,
    required this.appSettings,
  });
  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<JiraIntegrationConfigDialog> createState() =>
      _JiraIntegrationConfigDialogState();
}

class _JiraIntegrationConfigDialogState extends State<JiraIntegrationConfigDialog>
    with TickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _auth = JiraAuthService();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _setError(Object e) {
    setState(() => _error = '$e');
  }

  Future<void> _connectCloud() async {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.jiraStartingCloudConnection,
        ),
      ),
    );
    final clientId =
        widget.appSettings.jiraOAuthClientId.trim().isNotEmpty
            ? widget.appSettings.jiraOAuthClientId.trim()
            : JiraAuthService.jiraCloudClientId();
    if (clientId.isEmpty) {
      // Prompt user to set it temporarily.
      final ctrl = TextEditingController();
      final entered = await showDialog<String?>(
        context: context,
        builder: (ctx) => FolioDialog(
          title: Text(
            l10n.jiraSetClientId,
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEs
                      ? 'Necesitas un Client ID de una app OAuth 2.0 (3LO) en Atlassian Developer Console.'
                      : 'You need a Client ID from an OAuth 2.0 (3LO) app in Atlassian Developer Console.',
                ),
                const SizedBox(height: 6),
                Text(
                  isEs
                      ? 'Si estás usando la app oficial de Folio, esto no debería aparecer.'
                      : 'If you are using the official Folio app, you should not see this.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  isEs
                      ? 'Callback URL que debes registrar en Atlassian: http://127.0.0.1:45747/callback'
                      : 'Callback URL to register in Atlassian: http://127.0.0.1:45747/callback',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://developer.atlassian.com/console/myapps/');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    l10n.jiraOpenDeveloperConsole,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'JIRA_OAUTH_CLIENT_ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isEs
                      ? 'Tip: En la app, configura OAuth 2.0 (3LO) y copia el Client ID.'
                      : 'Tip: In the app, configure OAuth 2.0 (3LO) and copy the Client ID.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(l10n.jiraSave),
            ),
          ],
        ),
      );
      ctrl.dispose();
      if (!mounted || entered == null) return;
      await widget.appSettings.setJiraOAuthClientId(entered);
      if (!mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final cancelToken = JiraAuthCancelToken();

    // Modal de progreso: evita que parezca que "no hace nada".
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => FolioDialog(
          title: Text(l10n.jiraConnectingCloud),
          content: Row(
            children: [
              const FolioLoadingIndicator(size: FolioLoadingSize.small),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEs
                      ? 'Se abrirá el navegador para autorizar y luego volveremos a Folio.'
                      : 'A browser window will open for authorization, then we will return to Folio.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelToken.cancel();
                Navigator.of(ctx, rootNavigator: true).pop();
              },
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
    try {
      JiraAuthService.overrideClientId =
          widget.appSettings.jiraOAuthClientId.trim();
      // Usamos un nombre por defecto para evitar un diálogo extra que puede quedar oculto.
      final conn = await _auth
          .connectCloud(label: 'Jira Cloud', cancelToken: cancelToken)
          .timeout(const Duration(minutes: 2));
      if (cancelToken.isCancelled) return;
      widget.session.upsertJiraConnection(conn);
      if (mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop(); // cierra modal progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.jiraConnectionCreated,
            ),
          ),
        );
      }
    } catch (e) {
      if (e is JiraAuthCancelledException) {
        if (mounted) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) nav.pop();
        }
        return;
      }
      _setError(e);
      if (mounted) {
        // Cierra el modal de progreso si está abierto.
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
        final raw = '$e';
        final isMissingSecret = raw.contains('JIRA_OAUTH_CLIENT_SECRET');
        final msg = e is TimeoutException
            ? (isEs
                ? 'Timeout conectando Jira Cloud. Si no se abre el navegador, revisa que Windows permita abrir enlaces externos.'
                : 'Timeout connecting Jira Cloud. If the browser does not open, check Windows allows opening external links.')
            : isMissingSecret
            ? l10n.jiraCloudMissingOAuthSecret
            : (isEs
                ? 'Error conectando Jira Cloud: $e'
                : 'Error connecting Jira Cloud: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IntegrationConfigDialogShell(
      logoAsset: 'appLogos/jira.png',
      title: l10n.jiraIntegrationTitle,
      tabController: _tabs,
      connectionsTabLabel: l10n.jiraConnectionsTab,
      sourcesTabLabel: l10n.jiraSourcesTab,
      errorText: _error,
      connectionsTab: _busy
          ? const FolioLoadingIndicator(centered: true)
          : _ConnectionsTab(
              session: widget.session,
              onConnectCloud: _connectCloud,
            ),
      sourcesTab: _busy
          ? const FolioLoadingIndicator(centered: true)
          : _SourcesTab(session: widget.session),
    );
  }
}

class _ConnectionsTab extends StatefulWidget {
  const _ConnectionsTab({required this.session, required this.onConnectCloud});
  final VaultSession session;
  final VoidCallback onConnectCloud;

  @override
  State<_ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends State<_ConnectionsTab> {
  bool _addingServer = false;

  @override
  Widget build(BuildContext context) {
    if (_addingServer) {
      return _AddServerConnectionForm(
        session: widget.session,
        onCancel: () => setState(() => _addingServer = false),
        onDone: () => setState(() => _addingServer = false),
      );
    }

    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final scheme = Theme.of(context).colorScheme;
    final connections = widget.session.jiraConnections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: widget.onConnectCloud,
              icon: const Icon(Icons.cloud_outlined, size: 18),
              label: Text(isEs ? 'Conectar Cloud' : 'Connect Cloud'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _addingServer = true),
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(isEs ? 'Añadir Server/DC' : 'Add Server/DC'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: connections.isEmpty
              ? IntegrationEmptyState(
                  text: isEs
                      ? 'No hay conexiones configuradas.'
                      : 'No connections configured.',
                )
              : ListView.separated(
                  itemCount: connections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = connections[i];
                    final subtitle = c.deployment == JiraDeployment.cloud
                        ? (c.siteUrl ?? c.cloudId ?? '—')
                        : (c.baseUrl ?? '—');
                    return IntegrationEntryRow(
                      icon: c.deployment == JiraDeployment.cloud
                          ? Icons.cloud_outlined
                          : Icons.dns_outlined,
                      title: c.label,
                      subtitle: subtitle,
                      trailing: [
                        IconButton(
                          tooltip: isEs ? 'Eliminar' : 'Delete',
                          onPressed: () => widget.session.removeJiraConnection(c.id),
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AddServerConnectionForm extends StatefulWidget {
  const _AddServerConnectionForm({
    required this.session,
    required this.onCancel,
    required this.onDone,
  });
  final VaultSession session;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_AddServerConnectionForm> createState() => _AddServerConnectionFormState();
}

class _AddServerConnectionFormState extends State<_AddServerConnectionForm> {
  final _labelCtrl = TextEditingController(text: 'Jira Server');
  final _baseCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _auth = JiraAuthService();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _baseCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.jiraNewServerConnection,
            onBack: _busy ? () {} : widget.onCancel,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: isEs ? 'Nombre' : 'Name',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _baseCtrl,
            decoration: InputDecoration(
              labelText: isEs ? 'Base URL' : 'Base URL',
              hintText: 'https://jira.example.com',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tokenCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isEs ? 'Token / PAT' : 'Token / PAT',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : widget.onCancel,
                child: Text(isEs ? 'Cancelar' : 'Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : Text(isEs ? 'Guardar' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final conn = _auth.connectServer(
        label: _labelCtrl.text,
        baseUrl: _baseCtrl.text,
        pat: _tokenCtrl.text,
      );
      widget.session.upsertJiraConnection(conn);
      widget.onDone();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SourcesTab extends StatefulWidget {
  const _SourcesTab({required this.session});
  final VaultSession session;

  @override
  State<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<_SourcesTab> {
  bool _adding = false;
  JiraSource? _editingMappingsFor;

  String _connLabel(List<JiraConnection> connections, String id) {
    for (final c in connections) {
      if (c.id == id) return c.label;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    if (_adding) {
      return _CreateOrEditSourceForm(
        session: widget.session,
        onCancel: () => setState(() => _adding = false),
        onDone: () => setState(() => _adding = false),
      );
    }
    if (_editingMappingsFor != null) {
      return _EditSourceMappingForm(
        session: widget.session,
        source: _editingMappingsFor!,
        onCancel: () => setState(() => _editingMappingsFor = null),
        onDone: () => setState(() => _editingMappingsFor = null),
      );
    }

    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final scheme = Theme.of(context).colorScheme;
    final sources = widget.session.jiraSources;
    final connections = widget.session.jiraConnections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isEs ? 'Fuentes (para tableros Kanban)' : 'Sources (for Kanban)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: connections.isEmpty ? null : () => setState(() => _adding = true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(isEs ? 'Nueva' : 'New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: sources.isEmpty
              ? IntegrationEmptyState(
                  text: isEs ? 'No hay fuentes.' : 'No sources yet.',
                )
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    final subtitle = switch (s.type) {
                      JiraSourceType.jql => s.jql ?? '—',
                      JiraSourceType.project => 'project=${s.projectKey ?? '—'}',
                      JiraSourceType.board => 'board=${s.boardId ?? '—'}',
                    };
                    return IntegrationEntryRow(
                      icon: Icons.filter_alt_outlined,
                      title: s.name,
                      subtitle: '${_connLabel(connections, s.connectionId)} · ${s.type.name} · $subtitle',
                      subtitleMaxLines: 2,
                      extra: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          IntegrationStatChip(
                            icon: Icons.swap_horiz_rounded,
                            label: '${s.columnMappings.length} mappings',
                          ),
                          IntegrationStatChip(
                            icon: Icons.tune_rounded,
                            label: isEs
                                ? 'Comentarios ${s.importOptions.includeComments ? '✓' : '—'} · Adjuntos ${s.importOptions.includeAttachments ? '✓' : '—'} · Worklog ${s.importOptions.includeWorklog ? '✓' : '—'}'
                                : 'Comments ${s.importOptions.includeComments ? '✓' : '—'} · Attachments ${s.importOptions.includeAttachments ? '✓' : '—'} · Worklog ${s.importOptions.includeWorklog ? '✓' : '—'}',
                          ),
                        ],
                      ),
                      trailing: [
                        IconButton(
                          tooltip: isEs ? 'Editar mapping' : 'Edit mapping',
                          onPressed: () => setState(() => _editingMappingsFor = s),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: isEs ? 'Eliminar' : 'Delete',
                          onPressed: () => widget.session.removeJiraSource(s.id),
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CreateOrEditSourceForm extends StatefulWidget {
  const _CreateOrEditSourceForm({
    required this.session,
    required this.onCancel,
    required this.onDone,
  });

  final VaultSession session;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_CreateOrEditSourceForm> createState() =>
      _CreateOrEditSourceFormState();
}

class _CreateOrEditSourceFormState extends State<_CreateOrEditSourceForm> {
  late JiraConnection _selected = widget.session.jiraConnections.first;

  late JiraSourceType _type = JiraSourceType.project;

  late final TextEditingController _nameCtrl =
      TextEditingController();
  late final TextEditingController _jqlCtrl =
      TextEditingController();
  late final TextEditingController _projectCtrl =
      TextEditingController();
  late final TextEditingController _boardCtrl =
      TextEditingController();

  var _loading = false;
  String? _loadError;
  List<JiraProjectMeta> _projects = const [];
  List<JiraBoardMeta> _boards = const [];

  @override
  void initState() {
    super.initState();
    _reloadLists();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jqlCtrl.dispose();
    _projectCtrl.dispose();
    _boardCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadLists() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = JiraApiClient(connection: _selected);
      final projects = await client.listProjects();
      List<JiraBoardMeta> boards = const [];
      try {
        boards = await client.listBoards();
      } catch (e) {
        // Agile API puede no estar disponible o requerir scopes/permisos adicionales.
        _loadError = '$e';
        boards = const [];
      }
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _boards = boards;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      widget.onCancel();
      return;
    }
    final id = 'jira_source_${const Uuid().v4()}';
    final src = JiraSource(
      id: id,
      connectionId: _selected.id,
      type: _type,
      name: name,
      jql: _jqlCtrl.text.trim().isEmpty ? null : _jqlCtrl.text.trim(),
      projectKey:
          _projectCtrl.text.trim().isEmpty ? null : _projectCtrl.text.trim(),
      boardId: _boardCtrl.text.trim().isEmpty ? null : _boardCtrl.text.trim(),
    );
    widget.session.upsertJiraSource(src);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final connections = widget.session.jiraConnections;

    final projectHint = isEs
        ? 'Escribe para buscar (KEY o nombre)…'
        : 'Type to search (KEY or name)…';
    final boardHint =
        isEs ? 'Escribe para buscar (nombre)…' : 'Type to search (name)…';

    Widget projectPicker() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Autocomplete<JiraProjectMeta>(
            displayStringForOption: (p) => '${p.key} — ${p.name}',
            optionsBuilder: (text) {
              final q = text.text.trim().toLowerCase();
              if (q.isEmpty) return _projects;
              return _projects.where((p) {
                return p.key.toLowerCase().contains(q) ||
                    p.name.toLowerCase().contains(q);
              });
            },
            fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
              // Sync initial text from our controller once.
              if (textCtrl.text.isEmpty && _projectCtrl.text.isNotEmpty) {
                textCtrl.text = _projectCtrl.text;
              }
              return TextField(
                controller: textCtrl,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: isEs ? 'Proyecto' : 'Project',
                  hintText: projectHint,
                  border: const OutlineInputBorder(),
                ),
              );
            },
            onSelected: (p) {
              _projectCtrl.text = p.key;
              if (_nameCtrl.text.trim().isEmpty) {
                _nameCtrl.text = '${p.key} (${p.name})';
              }
              setState(() {});
            },
            optionsViewBuilder: (ctx, onSelected, opts) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280, maxWidth: 560),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: opts.length,
                      itemBuilder: (context, i) {
                        final p = opts.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text(p.key),
                          subtitle: Text(p.name),
                          onTap: () => onSelected(p),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            isEs
                ? 'Se guardará como projectKey="${_projectCtrl.text.trim().isEmpty ? '—' : _projectCtrl.text.trim()}".'
                : 'Will be saved as projectKey="${_projectCtrl.text.trim().isEmpty ? '—' : _projectCtrl.text.trim()}".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    Widget boardPicker() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Autocomplete<JiraBoardMeta>(
            displayStringForOption: (b) => b.name,
            optionsBuilder: (text) {
              final q = text.text.trim().toLowerCase();
              if (q.isEmpty) return _boards;
              return _boards.where((b) {
                return b.name.toLowerCase().contains(q) ||
                    (b.projectKey ?? '').toLowerCase().contains(q) ||
                    (b.projectName ?? '').toLowerCase().contains(q);
              });
            },
            fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
              return TextField(
                controller: textCtrl,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: isEs ? 'Tablero' : 'Board',
                  hintText: boardHint,
                  border: const OutlineInputBorder(),
                ),
              );
            },
            onSelected: (b) {
              _boardCtrl.text = b.id;
              if ((b.projectKey ?? '').trim().isNotEmpty) {
                _projectCtrl.text = b.projectKey!;
              }
              if (_nameCtrl.text.trim().isEmpty) {
                _nameCtrl.text = b.name;
              }
              setState(() {});
            },
            optionsViewBuilder: (ctx, onSelected, opts) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280, maxWidth: 560),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: opts.length,
                      itemBuilder: (context, i) {
                        final b = opts.elementAt(i);
                        final subtitleParts = <String>[
                          if ((b.projectKey ?? '').trim().isNotEmpty) b.projectKey!,
                          if ((b.projectName ?? '').trim().isNotEmpty) b.projectName!,
                          if ((b.type ?? '').trim().isNotEmpty) b.type!,
                          'id=${b.id}',
                        ];
                        return ListTile(
                          dense: true,
                          title: Text(b.name),
                          subtitle: Text(subtitleParts.join(' • ')),
                          onTap: () => onSelected(b),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            isEs
                ? 'Se guardará como boardId="${_boardCtrl.text.trim().isEmpty ? '—' : _boardCtrl.text.trim()}".'
                : 'Will be saved as boardId="${_boardCtrl.text.trim().isEmpty ? '—' : _boardCtrl.text.trim()}".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.jiraNewSource,
            onBack: widget.onCancel,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<JiraConnection>(
                  initialValue: _selected,
                  decoration: InputDecoration(
                    labelText: isEs ? 'Conexión' : 'Connection',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in connections)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) async {
                    final next = v ?? _selected;
                    if (next.id == _selected.id) return;
                    setState(() => _selected = next);
                    await _reloadLists();
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: l10n.jiraReload,
                onPressed: _loading ? null : _reloadLists,
                icon: _loading
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 8),
            Text(
              isEs
                  ? 'No se pudieron cargar proyectos/tableros. Puedes escribir los IDs manualmente.\n$_loadError'
                  : 'Could not load projects/boards. You can type IDs manually.\n$_loadError',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<JiraSourceType>(
            initialValue: _type,
            decoration: InputDecoration(
              labelText: isEs ? 'Tipo' : 'Type',
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: JiraSourceType.project, child: Text('Project')),
              DropdownMenuItem(value: JiraSourceType.board, child: Text('Board')),
              DropdownMenuItem(value: JiraSourceType.jql, child: Text('JQL')),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: isEs ? 'Nombre' : 'Name',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (_type == JiraSourceType.jql)
            TextField(
              controller: _jqlCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'JQL',
                hintText: 'project=ABC ORDER BY updated DESC',
                border: const OutlineInputBorder(),
              ),
            ),
          if (_type == JiraSourceType.project) projectPicker(),
          if (_type == JiraSourceType.board) ...[
            boardPicker(),
            const SizedBox(height: 10),
            projectPicker(),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(isEs ? 'Cancelar' : 'Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                child: Text(isEs ? 'Crear' : 'Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditSourceMappingForm extends StatefulWidget {
  const _EditSourceMappingForm({
    required this.session,
    required this.source,
    required this.onCancel,
    required this.onDone,
  });
  final VaultSession session;
  final JiraSource source;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_EditSourceMappingForm> createState() => _EditSourceMappingFormState();
}

class _EditSourceMappingFormState extends State<_EditSourceMappingForm> {
  late final List<JiraColumnMapping> _mappings = widget.source.columnMappings.toList();
  late JiraImportOptions _options = widget.source.importOptions;
  final _customFieldsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customFieldsCtrl.text = widget.source.customFieldIds.join(', ');
  }

  @override
  void dispose() {
    _customFieldsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: isEs ? 'Configurar fuente' : 'Configure source',
            onBack: widget.onCancel,
          ),
          const SizedBox(height: 10),
          Text(
            isEs ? 'Opciones de importación/push' : 'Import/push options',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          IntegrationImportOptionsChips(
            options: [
              IntegrationImportOption(
                label: isEs ? 'Comentarios' : 'Comments',
                selected: _options.includeComments,
                onChanged: (v) => setState(() => _options = JiraImportOptions(
                      includeComments: v,
                      includeAttachments: _options.includeAttachments,
                      includeSubtasks: _options.includeSubtasks,
                      includeLinks: _options.includeLinks,
                      includeWorklog: _options.includeWorklog,
                    )),
              ),
              IntegrationImportOption(
                label: isEs ? 'Adjuntos' : 'Attachments',
                selected: _options.includeAttachments,
                onChanged: (v) => setState(() => _options = JiraImportOptions(
                      includeComments: _options.includeComments,
                      includeAttachments: v,
                      includeSubtasks: _options.includeSubtasks,
                      includeLinks: _options.includeLinks,
                      includeWorklog: _options.includeWorklog,
                    )),
              ),
              IntegrationImportOption(
                label: isEs ? 'Subtareas' : 'Subtasks',
                selected: _options.includeSubtasks,
                onChanged: (v) => setState(() => _options = JiraImportOptions(
                      includeComments: _options.includeComments,
                      includeAttachments: _options.includeAttachments,
                      includeSubtasks: v,
                      includeLinks: _options.includeLinks,
                      includeWorklog: _options.includeWorklog,
                    )),
              ),
              IntegrationImportOption(
                label: 'Links',
                selected: _options.includeLinks,
                onChanged: (v) => setState(() => _options = JiraImportOptions(
                      includeComments: _options.includeComments,
                      includeAttachments: _options.includeAttachments,
                      includeSubtasks: _options.includeSubtasks,
                      includeLinks: v,
                      includeWorklog: _options.includeWorklog,
                    )),
              ),
              IntegrationImportOption(
                label: 'Worklog',
                selected: _options.includeWorklog,
                onChanged: (v) => setState(() => _options = JiraImportOptions(
                      includeComments: _options.includeComments,
                      includeAttachments: _options.includeAttachments,
                      includeSubtasks: _options.includeSubtasks,
                      includeLinks: _options.includeLinks,
                      includeWorklog: v,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _customFieldsCtrl,
            decoration: InputDecoration(
              labelText: isEs ? 'Custom fields (IDs, coma)' : 'Custom fields (IDs, comma)',
              hintText: 'customfield_10016, customfield_10020',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isEs ? 'Mapping Kanban → Jira (por columna)' : 'Kanban → Jira mapping (per column)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_mappings.isEmpty)
            Text(isEs ? 'No hay mappings.' : 'No mappings yet.'),
          for (int i = 0; i < _mappings.length; i++)
            _MappingRow(
              key: ValueKey('map_$i'),
              mapping: _mappings[i],
              onChanged: (m) => setState(() => _mappings[i] = m),
              onRemove: () => setState(() => _mappings.removeAt(i)),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _mappings.add(const JiraColumnMapping(columnId: 'todo'));
              }),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(isEs ? 'Añadir mapping' : 'Add mapping'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(isEs ? 'Cancelar' : 'Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final cf = _customFieldsCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(growable: false);
                  final nextSource = JiraSource(
                    id: widget.source.id,
                    connectionId: widget.source.connectionId,
                    type: widget.source.type,
                    name: widget.source.name,
                    jql: widget.source.jql,
                    boardId: widget.source.boardId,
                    projectKey: widget.source.projectKey,
                    importOptions: _options,
                    customFieldIds: cf,
                    columnMappings: _mappings,
                  );
                  widget.session.upsertJiraSource(nextSource);
                  widget.onDone();
                },
                child: Text(isEs ? 'Guardar' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MappingRow extends StatefulWidget {
  const _MappingRow({
    super.key,
    required this.mapping,
    required this.onChanged,
    required this.onRemove,
  });
  final JiraColumnMapping mapping;
  final ValueChanged<JiraColumnMapping> onChanged;
  final VoidCallback onRemove;

  @override
  State<_MappingRow> createState() => _MappingRowState();
}

class _MappingRowState extends State<_MappingRow> {
  late final _colCtrl = TextEditingController(text: widget.mapping.columnId);
  late final _transitionCtrl =
      TextEditingController(text: widget.mapping.transitionId ?? '');
  late final _statusCtrl = TextEditingController(text: widget.mapping.statusName ?? '');

  @override
  void dispose() {
    _colCtrl.dispose();
    _transitionCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      JiraColumnMapping(
        columnId: _colCtrl.text.trim(),
        transitionId: _transitionCtrl.text.trim().isEmpty ? null : _transitionCtrl.text.trim(),
        statusName: _statusCtrl.text.trim().isEmpty ? null : _statusCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _colCtrl,
              onChanged: (_) => _emit(),
              decoration: InputDecoration(
                labelText: isEs ? 'columnId' : 'columnId',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _transitionCtrl,
              onChanged: (_) => _emit(),
              decoration: InputDecoration(
                labelText: isEs ? 'transitionId (opcional)' : 'transitionId (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _statusCtrl,
              onChanged: (_) => _emit(),
              decoration: InputDecoration(
                labelText: isEs ? 'statusName (fallback)' : 'statusName (fallback)',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: isEs ? 'Quitar' : 'Remove',
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
