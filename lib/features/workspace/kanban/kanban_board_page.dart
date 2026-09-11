import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_kanban_data.dart';
import '../../../models/folio_page.dart';
import '../../../models/vault_task_list_entry.dart';
import '../../../session/vault_session.dart';
import '../../../services/jira/jira_sync_service.dart';
import '../../../services/youtrack/youtrack_sync_service.dart';
import '../../../services/trello/trello_sync_service.dart';
import '../../../services/github/github_sync_service.dart';
import '../../../services/gitlab/gitlab_sync_service.dart';
import '../tasks/task_details_panel.dart';
import 'kanban_integration_sync_controller.dart';
import 'kanban_persistence_controller.dart';

enum _KanbanFilter { all, active, done, dueToday, dueWeek, overdue }

TextStyle? _kanbanTaskTitleStyle({
  required TextTheme textTheme,
  required ColorScheme scheme,
  required VaultTaskListEntry e,
}) {
  final blocked = e.isBlocked;
  final strike = blocked || e.isDone;
  return textTheme.titleSmall?.copyWith(
    color: blocked ? scheme.error : null,
    decoration: strike ? TextDecoration.lineThrough : null,
    decorationColor: blocked ? scheme.error : null,
  );
}

/// Tablero Kanban para una sola página (modo página al detectar bloque `kanban`).
class KanbanBoardPage extends StatefulWidget {
  const KanbanBoardPage({
    super.key,
    required this.pageId,
    required this.session,
    required this.appSettings,
    required this.onOpenClassicEditor,
  });

  final String pageId;
  final VaultSession session;
  final AppSettings appSettings;
  final VoidCallback onOpenClassicEditor;

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  _KanbanFilter _filter = _KanbanFilter.all;
  var _includeTodos = true;
  var _warnedMultipleKanban = false;
  TaskRef? _openTask;
  var _detailsFullScreen = false;
  final _integrationSync = KanbanIntegrationSyncController();
  late final KanbanPersistenceController _persistence;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _persistence = KanbanPersistenceController(widget.session);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  Future<void> _syncYouTrack({required String youtrackSourceId}) {
    return _integrationSync.run('youtrack', () async {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.kanbanYoutrackSyncingPull),
          ),
        );
        final pull = await const YouTrackSyncService().pullIssuesIntoPage(
          session: widget.session,
          pageId: widget.pageId,
          youtrackSourceId: youtrackSourceId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.kanbanYoutrackPullOkPush),
          ),
        );
        final push = await const YouTrackSyncService().pushLinkedTasksFromPage(
          session: widget.session,
          pageId: widget.pageId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.kanbanYoutrackSyncResult(
                pull.pulled,
                pull.created,
                pull.updated,
                push.pushed,
                push.skipped,
              ),
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error YouTrack: $e')),
        );
      }
    }, onStateChanged: () { if (mounted) setState(() {}); });
  }

  Future<void> _syncTrello({required String trelloSourceId}) {
    return _integrationSync.run('trello', () async {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        // Push primero: subir cambios locales (p. ej. subtareas) antes de que el
        // pull pueda sobrescribirlos o marcar conflicto.
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.kanbanTrelloSyncingPush)),
        );
        final push = await const TrelloSyncService().pushLinkedTasksFromPage(
          session: widget.session,
          pageId: widget.pageId,
        );
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.kanbanTrelloPushOkPull)),
        );
        final pull = await const TrelloSyncService().pullCardsIntoPage(
          session: widget.session,
          pageId: widget.pageId,
          trelloSourceId: trelloSourceId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.kanbanTrelloSyncResult(
                push.pushed,
                push.skipped,
                pull.pulled,
                pull.created,
                pull.updated,
              ),
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.kanbanTrelloError('$e')),
          ),
        );
      }
    }, onStateChanged: () { if (mounted) setState(() {}); });
  }

  Future<void> _syncJira({required String jiraSourceId}) {
    return _integrationSync.run('jira', () async {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.kanbanJiraSyncingPull),
          ),
        );
        final pull = await const JiraSyncService().pullIssuesIntoPage(
          session: widget.session,
          pageId: widget.pageId,
          jiraSourceId: jiraSourceId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.kanbanJiraPullOkPush),
          ),
        );
        final push = await const JiraSyncService().pushLinkedTasksFromPage(
          session: widget.session,
          pageId: widget.pageId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.kanbanJiraSyncResult(
                pull.pulled,
                pull.created,
                pull.updated,
                push.pushed,
                push.skipped,
              ),
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(folioFormatJiraError(e, l10n))),
        );
      }
    }, onStateChanged: () { if (mounted) setState(() {}); });
  }

  Future<void> _syncGitHub({required String githubSourceId}) {
    return _integrationSync.run('github', () async {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        // Push primero: subir cambios locales antes de que el pull pueda
        // sobrescribirlos o marcar conflicto.
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.kanbanGithubSyncingPush),
          ),
        );
        final push = await const GitHubSyncService().pushLinkedTasksFromPage(
          session: widget.session,
          pageId: widget.pageId,
        );
        final pull = await const GitHubSyncService().pullIssuesIntoPage(
          session: widget.session,
          pageId: widget.pageId,
          githubSourceId: githubSourceId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.kanbanGithubSyncResult(
                pull.pulled,
                pull.created,
                pull.updated,
                push.pushed,
                push.skipped,
              ),
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error GitHub: $e')),
        );
      }
    }, onStateChanged: () { if (mounted) setState(() {}); });
  }

  Future<void> _syncGitLab({required String gitlabSourceId}) {
    return _integrationSync.run('gitlab', () async {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        // Push primero: subir cambios locales antes de que el pull pueda
        // sobrescribirlos o marcar conflicto.
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.kanbanGitlabSyncingPush),
          ),
        );
        final push = await const GitLabSyncService().pushLinkedTasksFromPage(
          session: widget.session,
          pageId: widget.pageId,
        );
        final pull = await const GitLabSyncService().pullIssuesIntoPage(
          session: widget.session,
          pageId: widget.pageId,
          gitlabSourceId: gitlabSourceId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.kanbanGitlabSyncResult(
                pull.pulled,
                pull.created,
                pull.updated,
                push.pushed,
                push.skipped,
              ),
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error GitLab: $e')),
        );
      }
    }, onStateChanged: () { if (mounted) setState(() {}); });
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime? _parseIsoDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso.trim());
  }

  bool _matchesFilter(VaultTaskListEntry e) {
    final today = _today();
    switch (_filter) {
      case _KanbanFilter.all:
        return true;
      case _KanbanFilter.active:
        return !e.isDone;
      case _KanbanFilter.done:
        return e.isDone;
      case _KanbanFilter.dueToday:
        if (e.blockType != 'task') return false;
        final due = _parseIsoDate(e.dueDate);
        return due != null && due == today;
      case _KanbanFilter.dueWeek:
        if (e.blockType != 'task') return false;
        final due = _parseIsoDate(e.dueDate);
        if (due == null) return false;
        final end = today.add(const Duration(days: 7));
        return !due.isBefore(today) && !due.isAfter(end);
      case _KanbanFilter.overdue:
        if (e.blockType != 'task') return false;
        if (e.isDone) return false;
        final due = _parseIsoDate(e.dueDate);
        return due != null && due.isBefore(today);
    }
  }

  FolioPage? _resolvePage() {
    try {
      return widget.session.pages.firstWhere((p) => p.id == widget.pageId);
    } catch (_) {
      return null;
    }
  }

  _KanbanBlockConfig _kanbanConfigFor(FolioPage page) {
    FolioBlock? first;
    var count = 0;
    for (final b in page.blocks) {
      if (b.type == 'kanban') {
        count++;
        first ??= b;
      }
    }
    if (count > 1 && !_warnedMultipleKanban && mounted) {
      _warnedMultipleKanban = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.kanbanMultipleBlocksSnack)));
      });
    }
    return _KanbanBlockConfig(
      blockId: first?.id ?? '',
      data:
          FolioKanbanData.tryParse(first?.text ?? '') ??
          FolioKanbanData.defaults(),
    );
  }

  String _columnTitle(AppLocalizations l10n, FolioKanbanColumnSpec spec) {
    final t = spec.title.trim();
    if (t.isNotEmpty) return t;
    return switch (spec.id) {
      'in_progress' => l10n.taskStatusInProgress,
      'done' => l10n.taskStatusDone,
      _ => l10n.taskStatusTodo,
    };
  }

  Color _columnColor(ColorScheme scheme, FolioKanbanColumnSpec spec) {
    final argb = spec.colorArgb;
    if (argb == null) return scheme.primary;
    return Color(argb);
  }

  Future<void> _quickAdd() async {
    final page = _resolvePage();
    if (page == null) return;
    final cfg = _kanbanConfigFor(page);
    final col = cfg.data.columns.isEmpty ? 'todo' : cfg.data.columns.first.id;
    final ref = createTaskDraft(
      session: widget.session,
      pageId: page.id,
      columnId: col,
      afterBlockId: cfg.blockId,
    );
    if (ref == null || !mounted) return;
    await _openTaskDetails(
      VaultTaskListEntry(
        pageId: ref.pageId,
        pageTitle: page.title,
        blockId: ref.blockId,
        blockType: 'task',
        task: null,
      ),
    );
  }

  Future<void> _quickAddForGroup(
    String columnId, {
    String? youtrackProjectId,
    String? youtrackProjectShortName,
  }) async {
    final page = _resolvePage();
    if (page == null) return;
    final cfg = _kanbanConfigFor(page);
    final ref = createTaskDraft(
      session: widget.session,
      pageId: page.id,
      columnId: columnId,
      afterBlockId: cfg.blockId,
    );
    if (ref == null || !mounted) return;
    await _openTaskDetails(
      VaultTaskListEntry(
        pageId: ref.pageId,
        pageTitle: page.title,
        blockId: ref.blockId,
        blockType: 'task',
        task: null,
      ),
    );
  }

  Future<void> _openTaskDetails(VaultTaskListEntry e) async {
    if (e.blockType != 'task') return;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < FolioDesktop.compactBreakpoint;
    if (compact) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FolioSpace.md),
            child: TaskDetailsSheet(
              session: widget.session,
              taskRef: TaskRef(pageId: e.pageId, blockId: e.blockId),
              onClose: () => Navigator.of(sheetContext).pop(),
              onOpenTaskRef: (ref) {
                Navigator.of(sheetContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _openTaskDetails(
                    VaultTaskListEntry(
                      pageId: ref.pageId,
                      pageTitle: '',
                      blockId: ref.blockId,
                      blockType: 'task',
                      task: null,
                    ),
                  );
                });
              },
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _openTask = TaskRef(pageId: e.pageId, blockId: e.blockId);
      _detailsFullScreen = false;
    });
  }

  Future<void> _renameColumn({
    required String pageId,
    required String kanbanBlockId,
    required FolioKanbanData data,
    required int index,
  }) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: data.columns[index].title);
    final nextTitle = await showDialog<String?>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.title),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.title,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop<String?>(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop<String?>(ctrl.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted) return;
    if (nextTitle == null) return;
    final cols = List<FolioKanbanColumnSpec>.from(data.columns);
    cols[index] = FolioKanbanColumnSpec(
      id: cols[index].id,
      title: nextTitle.trim(),
      colorArgb: cols[index].colorArgb,
    );
    _persistence.persist(pageId, kanbanBlockId, data.copyWith(columns: cols));
  }

  Future<void> _pickColumnColor({
    required String pageId,
    required String kanbanBlockId,
    required FolioKanbanData data,
    required int index,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final palette = <int>[
      0xFF90A4AE,
      0xFF42A5F5,
      0xFFAB47BC,
      0xFF26A69A,
      0xFFEF5350,
      0xFFFF7043,
      0xFFFFCA28,
      0xFF66BB6A,
    ];
    final selected = await showDialog<int?>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(FolioSpace.lg),
        child: Padding(
          padding: const EdgeInsets.all(FolioSpace.md),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in palette)
                InkWell(
                  onTap: () => Navigator.of(ctx).pop<int?>(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (selected == null) return;
    final cols = List<FolioKanbanColumnSpec>.from(data.columns);
    cols[index] = FolioKanbanColumnSpec(
      id: cols[index].id,
      title: cols[index].title,
      colorArgb: selected,
    );
    _persistence.persist(pageId, kanbanBlockId, data.copyWith(columns: cols));
  }

  Future<void> _addColumn({
    required String pageId,
    required String kanbanBlockId,
    required FolioKanbanData data,
  }) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final title = await showDialog<String?>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.add),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.title,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop<String?>(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop<String?>(ctrl.text),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted) return;
    if (title == null) return;
    final id = 'col_${DateTime.now().microsecondsSinceEpoch}';
    final cols = List<FolioKanbanColumnSpec>.from(data.columns)
      ..add(FolioKanbanColumnSpec(id: id, title: title.trim()));
    _persistence.persist(pageId, kanbanBlockId, data.copyWith(columns: cols));
  }

  void _moveColumn({
    required String pageId,
    required String kanbanBlockId,
    required FolioKanbanData data,
    required int index,
    required int delta,
  }) {
    final next = index + delta;
    if (next < 0 || next >= data.columns.length) return;
    final cols = List<FolioKanbanColumnSpec>.from(data.columns);
    final tmp = cols[index];
    cols[index] = cols[next];
    cols[next] = tmp;
    _persistence.persist(pageId, kanbanBlockId, data.copyWith(columns: cols));
  }

  void _deleteColumn({
    required String pageId,
    required String kanbanBlockId,
    required FolioKanbanData data,
    required int index,
  }) {
    if (data.columns.length <= 1) return;
    final cols = List<FolioKanbanColumnSpec>.from(data.columns)
      ..removeAt(index);
    _persistence.persist(pageId, kanbanBlockId, data.copyWith(columns: cols));
  }

  Future<void> _openKanbanSettingsSheet({
    required FolioPage page,
    required _KanbanBlockConfig cfg,
  }) async {
    final l10n = AppLocalizations.of(context);
    // Legacy: si hay más de una integración, dejar solo una.
    final normalized = _persistence.normalizeExclusiveIntegration(cfg.data);
    if ((normalized.jiraSourceId ?? '') != (cfg.data.jiraSourceId ?? '') ||
        (normalized.youtrackSourceId ?? '') != (cfg.data.youtrackSourceId ?? '') ||
        (normalized.trelloSourceId ?? '') != (cfg.data.trelloSourceId ?? '') ||
        (normalized.githubSourceId ?? '') != (cfg.data.githubSourceId ?? '') ||
        (normalized.gitlabSourceId ?? '') != (cfg.data.gitlabSourceId ?? '')) {
      _persistence.persist(page.id, cfg.blockId, normalized);
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FolioSpace.md),
            child: Material(
              color: scheme.surface,
              elevation: 6,
              borderRadius: BorderRadius.circular(FolioRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FolioSpace.md,
                    FolioSpace.md,
                    FolioSpace.md,
                    FolioSpace.sm,
                  ),
                  child: AnimatedBuilder(
                    animation: widget.session,
                    builder: (context, _) {
                      // Releer config desde sesión por si ha cambiado.
                      final latestPage = _resolvePage() ?? page;
                      final latestCfg = _kanbanConfigFor(latestPage);
                      final data = latestCfg.data;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune_rounded),
                              const SizedBox(width: FolioSpace.sm),
                              Expanded(
                                child: Text(
                                  l10n.settings,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.cancel,
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: FolioSpace.sm),
                          Text(
                            'Vista',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SegmentedButton<FolioKanbanViewMode>(
                            segments: const [
                              ButtonSegment(
                                value: FolioKanbanViewMode.kanban,
                                icon: Icon(Icons.view_kanban_rounded),
                              ),
                              ButtonSegment(
                                value: FolioKanbanViewMode.list,
                                icon: Icon(Icons.view_list_rounded),
                              ),
                              ButtonSegment(
                                value: FolioKanbanViewMode.grid,
                                icon: Icon(Icons.grid_view_rounded),
                              ),
                              ButtonSegment(
                                value: FolioKanbanViewMode.timeline,
                                icon: Icon(Icons.timeline_rounded),
                              ),
                            ],
                            selected: {data.viewMode},
                            onSelectionChanged: (s) {
                              if (s.isEmpty) return;
                              _persistence.persist(
                                latestPage.id,
                                latestCfg.blockId,
                                data.copyWith(viewMode: s.first),
                              );
                            },
                          ),
                          const SizedBox(height: FolioSpace.md),
                          Builder(
                            builder: (ctx) {
                              final l10nSheet = AppLocalizations.of(ctx);
                              final hasJira =
                                  (data.jiraSourceId ?? '').trim().isNotEmpty;
                              final hasYt =
                                  (data.youtrackSourceId ?? '').trim().isNotEmpty;
                              final hasTr =
                                  (data.trelloSourceId ?? '').trim().isNotEmpty;
                              final hasGh =
                                  (data.githubSourceId ?? '').trim().isNotEmpty;
                              final hasGl =
                                  (data.gitlabSourceId ?? '').trim().isNotEmpty;
                              final activeProvider = hasJira
                                  ? 'jira'
                                  : hasYt
                                      ? 'youtrack'
                                      : hasTr
                                          ? 'trello'
                                          : hasGh
                                              ? 'github'
                                              : hasGl
                                                  ? 'gitlab'
                                                  : null;

                              String composite(String provider, String sourceId) =>
                                  '$provider:$sourceId';

                              final items = <DropdownMenuItem<String?>>[
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(l10nSheet.kanbanNone),
                                ),
                                for (final s in widget.session.jiraSources)
                                  DropdownMenuItem<String?>(
                                    value: composite('jira', s.id),
                                    child: Text('Jira · ${s.name}'),
                                  ),
                                for (final s in widget.session.youtrackSources)
                                  DropdownMenuItem<String?>(
                                    value: composite('youtrack', s.id),
                                    child: Text('YouTrack · ${s.name}'),
                                  ),
                                for (final s in widget.session.trelloSources)
                                  DropdownMenuItem<String?>(
                                    value: composite('trello', s.id),
                                    child: Text('Trello · ${s.name}'),
                                  ),
                                for (final s in widget.session.githubSources)
                                  DropdownMenuItem<String?>(
                                    value: composite('github', s.id),
                                    child: Text('GitHub · ${s.name}'),
                                  ),
                                for (final s in widget.session.gitlabSources)
                                  DropdownMenuItem<String?>(
                                    value: composite('gitlab', s.id),
                                    child: Text('GitLab · ${s.name}'),
                                  ),
                              ];

                              String? selectedValue = switch (activeProvider) {
                                'jira' => composite(
                                    'jira', data.jiraSourceId!.trim()),
                                'youtrack' => composite(
                                    'youtrack', data.youtrackSourceId!.trim()),
                                'trello' => composite(
                                    'trello', data.trelloSourceId!.trim()),
                                'github' => composite(
                                    'github', data.githubSourceId!.trim()),
                                'gitlab' => composite(
                                    'gitlab', data.gitlabSourceId!.trim()),
                                _ => null,
                              };
                              if (selectedValue != null &&
                                  !items.any((i) => i.value == selectedValue)) {
                                // La fuente seleccionada ya no existe (se borró
                                // en Ajustes → Integraciones).
                                selectedValue = null;
                              }

                              final autoImport = switch (activeProvider) {
                                'jira' => data.jiraAutoImport,
                                'youtrack' => data.youtrackAutoImport,
                                'trello' => data.trelloAutoImport,
                                'github' => data.githubAutoImport,
                                'gitlab' => data.gitlabAutoImport,
                                _ => false,
                              };
                              final createOnQuickAdd = switch (activeProvider) {
                                'jira' => data.jiraCreateIssuesOnQuickAdd,
                                'youtrack' => data.youtrackCreateIssuesOnQuickAdd,
                                'trello' => data.trelloCreateCardsOnQuickAdd,
                                'github' => data.githubCreateIssuesOnQuickAdd,
                                'gitlab' => data.gitlabCreateIssuesOnQuickAdd,
                                _ => false,
                              };
                              final providerLabel = switch (activeProvider) {
                                'jira' => 'Jira',
                                'youtrack' => 'YouTrack',
                                'trello' => 'Trello',
                                'github' => 'GitHub',
                                'gitlab' => 'GitLab',
                                _ => null,
                              };

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10nSheet.kanbanSourceLabel,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String?>(
                                    initialValue: selectedValue,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: l10nSheet.kanbanSourceLabel,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: items,
                                    onChanged: (v) {
                                      final String provider;
                                      final String? sourceId;
                                      if (v == null) {
                                        provider = activeProvider ?? '';
                                        sourceId = null;
                                      } else {
                                        final parts = v.split(':');
                                        provider = parts.first;
                                        sourceId = parts.sublist(1).join(':');
                                      }
                                      if (provider.isEmpty) return;
                                      _persistence.persist(
                                        latestPage.id,
                                        latestCfg.blockId,
                                        _persistence.selectIntegration(
                                          data: data,
                                          provider: provider,
                                          sourceId: sourceId,
                                        ),
                                      );
                                    },
                                  ),
                                  if (activeProvider != null &&
                                      providerLabel != null) ...[
                                    const SizedBox(height: 8),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        l10nSheet.kanbanAutoImportFrom(providerLabel),
                                      ),
                                      value: autoImport,
                                      onChanged: (v) {
                                        final next = switch (activeProvider) {
                                          'jira' =>
                                            data.copyWith(jiraAutoImport: v),
                                          'youtrack' => data.copyWith(
                                              youtrackAutoImport: v),
                                          'trello' =>
                                            data.copyWith(trelloAutoImport: v),
                                          'github' =>
                                            data.copyWith(githubAutoImport: v),
                                          _ => data,
                                        };
                                        _persistence.persist(
                                          latestPage.id,
                                          latestCfg.blockId,
                                          next,
                                        );
                                      },
                                    ),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        l10nSheet.kanbanCreateItemsOnQuickAdd,
                                      ),
                                      value: createOnQuickAdd,
                                      onChanged: (v) {
                                        final next = switch (activeProvider) {
                                          'jira' => data.copyWith(
                                              jiraCreateIssuesOnQuickAdd: v),
                                          'youtrack' => data.copyWith(
                                              youtrackCreateIssuesOnQuickAdd:
                                                  v),
                                          'trello' => data.copyWith(
                                              trelloCreateCardsOnQuickAdd: v),
                                          'github' => data.copyWith(
                                              githubCreateIssuesOnQuickAdd: v),
                                          _ => data,
                                        };
                                        _persistence.persist(
                                          latestPage.id,
                                          latestCfg.blockId,
                                          next,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: FolioSpace.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Columnas',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _addColumn(
                                  pageId: latestPage.id,
                                  kanbanBlockId: latestCfg.blockId,
                                  data: data,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(l10n.add),
                              ),
                            ],
                          ),
                          const SizedBox(height: FolioSpace.xs),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: data.columns.length,
                              separatorBuilder: (context, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final col = data.columns[i];
                                final title = _columnTitle(l10n, col);
                                final color = _columnColor(scheme, col);
                                return ListTile(
                                  leading: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  title: Text(title),
                                  subtitle: Text(col.id),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: l10n.settings,
                                        onPressed: () => _renameColumn(
                                          pageId: latestPage.id,
                                          kanbanBlockId: latestCfg.blockId,
                                          data: data,
                                          index: i,
                                        ),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l10n.settings,
                                        onPressed: () => _pickColumnColor(
                                          pageId: latestPage.id,
                                          kanbanBlockId: latestCfg.blockId,
                                          data: data,
                                          index: i,
                                        ),
                                        icon: const Icon(
                                          Icons.palette_outlined,
                                          size: 18,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _moveColumn(
                                          pageId: latestPage.id,
                                          kanbanBlockId: latestCfg.blockId,
                                          data: data,
                                          index: i,
                                          delta: -1,
                                        ),
                                        icon: const Icon(
                                          Icons.chevron_left_rounded,
                                          size: 18,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _moveColumn(
                                          pageId: latestPage.id,
                                          kanbanBlockId: latestCfg.blockId,
                                          data: data,
                                          index: i,
                                          delta: 1,
                                        ),
                                        icon: const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l10n.delete,
                                        onPressed: () => _deleteColumn(
                                          pageId: latestPage.id,
                                          kanbanBlockId: latestCfg.blockId,
                                          data: data,
                                          index: i,
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: FolioSpace.sm),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final page = _resolvePage();
    if (page == null) {
      return Center(child: Text(l10n.taskHubEmpty));
    }

    final cfg = _kanbanConfigFor(page);
    final data = cfg.data;
    if (_includeTodos != data.includeSimpleTodos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _includeTodos = data.includeSimpleTodos);
      });
    }

    final all = widget.session.collectTaskBlocks(
      includeSimpleTodos: data.includeSimpleTodos && _includeTodos,
      pageId: widget.pageId,
    );
    final visible = all
        .where(_matchesFilter)
        // No mostrar subtareas en el tablero (se ven dentro del detalle).
        .where((e) => e.blockType != 'task' || e.task?.parentTaskId == null)
        .toList();

    final byColumn = <String, List<VaultTaskListEntry>>{
      for (final c in data.columns) c.id: [],
    };
    final allowed = byColumn.keys.toSet();
    for (final e in visible) {
      var key = e.kanbanColumnKey;
      if (!allowed.contains(key)) {
        key = data.columns.isEmpty ? 'todo' : data.columns.first.id;
      }
      byColumn[key]?.add(e);
    }

    final mode = data.viewMode;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.kanbanToolbarOpenEditor,
              onPressed: widget.onOpenClassicEditor,
              icon: const Icon(Icons.edit_note_rounded),
            ),
            const SizedBox(width: FolioSpace.xs),
            if ((data.jiraSourceId ?? '').trim().isNotEmpty)
              IconButton(
                tooltip: l10n.kanbanSyncJiraTooltip,
                onPressed: _integrationSync.isBusy('jira')
                    ? null
                    : () => _syncJira(jiraSourceId: data.jiraSourceId!.trim()),
                icon: _integrationSync.isBusy('jira')
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.sync_rounded),
              ),
            if ((data.jiraSourceId ?? '').trim().isNotEmpty)
              const SizedBox(width: FolioSpace.xs),
            if ((data.youtrackSourceId ?? '').trim().isNotEmpty)
              IconButton(
                tooltip: l10n.kanbanSyncYoutrackTooltip,
                onPressed: _integrationSync.isBusy('youtrack')
                    ? null
                    : () => _syncYouTrack(youtrackSourceId: data.youtrackSourceId!.trim()),
                icon: _integrationSync.isBusy('youtrack')
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.sync_rounded, color: Colors.orange),
              ),
            if ((data.youtrackSourceId ?? '').trim().isNotEmpty)
              const SizedBox(width: FolioSpace.xs),
            if ((data.trelloSourceId ?? '').trim().isNotEmpty)
              IconButton(
                tooltip: l10n.kanbanTrelloSyncTooltip,
                onPressed: _integrationSync.isBusy('trello')
                    ? null
                    : () => _syncTrello(trelloSourceId: data.trelloSourceId!.trim()),
                icon: _integrationSync.isBusy('trello')
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const SizedBox(
                        width: 22,
                        height: 22,
                        child: Image(
                          image: AssetImage('appLogos/trello.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            if ((data.trelloSourceId ?? '').trim().isNotEmpty)
              const SizedBox(width: FolioSpace.xs),
            if ((data.githubSourceId ?? '').trim().isNotEmpty)
              IconButton(
                tooltip: l10n.kanbanSyncGithubTooltip,
                onPressed: _integrationSync.isBusy('github')
                    ? null
                    : () => _syncGitHub(githubSourceId: data.githubSourceId!.trim()),
                icon: _integrationSync.isBusy('github')
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const SizedBox(
                        width: 22,
                        height: 22,
                        child: Image(
                          image: AssetImage('appLogos/github.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            if ((data.githubSourceId ?? '').trim().isNotEmpty)
              const SizedBox(width: FolioSpace.xs),
            if ((data.gitlabSourceId ?? '').trim().isNotEmpty)
              IconButton(
                tooltip: l10n.kanbanSyncGitlabTooltip,
                onPressed: _integrationSync.isBusy('gitlab')
                    ? null
                    : () => _syncGitLab(gitlabSourceId: data.gitlabSourceId!.trim()),
                icon: _integrationSync.isBusy('gitlab')
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const SizedBox(
                        width: 22,
                        height: 22,
                        child: Image(
                          image: AssetImage('appLogos/gitlab.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            if ((data.gitlabSourceId ?? '').trim().isNotEmpty)
              const SizedBox(width: FolioSpace.xs),
            IconButton(
              tooltip: l10n.settings,
              onPressed: () => _openKanbanSettingsSheet(page: page, cfg: cfg),
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: FolioSpace.xs),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _quickAdd,
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: Text(l10n.kanbanToolbarAddTask),
              ),
            ),
          ],
        ),
        const SizedBox(height: FolioSpace.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.taskHubFilterAll),
              selected: _filter == _KanbanFilter.all,
              onSelected: (_) => setState(() => _filter = _KanbanFilter.all),
            ),
            ChoiceChip(
              label: Text(l10n.taskHubFilterActive),
              selected: _filter == _KanbanFilter.active,
              onSelected: (_) => setState(() => _filter = _KanbanFilter.active),
            ),
            ChoiceChip(
              label: Text(l10n.taskHubFilterDone),
              selected: _filter == _KanbanFilter.done,
              onSelected: (_) => setState(() => _filter = _KanbanFilter.done),
            ),
            ChoiceChip(
              label: Text(l10n.taskHubFilterDueToday),
              selected: _filter == _KanbanFilter.dueToday,
              onSelected: (_) =>
                  setState(() => _filter = _KanbanFilter.dueToday),
            ),
            ChoiceChip(
              label: Text(l10n.taskHubFilterDueWeek),
              selected: _filter == _KanbanFilter.dueWeek,
              onSelected: (_) =>
                  setState(() => _filter = _KanbanFilter.dueWeek),
            ),
            ChoiceChip(
              label: Text(l10n.taskHubFilterOverdue),
              selected: _filter == _KanbanFilter.overdue,
              onSelected: (_) =>
                  setState(() => _filter = _KanbanFilter.overdue),
            ),
            if (data.includeSimpleTodos)
              FilterChip(
                label: Text(l10n.taskHubIncludeTodos),
                selected: _includeTodos,
                onSelected: (v) => setState(() => _includeTodos = v),
              ),
          ],
        ),
        const SizedBox(height: FolioSpace.md),
        Expanded(
          child: switch (mode) {
            FolioKanbanViewMode.kanban => _KanbanViewKanban(
              data: data,
              byColumn: byColumn,
              columnTitle: (c) => _columnTitle(l10n, c),
              columnColor: (c) => _columnColor(scheme, c),
              scheme: scheme,
              textTheme: textTheme,
              l10n: l10n,
              onMoveTaskToColumn: (e, columnId) {
                widget.session.setTaskBlockColumnId(
                  e.pageId,
                  e.blockId,
                  columnId,
                );
              },
              onOpenBlock: (e) {
                widget.session.selectPage(e.pageId);
                widget.session.requestScrollToBlock(e.blockId);
              },
              onOpenDetails: _openTaskDetails,
              onAddTask: _quickAddForGroup,
            ),
            FolioKanbanViewMode.list => _KanbanViewList(
              data: data,
              byColumn: byColumn,
              columnTitle: (c) => _columnTitle(l10n, c),
              l10n: l10n,
              scheme: scheme,
              textTheme: textTheme,
              onOpenDetails: _openTaskDetails,
            ),
            FolioKanbanViewMode.grid => _KanbanViewGrid(
              data: data,
              entries: visible,
              allowedColumnIds: allowed,
              columnTitleById: (id) {
                for (final c in data.columns) {
                  if (c.id == id) return _columnTitle(l10n, c);
                }
                return id;
              },
              l10n: l10n,
              scheme: scheme,
              textTheme: textTheme,
              onOpenDetails: _openTaskDetails,
            ),
            FolioKanbanViewMode.timeline => _KanbanViewTimeline(
              entries: visible,
              l10n: l10n,
              scheme: scheme,
              textTheme: textTheme,
              onOpenDetails: _openTaskDetails,
            ),
          },
        ),
      ],
    );

    final open = _openTask;
    if (open == null) return main;

    return Stack(
      children: [
        main,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() {
              _openTask = null;
              _detailsFullScreen = false;
            }),
            child: const SizedBox.shrink(),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          left: _detailsFullScreen ? 0 : null,
          child: Padding(
            padding: EdgeInsets.only(left: _detailsFullScreen ? 0 : FolioSpace.md),
            child: ConstrainedBox(
              constraints: _detailsFullScreen
                  ? const BoxConstraints.expand()
                  : const BoxConstraints.tightFor(width: 420),
              child: TaskDetailsPanel(
                session: widget.session,
                taskRef: open,
                onClose: () => setState(() {
                  _openTask = null;
                  _detailsFullScreen = false;
                }),
                onOpenTaskRef: (ref) => setState(() => _openTask = ref),
                isFullScreen: _detailsFullScreen,
                onToggleFullScreen: () => setState(() => _detailsFullScreen = !_detailsFullScreen),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KanbanBlockConfig {
  const _KanbanBlockConfig({required this.blockId, required this.data});
  final String blockId;
  final FolioKanbanData data;
}


class _KanbanViewKanban extends StatelessWidget {
  const _KanbanViewKanban({
    required this.data,
    required this.byColumn,
    required this.columnTitle,
    required this.columnColor,
    required this.scheme,
    required this.textTheme,
    required this.l10n,
    required this.onMoveTaskToColumn,
    required this.onOpenBlock,
    required this.onOpenDetails,
    required this.onAddTask,
  });

  final FolioKanbanData data;
  final Map<String, List<VaultTaskListEntry>> byColumn;
  final String Function(FolioKanbanColumnSpec spec) columnTitle;
  final Color Function(FolioKanbanColumnSpec spec) columnColor;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;
  final void Function(VaultTaskListEntry e, String columnId) onMoveTaskToColumn;
  final void Function(VaultTaskListEntry e) onOpenBlock;
  final void Function(VaultTaskListEntry e) onOpenDetails;
  final void Function(String columnId, {String? youtrackProjectId, String? youtrackProjectShortName}) onAddTask;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = data.columns.length;
        final gaps =
            FolioSpace.md * math.max(0, columnCount - 1);
        final columnWidth = math.max(
          260.0,
          columnCount == 0
              ? constraints.maxWidth
              : (constraints.maxWidth - gaps) / columnCount,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < data.columns.length; i++) ...[
                    if (i > 0) const SizedBox(width: FolioSpace.md),
                    SizedBox(
                      width: columnWidth,
                      child: _KanbanColumn(
                        title: columnTitle(data.columns[i]),
                        color: columnColor(data.columns[i]),
                        entries: byColumn[data.columns[i].id] ?? const [],
                        columnId: data.columns[i].id,
                        allColumnIds: data.columns.map((c) => c.id).toList(),
                        scheme: scheme,
                        textTheme: textTheme,
                        l10n: l10n,
                        onMoveTaskToColumn: onMoveTaskToColumn,
                        onOpenBlock: onOpenBlock,
                        onOpenDetails: onOpenDetails,
                        columnTitleForId: (id) {
                          for (final c in data.columns) {
                            if (c.id == id) return columnTitle(c);
                          }
                          return id;
                        },
                        onAddTask: onAddTask,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    required this.title,
    required this.color,
    required this.entries,
    required this.columnId,
    required this.allColumnIds,
    required this.scheme,
    required this.textTheme,
    required this.l10n,
    required this.onMoveTaskToColumn,
    required this.onOpenBlock,
    required this.onOpenDetails,
    required this.columnTitleForId,
    required this.onAddTask,
  });

  final String title;
  final Color color;
  final List<VaultTaskListEntry> entries;
  final String columnId;
  final List<String> allColumnIds;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;
  final void Function(VaultTaskListEntry e, String columnId) onMoveTaskToColumn;
  final void Function(VaultTaskListEntry e) onOpenBlock;
  final void Function(VaultTaskListEntry e) onOpenDetails;
  final String Function(String id) columnTitleForId;
  final void Function(String columnId, {String? youtrackProjectId, String? youtrackProjectShortName}) onAddTask;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  final Map<String, bool> _collapsedGroups = {};

  Widget _buildTile(VaultTaskListEntry e) {
    final scheme = widget.scheme;
    final textTheme = widget.textTheme;
    final l10n = widget.l10n;
    final columnId = widget.columnId;
    final allColumnIds = widget.allColumnIds;
    final onOpenDetails = widget.onOpenDetails;
    final onOpenBlock = widget.onOpenBlock;
    final onMoveTaskToColumn = widget.onMoveTaskToColumn;
    final columnTitleForId = widget.columnTitleForId;

    final subtitle = StringBuffer();
    if (e.blockType == 'task') {
      if (e.dueDate != null) {
        subtitle.write(folioFmtTaskDue(e.dueDate!));
      }
      if (e.priority != null) {
        if (subtitle.isNotEmpty) subtitle.write(' · ');
        subtitle.write(e.priority);
      }
    }
    final ext = e.task?.external;
    final jiraState = (ext?.provider == 'jira')
        ? ((ext?.syncState ?? 'ok').trim().isEmpty
              ? 'ok'
              : (ext!.syncState ?? 'ok').trim())
        : null;
    final youtrackState = (ext?.provider == 'youtrack')
        ? ((ext?.syncState ?? 'ok').trim().isEmpty
              ? 'ok'
              : (ext!.syncState ?? 'ok').trim())
        : null;
    final trelloState = (ext?.provider == 'trello')
        ? ((ext?.syncState ?? 'ok').trim().isEmpty
              ? 'ok'
              : (ext!.syncState ?? 'ok').trim())
        : null;

    Widget? trelloBadge() {
      if (trelloState == null) return null;
      if (trelloState == 'ok') return null;
      Color c() => switch (trelloState) {
        'conflict' => scheme.error,
        'needsPush' => scheme.tertiary,
        'needsPull' => scheme.secondary,
        _ => scheme.primary,
      };
      String label() => switch (trelloState) {
        'conflict' => l10n.kanbanConflict,
        'needsPush' => l10n.kanbanNeedsPush,
        'needsPull' => l10n.kanbanNeedsPull,
        _ => 'Trello',
      };
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: c().withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: c().withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: Image(
                image: AssetImage('appLogos/trello.png'),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label(),
              style: textTheme.labelSmall?.copyWith(
                color: c(),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    Widget? youtrackBadge() {
      if (youtrackState == null) return null;
      if (youtrackState == 'ok') return null;
      Color c() => switch (youtrackState) {
        'conflict' => scheme.error,
        'needsPush' => scheme.tertiary,
        'needsPull' => scheme.secondary,
        _ => scheme.primary,
      };
      String label() => switch (youtrackState) {
        'conflict' => l10n.kanbanConflict,
        'needsPush' => l10n.kanbanNeedsPush,
        'needsPull' => l10n.kanbanNeedsPull,
        _ => 'YouTrack',
      };
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: c().withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: c().withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: Icon(Icons.grid_view_rounded, size: 12, color: Colors.orange),
            ),
            const SizedBox(width: 6),
            Text(
              label(),
              style: textTheme.labelSmall?.copyWith(
                color: c(),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    Widget? jiraBadge() {
      if (jiraState == null) return null;
      if (jiraState == 'ok') return null;
      Color c() => switch (jiraState) {
        'conflict' => scheme.error,
        'needsPush' => scheme.tertiary,
        'needsPull' => scheme.secondary,
        _ => scheme.primary,
      };
      String label() => switch (jiraState) {
        'conflict' => l10n.kanbanConflict,
        'needsPush' => l10n.kanbanNeedsPush,
        'needsPull' => l10n.kanbanNeedsPull,
        _ => 'Jira',
      };
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: c().withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: c().withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: Image.asset('appLogos/jira.png'),
            ),
            const SizedBox(width: 6),
            Text(
              label(),
              style: textTheme.labelSmall?.copyWith(
                color: c(),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final tile = Card(
      elevation: 0,
      color: scheme.surface.withValues(alpha: 0.9),
      child: ListTile(
        dense: true,
        onTap: () => onOpenDetails(e),
        title: Text(
          e.displayTitle.isEmpty ? '—' : e.displayTitle,
          style: _kanbanTaskTitleStyle(
            textTheme: textTheme,
            scheme: scheme,
            e: e,
          ),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
                subtitle.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (jiraBadge() != null) ...[
              jiraBadge()!,
              const SizedBox(width: 8),
            ],
            if (youtrackBadge() != null) ...[
              youtrackBadge()!,
              const SizedBox(width: 8),
            ],
            if (trelloBadge() != null) ...[
              trelloBadge()!,
              const SizedBox(width: 8),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) {
                if (value == '__open') {
                  onOpenBlock(e);
                } else {
                  onMoveTaskToColumn(e, value);
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                for (final id in allColumnIds) {
                  if (id == columnId) continue;
                  items.add(
                    PopupMenuItem(
                      value: id,
                      child: Text(columnTitleForId(id)),
                    ),
                  );
                }
                if (items.isNotEmpty) {
                  items.add(const PopupMenuDivider());
                }
                items.add(
                  PopupMenuItem(
                    value: '__open',
                    child: Text(l10n.taskHubOpen),
                  ),
                );
                return items;
              },
            ),
          ],
        ),
      ),
    );

    if (e.blockType != 'task') return tile;
    if (e.isBlocked) return tile;
    return Draggable<VaultTaskListEntry>(
      data: e,
      feedback: SizedBox(
        width: 260,
        child: Material(
          color: Colors.transparent,
          child: Opacity(opacity: 0.9, child: tile),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: tile,
      ),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Group the entries by subsystem
    final grouped = <String, List<VaultTaskListEntry>>{};
    final groupProjectIds = <String, String>{};
    final groupProjectShortNames = <String, String>{};

    for (final e in widget.entries) {
      final ext = e.task?.external;
      String groupKey = '';
      if (ext != null && ext.provider == 'youtrack') {
        groupKey = e.task?.youtrack?.subsystem ?? '';
        final pid = e.task?.youtrack?.projectId;
        final psn = e.task?.youtrack?.projectShortName;
        if (groupKey.isNotEmpty) {
          if (pid != null) groupProjectIds[groupKey] = pid;
          if (psn != null) groupProjectShortNames[groupKey] = psn;
        }
      }
      grouped.putIfAbsent(groupKey, () => []).add(e);
    }

    final youtrackGroups = grouped.keys.where((k) => k.isNotEmpty).toList();
    final shouldGroup = youtrackGroups.isNotEmpty;

    final Widget listContent;
    if (!shouldGroup) {
      listContent = widget.entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.l10n.kanbanEmptyColumn,
                  style: widget.textTheme.bodyMedium?.copyWith(
                    color: widget.scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: widget.entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _buildTile(widget.entries[i]),
            );
    } else {
      final sortedKeys = grouped.keys.toList();
      sortedKeys.sort((a, b) {
        if (a.isEmpty) return -1;
        if (b.isEmpty) return 1;
        return a.compareTo(b);
      });

      final items = <Widget>[];

      for (final key in sortedKeys) {
        final groupEntries = grouped[key] ?? [];
        final displayName = key.isEmpty
            ? widget.l10n.kanbanUncategorizedCards
            : key;

        final isCollapsed = _collapsedGroups[key] ?? false;

        items.add(
          InkWell(
            onTap: () {
              setState(() {
                _collapsedGroups[key] = !isCollapsed;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: widget.scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      displayName,
                      style: widget.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (groupEntries.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${groupEntries.length}',
                        style: widget.textTheme.labelSmall?.copyWith(
                          color: widget.scheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        if (!isCollapsed) {
          for (final e in groupEntries) {
            items.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _buildTile(e),
              ),
            );
          }

          items.add(
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                child: IconButton(
                  onPressed: () {
                    final pid = groupProjectIds[key];
                    final psn = groupProjectShortNames[key];
                    widget.onAddTask(
                      widget.columnId,
                      youtrackProjectId: pid,
                      youtrackProjectShortName: psn,
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  style: IconButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ),
            ),
          );
        }

        if (key != sortedKeys.last) {
          items.add(const Divider(height: 16));
        }
      }

      listContent = ListView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: items,
      );
    }

    return DragTarget<VaultTaskListEntry>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) => widget.onMoveTaskToColumn(d.data, widget.columnId),
      builder: (context, candidates, rejected) {
        return Container(
          decoration: BoxDecoration(
            color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(FolioRadius.md),
            border: Border.all(
              color: widget.scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: widget.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: listContent,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanViewList extends StatelessWidget {
  const _KanbanViewList({
    required this.data,
    required this.byColumn,
    required this.columnTitle,
    required this.l10n,
    required this.scheme,
    required this.textTheme,
    required this.onOpenDetails,
  });

  final FolioKanbanData data;
  final Map<String, List<VaultTaskListEntry>> byColumn;
  final String Function(FolioKanbanColumnSpec spec) columnTitle;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final void Function(VaultTaskListEntry e) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final c in data.columns) {
      final entries = byColumn[c.id] ?? const [];
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Text(
            columnTitle(c),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      if (entries.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.kanbanEmptyColumn,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      } else {
        for (final e in entries) {
          children.add(
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
              child: ListTile(
                title: Text(
                  e.displayTitle.isEmpty ? '—' : e.displayTitle,
                  style: _kanbanTaskTitleStyle(
                    textTheme: textTheme,
                    scheme: scheme,
                    e: e,
                  ),
                ),
                subtitle: e.dueDate == null ? null : Text(folioFmtTaskDue(e.dueDate!)),
                onTap: () => onOpenDetails(e),
              ),
            ),
          );
        }
        children.add(const SizedBox(height: 10));
      }
    }
    return ListView(children: children);
  }
}

class _KanbanViewGrid extends StatelessWidget {
  const _KanbanViewGrid({
    required this.data,
    required this.entries,
    required this.allowedColumnIds,
    required this.columnTitleById,
    required this.l10n,
    required this.scheme,
    required this.textTheme,
    required this.onOpenDetails,
  });

  final FolioKanbanData data;
  final List<VaultTaskListEntry> entries;
  final Set<String> allowedColumnIds;
  final String Function(String id) columnTitleById;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final void Function(VaultTaskListEntry e) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.taskHubEmpty,
          style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 760 ? 3 : 2);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            final col = allowedColumnIds.contains(e.kanbanColumnKey)
                ? e.kanbanColumnKey
                : (data.columns.isEmpty ? 'todo' : data.columns.first.id);
            return Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
              child: InkWell(
                onTap: () => onOpenDetails(e),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.displayTitle.isEmpty ? '—' : e.displayTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _kanbanTaskTitleStyle(
                          textTheme: textTheme,
                          scheme: scheme,
                          e: e,
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(columnTitleById(col)),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (e.dueDate != null)
                            Chip(
                              label: Text(folioFmtTaskDue(e.dueDate!)),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _KanbanViewTimeline extends StatelessWidget {
  const _KanbanViewTimeline({
    required this.entries,
    required this.l10n,
    required this.scheme,
    required this.textTheme,
    required this.onOpenDetails,
  });

  final List<VaultTaskListEntry> entries;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final void Function(VaultTaskListEntry e) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final items = entries.where((e) => e.blockType == 'task').toList()
      ..sort((a, b) {
        final as = _tryParseIso(a.startDate) ?? DateTime(2100);
        final bs = _tryParseIso(b.startDate) ?? DateTime(2100);
        return as.compareTo(bs);
      });
    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.taskHubEmpty,
          style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = items[i];
        final range = (e.startDate == null && e.dueDate == null)
            ? l10n.none
            : '${e.startDate ?? '—'} → ${e.dueDate != null ? folioFmtTaskDue(e.dueDate!) : '—'}';
        return Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          child: ListTile(
            title: Text(
              e.displayTitle.isEmpty ? '—' : e.displayTitle,
              style: _kanbanTaskTitleStyle(
                textTheme: textTheme,
                scheme: scheme,
                e: e,
              ),
            ),
            subtitle: Text(range),
            onTap: () => onOpenDetails(e),
          ),
        );
      },
    );
  }

  DateTime? _tryParseIso(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso.trim());
  }
}
