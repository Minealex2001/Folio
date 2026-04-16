import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.jiraConnections;
        final sources = session.jiraSources;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('appLogos/jira.png'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jira',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEs
                          ? 'Conecta Jira Cloud o Server/DC para sincronizar issues con Kanban.'
                          : 'Connect Jira Cloud or Server/DC to sync issues with Kanban.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          icon: Icons.link_rounded,
                          label: isEs
                              ? '${connections.length} conexiones'
                              : '${connections.length} connections',
                        ),
                        _Pill(
                          icon: Icons.filter_alt_outlined,
                          label: isEs
                              ? '${sources.length} fuentes'
                              : '${sources.length} sources',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  FilledButton.icon(
                    onPressed: session.state == VaultFlowState.unlocked
                        ? () => showDialog<void>(
                              context: context,
                              builder: (ctx) =>
                                  JiraIntegrationConfigDialog(
                                    session: session,
                                    appSettings: appSettings,
                                  ),
                            )
                        : null,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(isEs ? 'Configurar' : l10n.settings),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEs ? 'Iniciando conexión con Jira Cloud…' : 'Starting Jira Cloud connection…',
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
        builder: (ctx) => AlertDialog(
          title: Text(
            isEs ? 'Configurar Client ID' : 'Set Client ID',
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
                    isEs ? 'Abrir Atlassian Developer Console' : 'Open Atlassian Developer Console',
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
              child: Text(isEs ? 'Cancelar' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(isEs ? 'Guardar' : 'Save'),
            ),
          ],
        ),
      );
      ctrl.dispose();
      if (!mounted || entered == null) return;
      await widget.appSettings.setJiraOAuthClientId(entered);
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
        builder: (ctx) => AlertDialog(
          title: Text(isEs ? 'Conectando Jira Cloud…' : 'Connecting Jira Cloud…'),
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
              child: Text(isEs ? 'Cancelar' : 'Cancel'),
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
              isEs ? 'Conexión Jira Cloud creada.' : 'Jira Cloud connection created.',
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
            ? (isEs
                ? 'Falta JIRA_OAUTH_CLIENT_SECRET. Folio carga `.env` al arrancar: reinicia la app y verifica el log `folio.env` ("dotenv loaded").'
                : 'Missing JIRA_OAUTH_CLIENT_SECRET. Folio loads `.env` on startup: restart the app and check the `folio.env` log ("dotenv loaded").')
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

  Future<void> _connectServer() async {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final labelCtrl = TextEditingController(text: 'Jira Server');
    final baseCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
    final result = await showDialog<({String label, String baseUrl, String pat})?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEs ? 'Nueva conexión Server/DC' : 'New Server/DC connection'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                  labelText: isEs ? 'Nombre' : 'Name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: baseCtrl,
                decoration: InputDecoration(
                  labelText: isEs ? 'Base URL' : 'Base URL',
                  hintText: 'https://jira.example.com',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isEs ? 'Token / PAT' : 'Token / PAT',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(isEs ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              (label: labelCtrl.text, baseUrl: baseCtrl.text, pat: tokenCtrl.text),
            ),
            child: Text(isEs ? 'Guardar' : 'Save'),
          ),
        ],
      ),
    );
    labelCtrl.dispose();
    baseCtrl.dispose();
    tokenCtrl.dispose();
    if (!mounted || result == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final conn = _auth.connectServer(
        label: result.label,
        baseUrl: result.baseUrl,
        pat: result.pat,
      );
      widget.session.upsertJiraConnection(conn);
    } catch (e) {
      _setError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createSource() async {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final connections = widget.session.jiraConnections;
    if (connections.isEmpty) {
      _setError(isEs ? 'Crea una conexión primero.' : 'Create a connection first.');
      return;
    }
    final created = await showDialog<JiraSource?>(
      context: context,
      builder: (ctx) => _CreateOrEditSourceDialog(
        isEs: isEs,
        connections: connections,
      ),
    );
    if (!mounted || created == null) return;
    widget.session.upsertJiraSource(created);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final connections = widget.session.jiraConnections;
    final sources = widget.session.jiraSources;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Image.asset('appLogos/jira.png'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEs ? 'Integración Jira' : 'Jira integration',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: isEs ? 'Cerrar' : 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: isEs ? 'Conexiones' : 'Connections'),
                Tab(text: isEs ? 'Fuentes' : 'Sources'),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ),
            if (_error != null) const SizedBox(height: 10),
            SizedBox(
              height: 420,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _busy
                      ? const Center(child: CircularProgressIndicator())
                      : _ConnectionsTab(
                          connections: connections,
                          onConnectCloud: _connectCloud,
                          onConnectServer: _connectServer,
                          onDelete: widget.session.removeJiraConnection,
                        ),
                  _busy
                      ? const Center(child: CircularProgressIndicator())
                      : _SourcesTab(
                          sources: sources,
                          connections: connections,
                          onCreate: _createSource,
                          onUpsert: widget.session.upsertJiraSource,
                          onDelete: widget.session.removeJiraSource,
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

class _CreateOrEditSourceDialog extends StatefulWidget {
  const _CreateOrEditSourceDialog({
    required this.isEs,
    required this.connections,
  });

  final bool isEs;
  final List<JiraConnection> connections;

  @override
  State<_CreateOrEditSourceDialog> createState() =>
      _CreateOrEditSourceDialogState();
}

class _CreateOrEditSourceDialogState extends State<_CreateOrEditSourceDialog> {
  late JiraConnection _selected = widget.connections.first;

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
      Navigator.pop(context, null);
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
    Navigator.pop(context, src);
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final scheme = Theme.of(context).colorScheme;

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
                _nameCtrl.text = '${b.name}';
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

    return AlertDialog(
      title: Text(isEs ? 'Nueva fuente' : 'New source'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<JiraConnection>(
                    value: _selected,
                    decoration: InputDecoration(
                      labelText: isEs ? 'Conexión' : 'Connection',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in widget.connections)
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
                  tooltip: isEs ? 'Recargar' : 'Reload',
                  onPressed: _loading ? null : _reloadLists,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
              value: _type,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(isEs ? 'Cancelar' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEs ? 'Crear' : 'Create'),
        ),
      ],
    );
  }
}

class _ConnectionsTab extends StatelessWidget {
  const _ConnectionsTab({
    required this.connections,
    required this.onConnectCloud,
    required this.onConnectServer,
    required this.onDelete,
  });
  final List<JiraConnection> connections;
  final VoidCallback onConnectCloud;
  final VoidCallback onConnectServer;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onConnectCloud,
              icon: const Icon(Icons.cloud_outlined, size: 18),
              label: Text(isEs ? 'Conectar Cloud' : 'Connect Cloud'),
            ),
            OutlinedButton.icon(
              onPressed: onConnectServer,
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(isEs ? 'Añadir Server/DC' : 'Add Server/DC'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: connections.isEmpty
              ? Center(
                  child: Text(
                    isEs
                        ? 'No hay conexiones configuradas.'
                        : 'No connections configured.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.separated(
                  itemCount: connections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = connections[i];
                    final subtitle = c.deployment == JiraDeployment.cloud
                        ? (c.siteUrl ?? c.cloudId ?? '—')
                        : (c.baseUrl ?? '—');
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            c.deployment == JiraDeployment.cloud
                                ? Icons.cloud_outlined
                                : Icons.dns_outlined,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: isEs ? 'Eliminar' : 'Delete',
                            onPressed: () => onDelete(c.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SourcesTab extends StatelessWidget {
  const _SourcesTab({
    required this.sources,
    required this.connections,
    required this.onCreate,
    required this.onUpsert,
    required this.onDelete,
  });
  final List<JiraSource> sources;
  final List<JiraConnection> connections;
  final VoidCallback onCreate;
  final void Function(JiraSource source) onUpsert;
  final void Function(String id) onDelete;

  String _connLabel(String id) {
    for (final c in connections) {
      if (c.id == id) return c.label;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final scheme = Theme.of(context).colorScheme;
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
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(isEs ? 'Nueva' : 'New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: sources.isEmpty
              ? Center(
                  child: Text(
                    isEs ? 'No hay fuentes.' : 'No sources yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    final subtitle = switch (s.type) {
                      JiraSourceType.jql => s.jql ?? '—',
                      JiraSourceType.project => 'project=${s.projectKey ?? '—'}',
                      JiraSourceType.board => 'board=${s.boardId ?? '—'}',
                    };
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_outlined, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_connLabel(s.connectionId)} · ${s.type.name} · $subtitle',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ChipInfo(
                                      icon: Icons.swap_horiz_rounded,
                                      label: isEs
                                          ? '${s.columnMappings.length} mappings'
                                          : '${s.columnMappings.length} mappings',
                                    ),
                                    _ChipInfo(
                                      icon: Icons.tune_rounded,
                                      label: isEs
                                          ? 'Comentarios ${s.importOptions.includeComments ? '✓' : '—'} · Adjuntos ${s.importOptions.includeAttachments ? '✓' : '—'} · Worklog ${s.importOptions.includeWorklog ? '✓' : '—'}'
                                          : 'Comments ${s.importOptions.includeComments ? '✓' : '—'} · Attachments ${s.importOptions.includeAttachments ? '✓' : '—'} · Worklog ${s.importOptions.includeWorklog ? '✓' : '—'}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: isEs ? 'Editar mapping' : 'Edit mapping',
                            onPressed: () async {
                              final updated = await showDialog<JiraSource?>(
                                context: context,
                                builder: (ctx) => _EditSourceMappingDialog(source: s),
                              );
                              if (updated != null) onUpsert(updated);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: isEs ? 'Eliminar' : 'Delete',
                            onPressed: () => onDelete(s.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChipInfo extends StatelessWidget {
  const _ChipInfo({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _EditSourceMappingDialog extends StatefulWidget {
  const _EditSourceMappingDialog({required this.source});
  final JiraSource source;

  @override
  State<_EditSourceMappingDialog> createState() => _EditSourceMappingDialogState();
}

class _EditSourceMappingDialogState extends State<_EditSourceMappingDialog> {
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
    return AlertDialog(
      title: Text(isEs ? 'Configurar fuente' : 'Configure source'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs ? 'Opciones de importación/push' : 'Import/push options',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilterChip(
                    selected: _options.includeComments,
                    onSelected: (v) => setState(() => _options = JiraImportOptions(
                          includeComments: v,
                          includeAttachments: _options.includeAttachments,
                          includeSubtasks: _options.includeSubtasks,
                          includeLinks: _options.includeLinks,
                          includeWorklog: _options.includeWorklog,
                        )),
                    label: Text(isEs ? 'Comentarios' : 'Comments'),
                  ),
                  FilterChip(
                    selected: _options.includeAttachments,
                    onSelected: (v) => setState(() => _options = JiraImportOptions(
                          includeComments: _options.includeComments,
                          includeAttachments: v,
                          includeSubtasks: _options.includeSubtasks,
                          includeLinks: _options.includeLinks,
                          includeWorklog: _options.includeWorklog,
                        )),
                    label: Text(isEs ? 'Adjuntos' : 'Attachments'),
                  ),
                  FilterChip(
                    selected: _options.includeSubtasks,
                    onSelected: (v) => setState(() => _options = JiraImportOptions(
                          includeComments: _options.includeComments,
                          includeAttachments: _options.includeAttachments,
                          includeSubtasks: v,
                          includeLinks: _options.includeLinks,
                          includeWorklog: _options.includeWorklog,
                        )),
                    label: Text(isEs ? 'Subtareas' : 'Subtasks'),
                  ),
                  FilterChip(
                    selected: _options.includeLinks,
                    onSelected: (v) => setState(() => _options = JiraImportOptions(
                          includeComments: _options.includeComments,
                          includeAttachments: _options.includeAttachments,
                          includeSubtasks: _options.includeSubtasks,
                          includeLinks: v,
                          includeWorklog: _options.includeWorklog,
                        )),
                    label: Text(isEs ? 'Links' : 'Links'),
                  ),
                  FilterChip(
                    selected: _options.includeWorklog,
                    onSelected: (v) => setState(() => _options = JiraImportOptions(
                          includeComments: _options.includeComments,
                          includeAttachments: _options.includeAttachments,
                          includeSubtasks: _options.includeSubtasks,
                          includeLinks: _options.includeLinks,
                          includeWorklog: v,
                        )),
                    label: Text(isEs ? 'Worklog' : 'Worklog'),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(isEs ? 'Cancelar' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final cf = _customFieldsCtrl.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false);
            Navigator.pop(
              context,
              JiraSource(
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
              ),
            );
          },
          child: Text(isEs ? 'Guardar' : 'Save'),
        ),
      ],
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

