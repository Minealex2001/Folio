import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_kanban_data.dart';
import '../../../models/folio_task_data.dart';
import '../../../models/folio_page.dart';
import '../../../models/vault_task_list_entry.dart';
import '../../../session/vault_session.dart';
import '../tasks/task_quick_add_dialog.dart';

enum _KanbanFilter { all, active, done, dueToday, dueWeek, overdue }

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
  _TaskRef? _openTask;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
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
    try {
      final p = iso.trim().split('-');
      if (p.length != 3) return null;
      final y = int.parse(p[0]);
      final m = int.parse(p[1]);
      final d = int.parse(p[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.kanbanMultipleBlocksSnack)),
        );
      });
    }
    return _KanbanBlockConfig(
      blockId: first?.id ?? '',
      data: FolioKanbanData.tryParse(first?.text ?? '') ?? FolioKanbanData.defaults(),
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
    await showTaskQuickAddDialog(
      context: context,
      session: widget.session,
      appSettings: widget.appSettings,
      targetPageId: widget.pageId,
    );
    if (mounted) setState(() {});
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
            child: _TaskDetailsSheet(
              session: widget.session,
              taskRef: _TaskRef(pageId: e.pageId, blockId: e.blockId),
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
    setState(() => _openTask = _TaskRef(pageId: e.pageId, blockId: e.blockId));
  }

  void _persistKanbanData(String pageId, String blockId, FolioKanbanData data) {
    if (blockId.trim().isEmpty) return;
    widget.session.updateBlockText(pageId, blockId, data.encode());
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
    _persistKanbanData(pageId, kanbanBlockId, data.copyWith(columns: cols));
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
    _persistKanbanData(pageId, kanbanBlockId, data.copyWith(columns: cols));
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
    _persistKanbanData(pageId, kanbanBlockId, data.copyWith(columns: cols));
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
    _persistKanbanData(pageId, kanbanBlockId, data.copyWith(columns: cols));
  }

  void _deleteColumn({
    required String pageId,
    required String kanbanBlockId,
    required FolioKanbanData data,
    required int index,
  }) {
    if (data.columns.length <= 1) return;
    final cols = List<FolioKanbanColumnSpec>.from(data.columns)..removeAt(index);
    _persistKanbanData(pageId, kanbanBlockId, data.copyWith(columns: cols));
  }

  Future<void> _openKanbanSettingsSheet({
    required FolioPage page,
    required _KanbanBlockConfig cfg,
  }) async {
    final l10n = AppLocalizations.of(context);
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
                                onPressed: () => Navigator.of(sheetContext).pop(),
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
                              _persistKanbanData(
                                latestPage.id,
                                latestCfg.blockId,
                                data.copyWith(viewMode: s.first),
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
              onSelected: (_) => setState(() => _filter = _KanbanFilter.dueToday),
            ),
            ChoiceChip(
              label: Text(l10n.taskHubFilterDueWeek),
              selected: _filter == _KanbanFilter.dueWeek,
              onSelected: (_) => setState(() => _filter = _KanbanFilter.dueWeek),
            ),
            ChoiceChip(
              label: Text(l10n.taskHubFilterOverdue),
              selected: _filter == _KanbanFilter.overdue,
              onSelected: (_) => setState(() => _filter = _KanbanFilter.overdue),
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
                  widget.session.setTaskBlockColumnId(e.pageId, e.blockId, columnId);
                },
                onOpenBlock: (e) {
                  widget.session.selectPage(e.pageId);
                  widget.session.requestScrollToBlock(e.blockId);
                },
                onOpenDetails: _openTaskDetails,
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
            onTap: () => setState(() => _openTask = null),
            child: const SizedBox.shrink(),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.only(left: FolioSpace.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: 420),
              child: _TaskDetailsPanel(
                session: widget.session,
                taskRef: open,
                onClose: () => setState(() => _openTask = null),
                onOpenTaskRef: (ref) => setState(() => _openTask = ref),
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

class _TaskRef {
  const _TaskRef({required this.pageId, required this.blockId});
  final String pageId;
  final String blockId;
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                      width: math.max(260, constraints.maxWidth / 3.2),
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

class _KanbanColumn extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return DragTarget<VaultTaskListEntry>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) => onMoveTaskToColumn(d.data, columnId),
      builder: (context, candidates, rejected) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(FolioRadius.md),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
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
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.kanbanEmptyColumn,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: entries.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          final subtitle = StringBuffer();
                          if (e.blockType == 'task') {
                            if (e.dueDate != null) subtitle.write(e.dueDate);
                            if (e.priority != null) {
                              if (subtitle.isNotEmpty) subtitle.write(' · ');
                              subtitle.write(e.priority);
                            }
                          }
                          final tile = Card(
                            elevation: 0,
                            color: scheme.surface.withValues(alpha: 0.9),
                            child: ListTile(
                              dense: true,
                              onTap: () => onOpenDetails(e),
                              title: Text(
                                e.displayTitle.isEmpty ? '—' : e.displayTitle,
                                style: textTheme.titleSmall?.copyWith(
                                  decoration: e.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : Text(
                                      subtitle.toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: PopupMenuButton<String>(
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
                            ),
                          );

                          if (e.blockType != 'task') return tile;
                          final blocked = e.task?.blocked == true;
                          if (blocked) {
                            return Opacity(opacity: 0.65, child: tile);
                          }
                          return Draggable<VaultTaskListEntry>(
                            data: e,
                            feedback: SizedBox(
                              width: 260,
                              child: Material(
                                color: Colors.transparent,
                                child: Opacity(opacity: 0.9, child: tile),
                              ),
                            ),
                            childWhenDragging:
                                Opacity(opacity: 0.35, child: tile),
                            child: tile,
                          );
                        },
                      ),
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
              style:
                  textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
                title: Text(e.displayTitle.isEmpty ? '—' : e.displayTitle),
                subtitle: e.dueDate == null ? null : Text(e.dueDate!),
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
                        style: textTheme.titleSmall?.copyWith(
                          decoration:
                              e.isDone ? TextDecoration.lineThrough : null,
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
                              label: Text(e.dueDate!),
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
            : '${e.startDate ?? '—'} → ${e.dueDate ?? '—'}';
        return Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          child: ListTile(
            title: Text(e.displayTitle.isEmpty ? '—' : e.displayTitle),
            subtitle: Text(range),
            onTap: () => onOpenDetails(e),
          ),
        );
      },
    );
  }

  DateTime? _tryParseIso(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    try {
      final p = iso.trim().split('-');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }
}

class _TaskDetailsPanel extends StatelessWidget {
  const _TaskDetailsPanel({
    required this.session,
    required this.taskRef,
    required this.onClose,
    required this.onOpenTaskRef,
  });

  final VaultSession session;
  final _TaskRef taskRef;
  final VoidCallback onClose;
  final void Function(_TaskRef ref) onOpenTaskRef;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 10,
      borderRadius: BorderRadius.circular(FolioRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: _TaskDetailsContent(
        session: session,
        taskRef: taskRef,
        onClose: onClose,
        onOpenTaskRef: onOpenTaskRef,
      ),
    );
  }
}

class _TaskDetailsSheet extends StatelessWidget {
  const _TaskDetailsSheet({
    required this.session,
    required this.taskRef,
    required this.onClose,
    required this.onOpenTaskRef,
  });

  final VaultSession session;
  final _TaskRef taskRef;
  final VoidCallback onClose;
  final void Function(_TaskRef ref) onOpenTaskRef;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 10,
      borderRadius: BorderRadius.circular(FolioRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.84,
        child: _TaskDetailsContent(
          session: session,
          taskRef: taskRef,
          onClose: onClose,
          onOpenTaskRef: onOpenTaskRef,
        ),
      ),
    );
  }
}

class _TaskDetailsContent extends StatefulWidget {
  const _TaskDetailsContent({
    required this.session,
    required this.taskRef,
    required this.onClose,
    required this.onOpenTaskRef,
  });

  final VaultSession session;
  final _TaskRef taskRef;
  final VoidCallback onClose;
  final void Function(_TaskRef ref) onOpenTaskRef;

  @override
  State<_TaskDetailsContent> createState() => _TaskDetailsContentState();
}

class _TaskDetailsContentState extends State<_TaskDetailsContent> {
  FolioTaskData? _data;
  late final TextEditingController _titleCtrl = TextEditingController();
  late final TextEditingController _descCtrl = TextEditingController();
  late final TextEditingController _timeCtrl = TextEditingController();
  late final TextEditingController _blockedReasonCtrl = TextEditingController();
  FolioBlock? _taskBlock;
  List<_ChildTaskRow> _childTasks = const [];

  @override
  void initState() {
    super.initState();
    _reloadFromSession();
    widget.session.addListener(_onSession);
  }

  @override
  void didUpdateWidget(covariant _TaskDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskRef.pageId != widget.taskRef.pageId ||
        oldWidget.taskRef.blockId != widget.taskRef.blockId) {
      _reloadFromSession();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _blockedReasonCtrl.dispose();
    super.dispose();
  }

  void _onSession() {
    _reloadFromSession(keepUserTextIfSame: true);
  }

  void _reloadFromSession({bool keepUserTextIfSame = false}) {
    FolioPage? page;
    try {
      page = widget.session.pages.firstWhere((p) => p.id == widget.taskRef.pageId);
    } catch (_) {
      page = null;
    }
    if (page == null) return;
    FolioBlock? b;
    for (final blk in page.blocks) {
      if (blk.id == widget.taskRef.blockId) {
        b = blk;
        break;
      }
    }
    if (b == null || b.type != 'task') return;
    _taskBlock = b;
    final parsed = FolioTaskData.tryParse(b.text);
    if (parsed == null) return;
    _data = parsed;
    if (!keepUserTextIfSame || _titleCtrl.text != parsed.title) {
      _titleCtrl.text = parsed.title;
    }
    if (!keepUserTextIfSame || _descCtrl.text != parsed.description) {
      _descCtrl.text = parsed.description;
    }
    final timeText = parsed.timeSpentMinutes?.toString() ?? '';
    if (!keepUserTextIfSame || _timeCtrl.text != timeText) {
      _timeCtrl.text = timeText;
    }
    if (!keepUserTextIfSame || _blockedReasonCtrl.text != parsed.blockedReason) {
      _blockedReasonCtrl.text = parsed.blockedReason;
    }

    // Resolver subtareas como tareas hijas (bloques `task` con parentTaskId).
    final children = <_ChildTaskRow>[];
    for (final blk in page.blocks) {
      if (blk.type != 'task') continue;
      if (blk.id == widget.taskRef.blockId) continue;
      final t = FolioTaskData.tryParse(blk.text);
      if (t == null) continue;
      if (t.parentTaskId == widget.taskRef.blockId) {
        children.add(_ChildTaskRow(blockId: blk.id, data: t));
      }
    }
    _childTasks = children;
    if (mounted) setState(() {});
  }

  void _emit(FolioTaskData next) {
    widget.session.updateBlockText(
      widget.taskRef.pageId,
      widget.taskRef.blockId,
      next.encode(),
    );
  }

  DateTime? _parseIso(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    try {
      final p = iso.trim().split('-');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  String? _iso(DateTime? d) {
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final cur = _data;
    if (cur == null) return;
    final initial = _parseIso(start ? cur.startDate : cur.dueDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted || picked == null) return;
    final next = start
        ? cur.copyWith(startDate: _iso(picked))
        : cur.copyWith(dueDate: _iso(picked));
    _emit(next);
  }

  void _addSubtask() {
    final cur = _data;
    final parentBlock = _taskBlock;
    if (cur == null || parentBlock == null) return;
    final pageId = widget.taskRef.pageId;
    final afterId = widget.taskRef.blockId;
    final depth = parentBlock.depth + 1;
    final child = FolioTaskData.defaults().copyWith(
      parentTaskId: afterId,
      columnId: cur.effectiveColumnId(),
      status: cur.status,
    );
    final newBlockId = '${pageId}_${DateTime.now().microsecondsSinceEpoch}';
    widget.session.insertBlockAfter(
      pageId: pageId,
      afterBlockId: afterId,
      block: FolioBlock(
        id: newBlockId,
        type: 'task',
        text: child.encode(),
        depth: depth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final data = _data;

    return Padding(
      padding: const EdgeInsets.all(FolioSpace.md),
      child: data == null
          ? Center(
              child: Text(
                l10n.taskHubEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.task_alt_rounded),
                    const SizedBox(width: FolioSpace.sm),
                    Expanded(
                      child: Text(
                        l10n.taskQuickAddTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.cancel,
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: FolioSpace.sm),
                TextField(
                  controller: _titleCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.title,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => _emit(data.copyWith(title: v.trim())),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  minLines: 2,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => _emit(data.copyWith(description: v)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: data.priority,
                        decoration: InputDecoration(
                          labelText: l10n.priority,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text(l10n.none)),
                          DropdownMenuItem(value: 'low', child: Text(l10n.low)),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text(l10n.medium),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text(l10n.high),
                          ),
                        ],
                        onChanged: (v) => _emit(data.copyWith(priority: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: data.status,
                        decoration: InputDecoration(
                          labelText: l10n.status,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'todo',
                            child: Text(l10n.taskStatusTodo),
                          ),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text(l10n.taskStatusInProgress),
                          ),
                          DropdownMenuItem(
                            value: 'done',
                            child: Text(l10n.taskStatusDone),
                          ),
                        ],
                        onChanged: (v) => _emit(data.copyWith(status: v ?? 'todo')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.taskBlocked),
                  value: data.blocked,
                  onChanged: (v) => _emit(data.copyWith(blocked: v)),
                ),
                if (data.blocked) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _blockedReasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.taskBlockedReason,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => _emit(data.copyWith(blockedReason: v)),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(start: true),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          data.startDate == null
                              ? l10n.startDate
                              : '${l10n.startDate}: ${data.startDate}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(start: false),
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(
                          data.dueDate == null
                              ? l10n.dueDate
                              : '${l10n.dueDate}: ${data.dueDate}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _timeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.timeSpentMinutes,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => _emit(
                    data.copyWith(timeSpentMinutes: int.tryParse(v.trim())),
                  ),
                ),
                const SizedBox(height: FolioSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.subtasks,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addSubtask,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.add),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: _childTasks.isEmpty
                      ? Center(
                          child: Text(
                            l10n.kanbanEmptyColumn,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _childTasks.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final child = _childTasks[i];
                            final s = child.data;
                            return Card(
                              elevation: 0,
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.25),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => widget.onOpenTaskRef(
                                  _TaskRef(
                                    pageId: widget.taskRef.pageId,
                                    blockId: child.blockId,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: s.status == 'done',
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (v) {
                                          final next = s.copyWith(
                                            status: v == true ? 'done' : 'todo',
                                          );
                                          widget.session.updateBlockText(
                                            widget.taskRef.pageId,
                                            child.blockId,
                                            next.encode(),
                                          );
                                        },
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          key: ValueKey(
                                            'detail_subtask_${child.blockId}',
                                          ),
                                          initialValue: s.title,
                                          decoration: InputDecoration(
                                            labelText: l10n.title,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (v) {
                                            final next = s.copyWith(title: v);
                                            widget.session.updateBlockText(
                                              widget.taskRef.pageId,
                                              child.blockId,
                                              next.encode(),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: l10n.taskHubOpen,
                                        onPressed: () => widget.onOpenTaskRef(
                                          _TaskRef(
                                            pageId: widget.taskRef.pageId,
                                            blockId: child.blockId,
                                          ),
                                        ),
                                        icon: const Icon(Icons.open_in_new_rounded),
                                      ),
                                      IconButton(
                                        tooltip: l10n.delete,
                                        onPressed: () {
                                          widget.session.removeBlockIfMultiple(
                                            widget.taskRef.pageId,
                                            child.blockId,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _ChildTaskRow {
  const _ChildTaskRow({required this.blockId, required this.data});
  final String blockId;
  final FolioTaskData data;
}


