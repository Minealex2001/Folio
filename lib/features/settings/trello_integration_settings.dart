import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/trello_integration_state.dart';
import '../../services/oauth/oauth_launch.dart';
import '../../services/trello/trello_api_client.dart';
import '../../services/trello/trello_auth_config.dart';
import '../../session/vault_session.dart';

const List<String> kTrelloPriorities = ['low', 'medium', 'high'];

class TrelloIntegrationCard extends StatelessWidget {
  const TrelloIntegrationCard({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final connections = session.trelloConnections;
        final sources = session.trelloSources;
        return IntegrationCard(
          logoAsset: 'appLogos/trello.png',
          title: 'Trello',
          subtitle: isEs
              ? 'Conecta Trello para sincronizar tableros completos con Kanban.'
              : 'Connect Trello to sync entire boards with Kanban.',
          configureLabel: l10n.trelloConfigure,
          onConfigure: session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => TrelloIntegrationConfigDialog(
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
              label: isEs ? '${sources.length} tableros' : '${sources.length} boards',
            ),
          ],
        );
      },
    );
  }
}

class TrelloIntegrationConfigDialog extends StatefulWidget {
  const TrelloIntegrationConfigDialog({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<TrelloIntegrationConfigDialog> createState() =>
      _TrelloIntegrationConfigDialogState();
}

class _TrelloIntegrationConfigDialogState
    extends State<TrelloIntegrationConfigDialog>
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
      logoAsset: 'appLogos/trello.png',
      title: l10n.trelloIntegrationTitle,
      tabController: _tabController,
      connectionsTabLabel: l10n.trelloConnectionsTab,
      sourcesTabLabel: l10n.trelloSourcesTab,
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
    final conns = widget.session.trelloConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: conns.isEmpty
              ? IntegrationEmptyState(text: l10n.trelloNoConnections)
              : ListView.separated(
                  itemCount: conns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = conns[i];
                    return IntegrationEntryRow(
                      icon: Icons.link_rounded,
                      title: c.label,
                      subtitle: 'api.trello.com',
                      trailing: [
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeTrelloConnection(c.id),
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
          label: Text(l10n.trelloAddConnection),
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

  Future<void> _openAuthorizePage() async {
    final uri = Uri.parse(
      'https://trello.com/1/authorize'
      '?expiration=never&name=Folio&scope=read,write&response_type=token'
      '&key=${TrelloAuthConfig.officialApiKey}',
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
            title: l10n.trelloNewConnectionTitle,
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
                    labelText: l10n.trelloConnectionName,
                    hintText: 'e.g. My Trello',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.trelloRequired : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.trelloTokenLabel,
                    suffixIcon: IconButton(
                      tooltip: l10n.trelloGetToken,
                      icon: const Icon(Icons.open_in_new_rounded),
                      onPressed: _openAuthorizePage,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.trelloRequired : null,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.trelloAuthHelp,
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
                    : Text(l10n.trelloConnectAndSave),
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

    final tempConn = TrelloConnection(
      id: const Uuid().v4(),
      label: label,
      apiKey: TrelloAuthConfig.officialApiKey,
      token: token,
    );

    try {
      final client = TrelloApiClient(connection: tempConn);
      await client.verifyConnection();

      widget.session.upsertTrelloConnection(tempConn);
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
  TrelloSource? _editingMappingsFor;

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
    final sources = widget.session.trelloSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: sources.isEmpty
              ? IntegrationEmptyState(text: l10n.trelloNoBoards)
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    return IntegrationEntryRow(
                      icon: Icons.dashboard_outlined,
                      title: s.name,
                      subtitle: s.boardName ?? s.boardId,
                      trailing: [
                        IconButton(
                          tooltip: l10n.trelloMapColumnsAndPriorities,
                          icon: const Icon(Icons.map_rounded),
                          onPressed: () => setState(() => _editingMappingsFor = s),
                        ),
                        IconButton(
                          tooltip: l10n.delete,
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => widget.session.removeTrelloSource(s.id),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: widget.session.trelloConnections.isEmpty
              ? null
              : () => setState(() => _adding = true),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.trelloAddBoard),
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
  List<TrelloBoard> _boards = [];
  String? _selectedBoardId;
  String? _selectedBoardName;
  bool _loadingBoards = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _connectionId = widget.session.trelloConnections.first.id;
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    final conn = widget.session.trelloConnections.firstWhereOrNull((c) => c.id == _connectionId);
    if (conn == null) return;
    setState(() {
      _loadingBoards = true;
      _loadError = null;
      _boards = [];
    });
    try {
      final client = TrelloApiClient(connection: conn);
      final list = await client.getBoards();
      setState(() {
        _boards = list;
        if (list.isNotEmpty) {
          _selectedBoardId = list.first.id;
          _selectedBoardName = list.first.name;
        }
      });
    } catch (e) {
      setState(() => _loadError = 'Failed to load boards: $e');
    } finally {
      setState(() => _loadingBoards = false);
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
    final conns = widget.session.trelloConnections;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntegrationInlineFormHeader(
            title: l10n.trelloAddBoard,
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
                    labelText: l10n.trelloSourceName,
                    hintText: 'e.g. My Project Board',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.trelloRequired : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _connectionId,
                  decoration: InputDecoration(labelText: l10n.trelloConnectionLabel),
                  items: conns
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _connectionId = v;
                      });
                      _loadBoards();
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_loadingBoards)
                  const Padding(padding: EdgeInsets.all(12), child: FolioLoadingIndicator(centered: true))
                else if (_loadError != null)
                  Text(_loadError!, style: TextStyle(color: scheme.error, fontSize: 13))
                else if (_boards.isEmpty)
                  Text(l10n.trelloNoBoardsFound)
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBoardId,
                    decoration: InputDecoration(labelText: l10n.trelloSelectBoard),
                    items: _boards
                        .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final board = _boards.firstWhereOrNull((b) => b.id == v);
                        setState(() {
                          _selectedBoardId = v;
                          _selectedBoardName = board?.name;
                        });
                      }
                    },
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
                onPressed: _selectedBoardId == null ? null : _submit,
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
    if (_selectedBoardId == null) return;

    final name = _nameCtrl.text.trim();

    final source = TrelloSource(
      id: const Uuid().v4(),
      connectionId: _connectionId,
      name: name,
      boardId: _selectedBoardId!,
      boardName: _selectedBoardName,
      importOptions: const TrelloImportOptions(),
      columnMappings: const [
        TrelloColumnMapping(columnId: 'todo'),
        TrelloColumnMapping(columnId: 'in_progress'),
        TrelloColumnMapping(columnId: 'done'),
      ],
      priorityLabelMappings: const [],
    );

    widget.session.upsertTrelloSource(source);
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
  final TrelloSource source;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_EditMappingsForm> createState() => _EditMappingsFormState();
}

class _EditMappingsFormState extends State<_EditMappingsForm> {
  late final List<TrelloColumnMapping> _mappings = widget.source.columnMappings.toList();
  late List<TrelloPriorityLabelMapping> _priorityMappings =
      widget.source.priorityLabelMappings.toList();
  late TrelloImportOptions _options = widget.source.importOptions;

  List<TrelloList> _lists = [];
  List<TrelloLabel> _labels = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBoardData();
  }

  Future<void> _loadBoardData() async {
    final conn = widget.session.trelloConnections
        .firstWhereOrNull((c) => c.id == widget.source.connectionId);
    if (conn == null) {
      setState(() {
        _loading = false;
        _loadError = 'Connection not found';
      });
      return;
    }
    try {
      final client = TrelloApiClient(connection: conn);
      final lists = await client.getLists(widget.source.boardId);
      final labels = await client.getBoardLabels(widget.source.boardId);
      setState(() {
        _lists = lists;
        _labels = labels;
      });
    } catch (e) {
      setState(() => _loadError = 'Failed to load board data: $e');
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
          title: l10n.trelloConfigureMappings,
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
                            l10n.trelloImportOptions,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          IntegrationImportOptionsChips(
                            options: [
                              IntegrationImportOption(
                                label: l10n.trelloComments,
                                selected: _options.includeComments,
                                onChanged: (v) => setState(() => _options = TrelloImportOptions(
                                      includeComments: v,
                                      includeAttachments: _options.includeAttachments,
                                      includeChecklists: _options.includeChecklists,
                                    )),
                              ),
                              IntegrationImportOption(
                                label: l10n.trelloAttachments,
                                selected: _options.includeAttachments,
                                onChanged: (v) => setState(() => _options = TrelloImportOptions(
                                      includeComments: _options.includeComments,
                                      includeAttachments: v,
                                      includeChecklists: _options.includeChecklists,
                                    )),
                              ),
                              IntegrationImportOption(
                                label: l10n.trelloChecklists,
                                selected: _options.includeChecklists,
                                onChanged: (v) => setState(() => _options = TrelloImportOptions(
                                      includeComments: _options.includeComments,
                                      includeAttachments: _options.includeAttachments,
                                      includeChecklists: v,
                                    )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.trelloColumnMapping,
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
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _lists.any((l) => l.id == _mappings[i].listId)
                                          ? _mappings[i].listId
                                          : null,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: l10n.trelloListHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: _lists
                                          .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                                          .toList(),
                                      onChanged: (v) {
                                        final list = _lists.firstWhereOrNull((l) => l.id == v);
                                        setState(() {
                                          _mappings[i] = TrelloColumnMapping(
                                            columnId: _mappings[i].columnId,
                                            listId: v,
                                            listName: list?.name,
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
                            l10n.trelloPriorityMapping,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          for (final priority in kTrelloPriorities)
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
                                              ?.labelId ??
                                          '',
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: l10n.trelloLabelHint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: '',
                                          child: Text(l10n.trelloNone),
                                        ),
                                        ..._labels.map(
                                          (l) => DropdownMenuItem(
                                            value: l.id,
                                            child: Text(l.name.isEmpty ? (l.color ?? l.id) : l.name),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _priorityMappings =
                                              _priorityMappings.where((m) => m.priority != priority).toList();
                                          if (v != null && v.isNotEmpty) {
                                            final label = _labels.firstWhereOrNull((l) => l.id == v);
                                            _priorityMappings.add(TrelloPriorityLabelMapping(
                                              priority: priority,
                                              labelId: v,
                                              labelName: label?.name,
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
                      final nextSource = TrelloSource(
                        id: widget.source.id,
                        connectionId: widget.source.connectionId,
                        name: widget.source.name,
                        boardId: widget.source.boardId,
                        boardName: widget.source.boardName,
                        importOptions: _options,
                        columnMappings: _mappings,
                        priorityLabelMappings: _priorityMappings,
                      );
                      widget.session.upsertTrelloSource(nextSource);
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
        return l10n.trelloColumnTodo;
      case 'in_progress':
        return l10n.trelloColumnInProgress;
      case 'done':
        return l10n.trelloColumnDone;
      default:
        return columnId;
    }
  }

  String _priorityName(String priority, AppLocalizations l10n) {
    switch (priority) {
      case 'low':
        return l10n.trelloPriorityLow;
      case 'medium':
        return l10n.trelloPriorityMedium;
      case 'high':
        return l10n.trelloPriorityHigh;
      default:
        return priority;
    }
  }
}
