import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/github_integration_state.dart';
import '../../services/github/github_api_client.dart';
import '../../services/oauth/oauth_launch.dart';
import '../../session/vault_session.dart';

const List<String> kGitHubPriorities = ['low', 'medium', 'high'];
const List<String> kGitHubDefaultColumns = ['todo', 'in_progress', 'done'];

class GitHubIntegrationCard extends StatelessWidget {
  const GitHubIntegrationCard({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.githubConnections;
        final sources = session.githubSources;
        return IntegrationCard(
          logoAsset: 'appLogos/github.png',
          title: 'GitHub',
          subtitle: l10n.githubCardSubtitle,
          configureLabel: l10n.githubConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => GitHubIntegrationConfigDialog(
                      session: session,
                      appSettings: appSettings,
                    ),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: Icons.link_rounded,
              label: l10n.githubConnectionsCount(connections.length),
            ),
            IntegrationStatChip(
              icon: Icons.dashboard_outlined,
              label: '${sources.length} repos',
            ),
          ],
        );
      },
    );
  }
}

class GitHubIntegrationConfigDialog extends StatefulWidget {
  const GitHubIntegrationConfigDialog({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<GitHubIntegrationConfigDialog> createState() =>
      _GitHubIntegrationConfigDialogState();
}

class _GitHubIntegrationConfigDialogState
    extends State<GitHubIntegrationConfigDialog>
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
      logoAsset: 'appLogos/github.png',
      title: l10n.githubIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.githubConnectionsTab,
      sourcesTabLabel: l10n.githubSourcesTab,
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
    final conns = widget.session.githubConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.githubNoConnections)
              : ListView.separated(
                  itemCount: conns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = conns[i];
                    return IntegrationEntryRow(
                      icon: Icons.link_rounded,
                      title: c.label,
                      subtitle: 'api.github.com',
                      trailing: [
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeGitHubConnection(c.id),
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
          label: Text(l10n.githubAddConnection),
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
  final _tokenCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTokenPage() async {
    final uri = Uri.parse(
      'https://github.com/settings/tokens/new'
      '?scopes=repo&description=Folio',
    );
    await launchOAuthAuthorizeUrl(uri);
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
            title: l10n.githubNewConnectionTitle,
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
                    labelText: l10n.githubConnectionName,
                    hintText: 'e.g. My GitHub',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.githubRequired : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.githubTokenLabel,
                    suffixIcon: IconButton(
                      tooltip: l10n.githubGetToken,
                      icon: const Icon(Icons.open_in_new_rounded),
                      onPressed: _openTokenPage,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.githubRequired : null,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.githubAuthHelp,
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
                    : Text(l10n.githubConnectAndSave),
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

    final tempConn = GitHubConnection(
      id: const Uuid().v4(),
      label: label,
      token: token,
    );

    try {
      final client = GitHubApiClient(connection: tempConn);
      await client.verifyConnection();

      widget.session.upsertGitHubConnection(tempConn);
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
  GitHubSource? _editingMappingsFor;

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
    final sources = widget.session.githubSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: sources.isEmpty
              ? IntegrationEmptyState(text: l10n.githubNoRepos)
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    return IntegrationEntryRow(
                      icon: Icons.dashboard_outlined,
                      title: s.name,
                      subtitle: '${s.owner}/${s.repo}',
                      trailing: [
                        IconButton(
                          tooltip: l10n.githubMapColumnsAndPriorities,
                          icon: const Icon(Icons.map_rounded),
                          onPressed: () => setState(() => _editingMappingsFor = s),
                        ),
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeGitHubSource(s.id),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: widget.session.githubConnections.isEmpty
              ? null
              : () => setState(() => _adding = true),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.githubAddRepo),
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
  List<GitHubRepo> _repos = [];
  String? _selectedRepoFullName;
  bool _includePullRequests = true;
  bool _loadingRepos = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _connectionId = widget.session.githubConnections.first.id;
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    final conn = widget.session.githubConnections.firstWhereOrNull((c) => c.id == _connectionId);
    if (conn == null) return;
    setState(() {
      _loadingRepos = true;
      _loadError = null;
      _repos = [];
    });
    try {
      final client = GitHubApiClient(connection: conn);
      final list = await client.listRepos();
      setState(() {
        _repos = list;
        if (list.isNotEmpty) {
          _selectedRepoFullName = list.first.fullName;
        }
      });
    } catch (e) {
      setState(() => _loadError = 'Failed to load repositories: $e');
    } finally {
      setState(() => _loadingRepos = false);
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
    final conns = widget.session.githubConnections;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.githubAddRepo,
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
                    labelText: l10n.githubSourceName,
                    hintText: 'e.g. My Project Repo',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.githubRequired : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _connectionId,
                  decoration: InputDecoration(labelText: l10n.githubConnectionLabel),
                  items: conns
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _connectionId = v;
                      });
                      _loadRepos();
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_loadingRepos)
                  const Padding(padding: EdgeInsets.all(12), child: FolioLoadingIndicator(centered: true))
                else if (_loadError != null)
                  Text(_loadError!, style: TextStyle(color: scheme.error, fontSize: 13))
                else if (_repos.isEmpty)
                  Text(l10n.githubNoReposFound)
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRepoFullName,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.githubSelectRepo),
                    items: _repos
                        .map((r) => DropdownMenuItem(value: r.fullName, child: Text(r.fullName)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedRepoFullName = v);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _includePullRequests,
                  onChanged: (v) => setState(() => _includePullRequests = v ?? true),
                  title: Text(l10n.githubIncludePullRequests),
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
                onPressed: _selectedRepoFullName == null ? null : _submit,
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
    final fullName = _selectedRepoFullName;
    if (fullName == null) return;
    final repo = _repos.firstWhereOrNull((r) => r.fullName == fullName);
    final owner = repo?.owner ?? fullName.split('/').first;
    final repoName = repo?.name ?? fullName.split('/').last;

    final name = _nameCtrl.text.trim();

    final source = GitHubSource(
      id: const Uuid().v4(),
      connectionId: _connectionId,
      name: name,
      owner: owner,
      repo: repoName,
      includePullRequests: _includePullRequests,
      importOptions: const GitHubImportOptions(),
      columnMappings: const [
        GitHubColumnMapping(columnId: 'todo', stateValue: 'open'),
        GitHubColumnMapping(columnId: 'in_progress'),
        GitHubColumnMapping(columnId: 'done', stateValue: 'closed'),
      ],
      priorityLabelMappings: const [],
    );

    widget.session.upsertGitHubSource(source);
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
  final GitHubSource source;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_EditMappingsForm> createState() => _EditMappingsFormState();
}

class _EditMappingsFormState extends State<_EditMappingsForm> {
  late final List<GitHubColumnMapping> _mappings = widget.source.columnMappings.toList();
  late List<GitHubPriorityLabelMapping> _priorityMappings =
      widget.source.priorityLabelMappings.toList();
  late GitHubImportOptions _options = widget.source.importOptions;
  late bool _includePullRequests = widget.source.includePullRequests;

  List<GitHubLabel> _labels = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRepoData();
  }

  Future<void> _loadRepoData() async {
    final conn = widget.session.githubConnections
        .firstWhereOrNull((c) => c.id == widget.source.connectionId);
    if (conn == null) {
      setState(() {
        _loading = false;
        _loadError = 'Connection not found';
      });
      return;
    }
    try {
      final client = GitHubApiClient(connection: conn);
      final labels = await client.getLabels(widget.source.owner, widget.source.repo);
      setState(() {
        _labels = labels;
      });
    } catch (e) {
      setState(() => _loadError = 'Failed to load repository data: $e');
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
          title: l10n.githubConfigureMappings,
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
                            l10n.githubImportOptions,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          IntegrationImportOptionsChips(
                            options: [
                              IntegrationImportOption(
                                label: l10n.githubComments,
                                selected: _options.includeComments,
                                onChanged: (v) => setState(() => _options = GitHubImportOptions(
                                      includeComments: v,
                                      includeAssignees: _options.includeAssignees,
                                    )),
                              ),
                              IntegrationImportOption(
                                label: l10n.githubAssignees,
                                selected: _options.includeAssignees,
                                onChanged: (v) => setState(() => _options = GitHubImportOptions(
                                      includeComments: _options.includeComments,
                                      includeAssignees: v,
                                    )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _includePullRequests,
                            onChanged: (v) => setState(() => _includePullRequests = v ?? true),
                            title: Text(l10n.githubIncludePullRequests),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.githubColumnMapping,
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
                                        hintText: l10n.githubStateHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        DropdownMenuItem(value: '', child: Text(l10n.githubNone)),
                                        DropdownMenuItem(value: 'open', child: Text(l10n.githubStateOpen)),
                                        DropdownMenuItem(value: 'closed', child: Text(l10n.githubStateClosed)),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _mappings[i] = GitHubColumnMapping(
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
                                        hintText: l10n.githubLabelHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        DropdownMenuItem(value: null, child: Text(l10n.githubNone)),
                                        ..._labels.map(
                                          (l) => DropdownMenuItem(value: l.name, child: Text(l.name)),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _mappings[i] = GitHubColumnMapping(
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
                            l10n.githubPriorityMapping,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          for (final priority in kGitHubPriorities)
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
                                        hintText: l10n.githubLabelHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: '',
                                          child: Text(l10n.githubNone),
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
                                            _priorityMappings.add(GitHubPriorityLabelMapping(
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
                      final nextSource = GitHubSource(
                        id: widget.source.id,
                        connectionId: widget.source.connectionId,
                        name: widget.source.name,
                        owner: widget.source.owner,
                        repo: widget.source.repo,
                        includePullRequests: _includePullRequests,
                        importOptions: _options,
                        columnMappings: _mappings,
                        priorityLabelMappings: _priorityMappings,
                      );
                      widget.session.upsertGitHubSource(nextSource);
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
        return l10n.githubColumnTodo;
      case 'in_progress':
        return l10n.githubColumnInProgress;
      case 'done':
        return l10n.githubColumnDone;
      default:
        return columnId;
    }
  }

  String _priorityName(String priority, AppLocalizations l10n) {
    switch (priority) {
      case 'low':
        return l10n.githubPriorityLow;
      case 'medium':
        return l10n.githubPriorityMedium;
      case 'high':
        return l10n.githubPriorityHigh;
      default:
        return priority;
    }
  }
}
