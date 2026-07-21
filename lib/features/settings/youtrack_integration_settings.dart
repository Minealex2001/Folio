import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/youtrack_integration_state.dart';
import '../../services/youtrack/youtrack_api_client.dart';
import '../../session/vault_session.dart';
import '../../utils/private_host.dart';

class YouTrackIntegrationCard extends StatelessWidget {
  const YouTrackIntegrationCard({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.youtrackConnections;
        final sources = session.youtrackSources;
        return IntegrationCard(
          logoAsset: 'appLogos/youtrack.png',
          title: 'YouTrack',
          subtitle: isEs
              ? 'Conecta JetBrains YouTrack para sincronizar tareas con Kanban.'
              : 'Connect JetBrains YouTrack to sync tasks with Kanban.',
          configureLabel: l10n.youtrackConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => YouTrackIntegrationConfigDialog(
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

class YouTrackIntegrationConfigDialog extends StatefulWidget {
  const YouTrackIntegrationConfigDialog({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<YouTrackIntegrationConfigDialog> createState() =>
      _YouTrackIntegrationConfigDialogState();
}

class _YouTrackIntegrationConfigDialogState
    extends State<YouTrackIntegrationConfigDialog>
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
      logoAsset: 'appLogos/youtrack.png',
      title: l10n.youtrackIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.youtrackConnectionsTab,
      sourcesTabLabel: l10n.youtrackSourcesTab,
      connectionsTab: _ConnectionsTab(session: widget.session),
      sourcesTab: _SourcesTab(session: widget.session),
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
    final conns = widget.session.youtrackConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.youtrackNoConnections)
              : ListView.separated(
                  itemCount: conns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = conns[i];
                    return IntegrationEntryRow(
                      icon: Icons.link_rounded,
                      title: c.label,
                      subtitle: c.baseUrl,
                      trailing: [
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeYouTrackConnection(c.id),
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
          label: Text(l10n.youtrackAddConnection),
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
  final _urlCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
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
            title: l10n.youtrackNewConnectionTitle,
            onBack: _busy ? () {} : widget.onCancel,
          ),
          const SizedBox(height: 10),
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _labelCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.youtrackConnectionName,
                    hintText: 'e.g. My YouTrack Standalone',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.youtrackRequired : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.youtrackBaseUrlLabel,
                    hintText: 'e.g. https://youtrack.example.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.youtrackRequired;
                    final value = v.trim();
                    final uri = Uri.tryParse(value);
                    if (uri == null ||
                        !uri.hasScheme ||
                        (uri.scheme != 'http' && uri.scheme != 'https')) {
                      return l10n.youtrackUrlMustStartWithHttp;
                    }
                    if (uri.scheme == 'http' && !isPrivateOrLocalHost(uri.host)) {
                      return l10n.youtrackUrlMustStartWithHttp;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.youtrackPermanentToken,
                    hintText: 'perm:your-youtrack-personal-access-token',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.youtrackRequired : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: scheme.error, fontSize: 13),
                  ),
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
                    : Text(l10n.youtrackConnectAndSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final label = _labelCtrl.text.trim();
    final baseUrl = _urlCtrl.text.trim();
    final token = _tokenCtrl.text.trim();

    final tempConn = YouTrackConnection(
      id: const Uuid().v4(),
      label: label,
      baseUrl: baseUrl,
      token: token,
    );

    try {
      final client = YouTrackApiClient(connection: tempConn);
      await client.verifyConnection();

      widget.session.upsertYouTrackConnection(tempConn);
      if (mounted) {
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
  YouTrackSource? _editingMappingsFor;

  @override
  Widget build(BuildContext context) {
    if (_adding) {
      return _AddSourceForm(
        session: widget.session,
        onCancel: () => setState(() => _adding = false),
        onDone: () => setState(() => _adding = false),
      );
    }
    if (_editingMappingsFor != null) {
      return _EditMappingsForm(
        session: widget.session,
        source: _editingMappingsFor!,
        onCancel: () => setState(() => _editingMappingsFor = null),
        onDone: () => setState(() => _editingMappingsFor = null),
      );
    }

    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final scheme = Theme.of(context).colorScheme;
    final sources = widget.session.youtrackSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: sources.isEmpty
              ? IntegrationEmptyState(text: l10n.youtrackNoSources)
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    return IntegrationEntryRow(
                      icon: Icons.filter_alt_rounded,
                      title: s.name,
                      subtitle: s.type == YouTrackSourceType.project
                          ? '${isEs ? "Proyecto" : "Project"}: ${s.projectShortName ?? s.projectId}'
                          : 'Query: ${s.query}',
                      trailing: [
                        IconButton(
                          tooltip: l10n.youtrackMapColumns,
                          icon: const Icon(Icons.map_rounded),
                          onPressed: () => setState(() => _editingMappingsFor = s),
                        ),
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeYouTrackSource(s.id),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: widget.session.youtrackConnections.isEmpty
              ? null
              : () => setState(() => _adding = true),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.youtrackAddSource),
        ),
      ],
    );
  }
}

class _AddSourceForm extends StatefulWidget {
  const _AddSourceForm({
    required this.session,
    required this.onCancel,
    required this.onDone,
  });
  final VaultSession session;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_AddSourceForm> createState() => _AddSourceFormState();
}

class _AddSourceFormState extends State<_AddSourceForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _queryCtrl = TextEditingController();

  late String _connectionId;
  YouTrackSourceType _type = YouTrackSourceType.project;
  List<YouTrackProject> _projects = [];
  String? _selectedProjectId;
  String? _selectedProjectShortName;
  bool _loadingProjects = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _connectionId = widget.session.youtrackConnections.first.id;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final conn = widget.session.youtrackConnections.firstWhereOrNull((c) => c.id == _connectionId);
    if (conn == null) return;
    setState(() {
      _loadingProjects = true;
      _loadError = null;
      _projects = [];
    });
    try {
      final client = YouTrackApiClient(connection: conn);
      final list = await client.getProjects();
      setState(() {
        _projects = list;
        if (list.isNotEmpty) {
          _selectedProjectId = list.first.id;
          _selectedProjectShortName = list.first.shortName;
        }
      });
    } catch (e) {
      setState(() => _loadError = 'Failed to load projects: $e');
    } finally {
      setState(() => _loadingProjects = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conns = widget.session.youtrackConnections;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.youtrackAddSource,
            onBack: widget.onCancel,
          ),
          const SizedBox(height: 10),
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.youtrackSourceName,
                    hintText: 'e.g. My Sprint Backlog',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.youtrackRequired : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _connectionId,
                  decoration: InputDecoration(labelText: l10n.youtrackConnectionLabel),
                  items: conns
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _connectionId = v;
                      });
                      _loadProjects();
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<YouTrackSourceType>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l10n.youtrackSourceType),
                  items: [
                    DropdownMenuItem(
                        value: YouTrackSourceType.project,
                        child: Text(l10n.youtrackFullProject)),
                    DropdownMenuItem(
                        value: YouTrackSourceType.query,
                        child: Text(l10n.youtrackCustomQuery)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _type = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_type == YouTrackSourceType.project) ...[
                  if (_loadingProjects)
                    const Padding(padding: EdgeInsets.all(12), child: FolioLoadingIndicator(centered: true))
                  else if (_loadError != null)
                    Text(_loadError!, style: TextStyle(color: scheme.error, fontSize: 13))
                  else if (_projects.isEmpty)
                    Text(l10n.youtrackNoProjectsFound)
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProjectId,
                      decoration: InputDecoration(labelText: l10n.youtrackSelectProject),
                      items: _projects
                          .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.shortName})')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          final project = _projects.firstWhereOrNull((p) => p.id == v);
                          setState(() {
                            _selectedProjectId = v;
                            _selectedProjectShortName = project?.shortName;
                          });
                        }
                      },
                    ),
                ] else ...[
                  TextFormField(
                    controller: _queryCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.youtrackSearchQueryLabel,
                      hintText: 'e.g. project: DEMO state: -Fixed, -Done',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.youtrackRequired : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final query = _type == YouTrackSourceType.query ? _queryCtrl.text.trim() : null;

    final source = YouTrackSource(
      id: const Uuid().v4(),
      connectionId: _connectionId,
      type: _type,
      name: name,
      query: query,
      projectId: _selectedProjectId,
      projectShortName: _selectedProjectShortName,
      importOptions: const YouTrackImportOptions(),
      columnMappings: const [
        YouTrackColumnMapping(columnId: 'todo', stateName: 'To Do'),
        YouTrackColumnMapping(columnId: 'in_progress', stateName: 'In Progress'),
        YouTrackColumnMapping(columnId: 'done', stateName: 'Fixed'),
      ],
    );

    widget.session.upsertYouTrackSource(source);
    widget.onDone();
  }
}

class _EditMappingsForm extends StatefulWidget {
  const _EditMappingsForm({
    required this.session,
    required this.source,
    required this.onCancel,
    required this.onDone,
  });
  final VaultSession session;
  final YouTrackSource source;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_EditMappingsForm> createState() => _EditMappingsFormState();
}

class _EditMappingsFormState extends State<_EditMappingsForm> {
  late final List<YouTrackColumnMapping> _mappings = widget.source.columnMappings.toList();
  late YouTrackImportOptions _options = widget.source.importOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.youtrackConfigureMappings,
            onBack: widget.onCancel,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.youtrackImportOptions,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          IntegrationImportOptionsChips(
            options: [
              IntegrationImportOption(
                label: l10n.youtrackComments,
                selected: _options.includeComments,
                onChanged: (v) => setState(() => _options = YouTrackImportOptions(
                      includeComments: v,
                      includeAttachments: _options.includeAttachments,
                    )),
              ),
              IntegrationImportOption(
                label: l10n.youtrackAttachments,
                selected: _options.includeAttachments,
                onChanged: (v) => setState(() => _options = YouTrackImportOptions(
                      includeComments: _options.includeComments,
                      includeAttachments: v,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.youtrackColumnMapping,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < _mappings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _columnName(_mappings[i].columnId, l10n),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: _mappings[i].stateName ?? '',
                      decoration: InputDecoration(
                        hintText: l10n.youtrackStateHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        _mappings[i] = YouTrackColumnMapping(
                          columnId: _mappings[i].columnId,
                          stateName: val.trim(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final nextSource = YouTrackSource(
                    id: widget.source.id,
                    connectionId: widget.source.connectionId,
                    type: widget.source.type,
                    name: widget.source.name,
                    query: widget.source.query,
                    projectId: widget.source.projectId,
                    projectShortName: widget.source.projectShortName,
                    importOptions: _options,
                    columnMappings: _mappings,
                  );
                  widget.session.upsertYouTrackSource(nextSource);
                  widget.onDone();
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _columnName(String columnId, AppLocalizations l10n) {
    switch (columnId) {
      case 'todo':
        return l10n.youtrackColumnTodo;
      case 'in_progress':
        return l10n.youtrackColumnInProgress;
      case 'done':
        return l10n.youtrackColumnDone;
      default:
        return columnId;
    }
  }
}
