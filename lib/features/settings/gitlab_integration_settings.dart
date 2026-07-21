import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/gitlab_integration_state.dart';
import '../../services/gitlab/gitlab_api_client.dart';
import '../../session/vault_session.dart';
import '../../utils/private_host.dart';

const List<String> kGitLabPriorities = ['low', 'medium', 'high'];
const String kGitLabDefaultBaseUrl = 'https://gitlab.com';

class GitLabIntegrationCard extends StatelessWidget {
  const GitLabIntegrationCard({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.gitlabConnections;
        final sources = session.gitlabSources;
        return IntegrationCard(
          logoAsset: 'appLogos/gitlab.png',
          title: 'GitLab',
          subtitle: isEs
              ? 'Conecta GitLab para sincronizar Issues y Merge Requests con Kanban.'
              : 'Connect GitLab to sync Issues and Merge Requests with Kanban.',
          configureLabel: l10n.gitlabConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => GitLabIntegrationConfigDialog(
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
              icon: Icons.dashboard_outlined,
              label: isEs ? '${sources.length} proyectos' : '${sources.length} projects',
            ),
          ],
        );
      },
    );
  }
}

class GitLabIntegrationConfigDialog extends StatefulWidget {
  const GitLabIntegrationConfigDialog({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<GitLabIntegrationConfigDialog> createState() =>
      _GitLabIntegrationConfigDialogState();
}

class _GitLabIntegrationConfigDialogState
    extends State<GitLabIntegrationConfigDialog>
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
      logoAsset: 'appLogos/gitlab.png',
      title: l10n.gitlabIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.gitlabConnectionsTab,
      sourcesTabLabel: l10n.gitlabSourcesTab,
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
    final conns = widget.session.gitlabConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.gitlabNoConnections)
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
                          onPressed: () => widget.session.removeGitLabConnection(c.id),
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
          label: Text(l10n.gitlabAddConnection),
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
  final _baseUrlCtrl = TextEditingController(text: kGitLabDefaultBaseUrl);
  final _tokenCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _baseUrlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  String get _normalizedBaseUrl {
    final raw = _baseUrlCtrl.text.trim();
    final base = raw.isEmpty ? kGitLabDefaultBaseUrl : raw;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Future<void> _openTokenPage() async {
    final uri = Uri.tryParse(
      '$_normalizedBaseUrl/-/user_settings/personal_access_tokens'
      '?scopes=api&name=Folio',
    );
    if (uri == null) return;
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
            title: l10n.gitlabNewConnectionTitle,
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
                    labelText: l10n.gitlabConnectionName,
                    hintText: 'e.g. My GitLab',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.gitlabRequired : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _baseUrlCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.gitlabBaseUrlLabel,
                    hintText: kGitLabDefaultBaseUrl,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.hasScheme) return l10n.gitlabRequired;
                    if (uri.scheme == 'http' &&
                        !isPrivateOrLocalHost(uri.host)) {
                      return l10n.gitlabRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.gitlabTokenLabel,
                    suffixIcon: IconButton(
                      tooltip: l10n.gitlabGetToken,
                      icon: const Icon(Icons.open_in_new_rounded),
                      onPressed: _openTokenPage,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.gitlabRequired : null,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.gitlabAuthHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
                    : Text(l10n.gitlabConnectAndSave),
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
    final token = _tokenCtrl.text.trim();

    final tempConn = GitLabConnection(
      id: const Uuid().v4(),
      label: label,
      baseUrl: _normalizedBaseUrl,
      token: token,
    );

    try {
      final client = GitLabApiClient(connection: tempConn);
      await client.verifyConnection();

      widget.session.upsertGitLabConnection(tempConn);
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
  GitLabSource? _editingMappingsFor;

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
    final scheme = Theme.of(context).colorScheme;
    final sources = widget.session.gitlabSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: sources.isEmpty
              ? IntegrationEmptyState(text: l10n.gitlabNoProjects)
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    return IntegrationEntryRow(
                      icon: Icons.dashboard_outlined,
                      title: s.name,
                      subtitle: s.projectPath,
                      trailing: [
                        IconButton(
                          tooltip: l10n.gitlabMapColumnsAndPriorities,
                          icon: const Icon(Icons.map_rounded),
                          onPressed: () => setState(() => _editingMappingsFor = s),
                        ),
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeGitLabSource(s.id),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: widget.session.gitlabConnections.isEmpty
              ? null
              : () => setState(() => _adding = true),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.gitlabAddProject),
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

  late String _connectionId;
  List<GitLabProject> _projects = [];
  String? _selectedProjectPath;
  bool _includeMergeRequests = true;
  bool _loadingProjects = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _connectionId = widget.session.gitlabConnections.first.id;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final conn = widget.session.gitlabConnections.firstWhereOrNull((c) => c.id == _connectionId);
    if (conn == null) return;
    setState(() {
      _loadingProjects = true;
      _loadError = null;
      _projects = [];
    });
    try {
      final client = GitLabApiClient(connection: conn);
      final list = await client.listProjects();
      setState(() {
        _projects = list;
        if (list.isNotEmpty) {
          _selectedProjectPath = list.first.pathWithNamespace;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conns = widget.session.gitlabConnections;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.gitlabAddProject,
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
                    labelText: l10n.gitlabSourceName,
                    hintText: 'e.g. My Project',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.gitlabRequired : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _connectionId,
                  decoration: InputDecoration(labelText: l10n.gitlabConnectionLabel),
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
                if (_loadingProjects)
                  const Padding(padding: EdgeInsets.all(12), child: FolioLoadingIndicator(centered: true))
                else if (_loadError != null)
                  Text(_loadError!, style: TextStyle(color: scheme.error, fontSize: 13))
                else if (_projects.isEmpty)
                  Text(l10n.gitlabNoProjectsFound)
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProjectPath,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.gitlabSelectProject),
                    items: _projects
                        .map((p) => DropdownMenuItem(
                              value: p.pathWithNamespace,
                              child: Text(p.pathWithNamespace),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedProjectPath = v);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _includeMergeRequests,
                  onChanged: (v) => setState(() => _includeMergeRequests = v ?? true),
                  title: Text(l10n.gitlabIncludeMergeRequests),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
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
                onPressed: _selectedProjectPath == null ? null : _submit,
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
    final projectPath = _selectedProjectPath;
    if (projectPath == null) return;

    final name = _nameCtrl.text.trim();

    final source = GitLabSource(
      id: const Uuid().v4(),
      connectionId: _connectionId,
      name: name,
      projectPath: projectPath,
      includeMergeRequests: _includeMergeRequests,
      importOptions: const GitLabImportOptions(),
      columnMappings: const [
        GitLabColumnMapping(columnId: 'todo', stateValue: 'opened'),
        GitLabColumnMapping(columnId: 'in_progress'),
        GitLabColumnMapping(columnId: 'done', stateValue: 'closed'),
      ],
      priorityLabelMappings: const [],
    );

    widget.session.upsertGitLabSource(source);
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
  final GitLabSource source;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_EditMappingsForm> createState() => _EditMappingsFormState();
}

class _EditMappingsFormState extends State<_EditMappingsForm> {
  late final List<GitLabColumnMapping> _mappings = widget.source.columnMappings.toList();
  late List<GitLabPriorityLabelMapping> _priorityMappings =
      widget.source.priorityLabelMappings.toList();
  late GitLabImportOptions _options = widget.source.importOptions;
  late bool _includeMergeRequests = widget.source.includeMergeRequests;

  List<GitLabLabel> _labels = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProjectData();
  }

  Future<void> _loadProjectData() async {
    final conn = widget.session.gitlabConnections
        .firstWhereOrNull((c) => c.id == widget.source.connectionId);
    if (conn == null) {
      setState(() {
        _loading = false;
        _loadError = 'Connection not found';
      });
      return;
    }
    try {
      final client = GitLabApiClient(connection: conn);
      final labels = await client.getLabels(widget.source.projectPath);
      setState(() {
        _labels = labels;
      });
    } catch (e) {
      setState(() => _loadError = 'Failed to load project data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntegrationInlineFormHeader(
          title: l10n.gitlabConfigureMappings,
          onBack: widget.onCancel,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const FolioLoadingIndicator(centered: true)
              : _loadError != null
                  ? Text(_loadError!, style: TextStyle(color: scheme.error))
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.gitlabImportOptions,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          IntegrationImportOptionsChips(
                            options: [
                              IntegrationImportOption(
                                label: l10n.gitlabComments,
                                selected: _options.includeComments,
                                onChanged: (v) => setState(() => _options = GitLabImportOptions(
                                      includeComments: v,
                                      includeAssignees: _options.includeAssignees,
                                    )),
                              ),
                              IntegrationImportOption(
                                label: l10n.gitlabAssignees,
                                selected: _options.includeAssignees,
                                onChanged: (v) => setState(() => _options = GitLabImportOptions(
                                      includeComments: _options.includeComments,
                                      includeAssignees: v,
                                    )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _includeMergeRequests,
                            onChanged: (v) => setState(() => _includeMergeRequests = v ?? true),
                            title: Text(l10n.gitlabIncludeMergeRequests),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.gitlabColumnMapping,
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
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _mappings[i].stateValue ?? '',
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: l10n.gitlabStateHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        DropdownMenuItem(value: '', child: Text(l10n.gitlabNone)),
                                        DropdownMenuItem(value: 'opened', child: Text(l10n.gitlabStateOpen)),
                                        DropdownMenuItem(value: 'closed', child: Text(l10n.gitlabStateClosed)),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _mappings[i] = GitLabColumnMapping(
                                            columnId: _mappings[i].columnId,
                                            stateValue: (v == null || v.isEmpty) ? null : v,
                                            labelName: _mappings[i].labelName,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _labels.any((l) => l.name == _mappings[i].labelName)
                                          ? _mappings[i].labelName
                                          : null,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: l10n.gitlabLabelHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        DropdownMenuItem(value: null, child: Text(l10n.gitlabNone)),
                                        ..._labels.map(
                                          (l) => DropdownMenuItem(value: l.name, child: Text(l.name)),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _mappings[i] = GitLabColumnMapping(
                                            columnId: _mappings[i].columnId,
                                            stateValue: _mappings[i].stateValue,
                                            labelName: v,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.gitlabPriorityMapping,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          for (final priority in kGitLabPriorities)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Text(_priorityName(priority, l10n))),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward_rounded, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _priorityMappings
                                              .firstWhereOrNull((m) => m.priority == priority)
                                              ?.labelName ??
                                          '',
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: l10n.gitlabLabelHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: '',
                                          child: Text(l10n.gitlabNone),
                                        ),
                                        ..._labels.map(
                                          (l) => DropdownMenuItem(
                                            value: l.name,
                                            child: Text(l.name),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _priorityMappings =
                                              _priorityMappings.where((m) => m.priority != priority).toList();
                                          if (v != null && v.isNotEmpty) {
                                            final label = _labels.firstWhereOrNull((l) => l.name == v);
                                            _priorityMappings.add(GitLabPriorityLabelMapping(
                                              priority: priority,
                                              labelName: v,
                                              color: label?.color,
                                            ));
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () {
                      final nextSource = GitLabSource(
                        id: widget.source.id,
                        connectionId: widget.source.connectionId,
                        name: widget.source.name,
                        projectPath: widget.source.projectPath,
                        includeMergeRequests: _includeMergeRequests,
                        importOptions: _options,
                        columnMappings: _mappings,
                        priorityLabelMappings: _priorityMappings,
                      );
                      widget.session.upsertGitLabSource(nextSource);
                      widget.onDone();
                    },
              child: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }

  String _columnName(String columnId, AppLocalizations l10n) {
    switch (columnId) {
      case 'todo':
        return l10n.gitlabColumnTodo;
      case 'in_progress':
        return l10n.gitlabColumnInProgress;
      case 'done':
        return l10n.gitlabColumnDone;
      default:
        return columnId;
    }
  }

  String _priorityName(String priority, AppLocalizations l10n) {
    switch (priority) {
      case 'low':
        return l10n.gitlabPriorityLow;
      case 'medium':
        return l10n.gitlabPriorityMedium;
      case 'high':
        return l10n.gitlabPriorityHigh;
      default:
        return priority;
    }
  }
}
