import 'dart:math' as math;
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_kanban_data.dart';
import '../../../models/folio_task_data.dart';
import '../../../models/folio_page.dart';
import '../../../models/jira_integration_state.dart';
import '../../../models/vault_task_list_entry.dart';
import '../../../session/vault_session.dart';
import '../../../services/jira/jira_api_client.dart';
import '../../../services/jira/jira_sync_service.dart';
import '../tasks/task_quick_add_dialog.dart';

enum _KanbanFilter { all, active, done, dueToday, dueWeek, overdue }

/// Formatea 'YYYY-MM-DD' o 'YYYY-MM-DDTHH:MM' para mostrarlo en la UI.
String _fmtDue(String due) => due.replaceFirst('T', ' ');

String _formatJiraError(Object e, {required bool isEs}) {
  if (e is JiraApiException) {
    if (e.statusCode == 410) {
      return isEs
          ? 'Jira devolvió 410 (Gone). Suele ocurrir si la conexión/sitio ya no es válido (acceso revocado o cloudId incorrecto). Re-conecta Jira y vuelve a intentar.\nDetalle: $e'
          : 'Jira returned 410 (Gone). This usually means the connection/site is no longer valid (access revoked or wrong cloudId). Reconnect Jira and try again.\nDetails: $e';
    }
    return '${isEs ? 'Error Jira' : 'Jira error'}: $e';
  }
  return '${isEs ? 'Error Jira' : 'Jira error'}: $e';
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
  _TaskRef? _openTask;
  var _jiraSyncBusy = false;

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

  Future<void> _syncJira({required String jiraSourceId}) async {
    if (_jiraSyncBusy) return;
    setState(() => _jiraSyncBusy = true);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEs ? 'Jira: sincronizando (pull)…' : 'Jira: syncing (pull)…',
          ),
        ),
      );
      final pull = await const JiraSyncService().pullIssuesIntoPage(
        session: widget.session,
        pageId: widget.pageId,
        jiraSourceId: jiraSourceId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEs ? 'Jira: pull OK · ahora push…' : 'Jira: pull OK · now push…',
          ),
        ),
      );
      final push = await const JiraSyncService().pushLinkedTasksFromPage(
        session: widget.session,
        pageId: widget.pageId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'Jira: pull ${pull.pulled} · +${pull.created} · ~${pull.updated} · push ${push.pushed} (omitidos ${push.skipped})'
                : 'Jira: pull ${pull.pulled} · +${pull.created} · ~${pull.updated} · push ${push.pushed} (skipped ${push.skipped})',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_formatJiraError(e, isEs: isEs))),
      );
    } finally {
      if (mounted) setState(() => _jiraSyncBusy = false);
    }
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
    if (page != null) {
      final cfg = _kanbanConfigFor(page);
      final data = cfg.data;
      final sourceId = (data.jiraSourceId ?? '').trim();
      if (sourceId.isNotEmpty && data.jiraCreateIssuesOnQuickAdd) {
        final created = await _quickAddToJira(
          page: page,
          kanbanBlockId: cfg.blockId,
          jiraSourceId: sourceId,
          defaultColumnId: data.columns.isEmpty
              ? 'todo'
              : data.columns.first.id,
        );
        if (created && mounted) {
          setState(() {});
          return;
        }
      }
    }
    await showTaskQuickAddDialog(
      context: context,
      session: widget.session,
      appSettings: widget.appSettings,
      targetPageId: widget.pageId,
    );
    if (mounted) setState(() {});
  }

  Future<bool> _quickAddToJira({
    required FolioPage page,
    required String kanbanBlockId,
    required String jiraSourceId,
    required String defaultColumnId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final source = widget.session.jiraSources.firstWhereOrNull(
      (s) => s.id == jiraSourceId,
    );
    if (source == null) return false;
    if (source.type != JiraSourceType.project ||
        (source.projectKey ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'Para crear issues desde Kanban, usa una fuente de tipo Project.'
                : 'To create issues from Kanban, use a Project source.',
          ),
        ),
      );
      return false;
    }
    final connection = widget.session.jiraConnections.firstWhere(
      (c) => c.id == source.connectionId,
      orElse: () => throw StateError('Conexión Jira no encontrada'),
    );

    final summaryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final summary = await showDialog<String?>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(isEs ? 'Nuevo issue en Jira' : 'New Jira issue'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: summaryCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.title,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop<String?>(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop<String?>(summaryCtrl.text),
            child: Text(isEs ? 'Crear' : l10n.add),
          ),
        ],
      ),
    );
    final desc = descCtrl.text;
    summaryCtrl.dispose();
    descCtrl.dispose();
    if (!mounted || summary == null) return false;
    final normalized = summary.trim();
    if (normalized.isEmpty) return false;

    try {
      final client = JiraApiClient(connection: connection);
      final created = await client.createIssue(
        projectKey: source.projectKey!.trim(),
        issueTypeName: 'Task',
        summary: normalized,
        description: desc.trim().isEmpty ? null : desc.trim(),
      );
      final external = FolioExternalTaskLink(
        provider: 'jira',
        issueId: created.id,
        issueKey: created.key,
        deployment: connection.deployment.name,
        baseUrl: connection.deployment == JiraDeployment.server
            ? connection.baseUrl
            : null,
        cloudId: connection.deployment == JiraDeployment.cloud
            ? connection.cloudId
            : null,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        syncState: 'ok',
      );
      final task = FolioTaskData.defaults().copyWith(
        title: normalized,
        description: desc,
        status: 'todo',
        columnId: defaultColumnId,
        external: external,
      );
      final newBlockId =
          '${widget.pageId}_${DateTime.now().microsecondsSinceEpoch}';
      widget.session.insertBlockAfter(
        pageId: widget.pageId,
        afterBlockId: kanbanBlockId.isEmpty
            ? (page.blocks.isEmpty ? '' : page.blocks.last.id)
            : kanbanBlockId,
        block: FolioBlock(
          id: newBlockId,
          type: 'task',
          text: task.encode(),
          depth: 0,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'Issue creado: ${created.key}'
                : 'Issue created: ${created.key}',
          ),
        ),
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isEs ? 'Error Jira' : 'Jira error'}: $e')),
      );
      return false;
    }
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
    final cols = List<FolioKanbanColumnSpec>.from(data.columns)
      ..removeAt(index);
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
                              _persistKanbanData(
                                latestPage.id,
                                latestCfg.blockId,
                                data.copyWith(viewMode: s.first),
                              );
                            },
                          ),
                          const SizedBox(height: FolioSpace.md),
                          Text(
                            'Jira',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (ctx) {
                              final isEs =
                                  Localizations.localeOf(ctx).languageCode ==
                                  'es';
                              // Defensive: avoid DropdownButton crashes if sources contain duplicates
                              // (e.g. corrupted state) or if a previously-selected source was deleted.
                              final sourcesById = <String, JiraSource>{};
                              for (final s in widget.session.jiraSources) {
                                sourcesById[s.id] = s;
                              }
                              final sources = sourcesById.values.toList(
                                growable: false,
                              );
                              final selected = (data.jiraSourceId ?? '').trim();
                              final selectedValue =
                                  selected.isEmpty ||
                                      !sourcesById.containsKey(selected)
                                  ? null
                                  : selected;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DropdownButtonFormField<String?>(
                                    value: selectedValue,
                                    decoration: InputDecoration(
                                      labelText: isEs
                                          ? 'Fuente Jira (opcional)'
                                          : 'Jira source (optional)',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(isEs ? 'Ninguna' : 'None'),
                                      ),
                                      for (final s in sources)
                                        DropdownMenuItem<String?>(
                                          value: s.id,
                                          child: Text(s.name),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      _persistKanbanData(
                                        latestPage.id,
                                        latestCfg.blockId,
                                        data.copyWith(
                                          jiraSourceId:
                                              v?.trim().isEmpty == true
                                              ? null
                                              : v,
                                        ),
                                      );
                                    },
                                  ),
                                  if (selectedValue != null) ...[
                                    const SizedBox(height: 8),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        isEs
                                            ? 'Auto-importar desde Jira'
                                            : 'Auto-import from Jira',
                                      ),
                                      value: data.jiraAutoImport,
                                      onChanged: (v) {
                                        _persistKanbanData(
                                          latestPage.id,
                                          latestCfg.blockId,
                                          data.copyWith(jiraAutoImport: v),
                                        );
                                      },
                                    ),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        isEs
                                            ? 'Crear issues al añadir tarea'
                                            : 'Create issues when adding tasks',
                                      ),
                                      value: data.jiraCreateIssuesOnQuickAdd,
                                      onChanged: (v) {
                                        _persistKanbanData(
                                          latestPage.id,
                                          latestCfg.blockId,
                                          data.copyWith(
                                            jiraCreateIssuesOnQuickAdd: v,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
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
    final isEs = Localizations.localeOf(context).languageCode == 'es';

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
                tooltip: isEs
                    ? 'Sincronizar Jira (pull + push)'
                    : 'Sync Jira (pull + push)',
                onPressed: _jiraSyncBusy
                    ? null
                    : () => _syncJira(jiraSourceId: data.jiraSourceId!.trim()),
                icon: _jiraSyncBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
            if ((data.jiraSourceId ?? '').trim().isNotEmpty)
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
                            if (e.dueDate != null)
                              subtitle.write(_fmtDue(e.dueDate!));
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

                          Widget? jiraBadge() {
                            if (jiraState == null) return null;
                            if (jiraState == 'ok') return null;
                            final isEs =
                                Localizations.localeOf(context).languageCode ==
                                'es';
                            Color c() => switch (jiraState) {
                              'conflict' => scheme.error,
                              'needsPush' => scheme.tertiary,
                              'needsPull' => scheme.secondary,
                              _ => scheme.primary,
                            };
                            String label() => switch (jiraState) {
                              'conflict' => isEs ? 'Conflicto' : 'Conflict',
                              'needsPush' =>
                                isEs ? 'Pendiente push' : 'Needs push',
                              'needsPull' =>
                                isEs ? 'Pendiente pull' : 'Needs pull',
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (jiraBadge() != null) ...[
                                    jiraBadge()!,
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
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: tile,
                            ),
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
                title: Text(e.displayTitle.isEmpty ? '—' : e.displayTitle),
                subtitle: e.dueDate == null ? null : Text(_fmtDue(e.dueDate!)),
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
                          decoration: e.isDone
                              ? TextDecoration.lineThrough
                              : null,
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
                              label: Text(_fmtDue(e.dueDate!)),
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
            : '${e.startDate ?? '—'} → ${e.dueDate != null ? _fmtDue(e.dueDate!) : '—'}';
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
    return DateTime.tryParse(iso.trim());
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
  var _deleteBusy = false;

  var _jiraBusy = false;
  String? _jiraError;
  JiraIssueExpanded? _jiraIssue;
  List<JiraComment> _jiraComments = const [];
  List<JiraWorklog> _jiraWorklogs = const [];
  final _jiraNewCommentCtrl = TextEditingController();
  final _jiraWorklogMinutesCtrl = TextEditingController();
  bool _jiraAutoPulledOnce = false;

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
    _jiraNewCommentCtrl.dispose();
    _jiraWorklogMinutesCtrl.dispose();
    super.dispose();
  }

  void _onSession() {
    _reloadFromSession(keepUserTextIfSame: true);
  }

  void _reloadFromSession({bool keepUserTextIfSame = false}) {
    FolioPage? page;
    try {
      page = widget.session.pages.firstWhere(
        (p) => p.id == widget.taskRef.pageId,
      );
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
    if (!keepUserTextIfSame ||
        _blockedReasonCtrl.text != parsed.blockedReason) {
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

    // Best-effort: auto pull Jira details once per task open.
    final ext = parsed.external;
    if (!_jiraAutoPulledOnce &&
        ext != null &&
        ext.provider == 'jira' &&
        (ext.issueId.trim().isNotEmpty ||
            (ext.issueKey ?? '').trim().isNotEmpty)) {
      _jiraAutoPulledOnce = true;
      unawaited(_jiraRefresh());
    }
  }

  void _emit(FolioTaskData next) {
    // If this task is linked to Jira, mark it dirty for incremental push.
    final ext = next.external;
    if (ext != null && ext.provider == 'jira') {
      final cur = (ext.syncState ?? '').trim();
      if (cur != 'conflict') {
        next = next.copyWith(external: ext.copyWith(syncState: 'needsPush'));
      }
    }
    widget.session.updateBlockText(
      widget.taskRef.pageId,
      widget.taskRef.blockId,
      next.encode(),
    );
  }

  Future<void> _deleteTaskWithJiraIfLinked() async {
    if (_deleteBusy) return;
    final data = _data;
    if (data == null) return;

    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEs ? 'Borrar tarea' : 'Delete task'),
        content: Text(
          data.external?.provider == 'jira'
              ? (isEs
                    ? 'Esta acción borrará la tarea en Folio y también el issue en Jira (incluyendo subtareas vinculadas). ¿Continuar?'
                    : 'This will delete the task in Folio and also the issue in Jira (including linked subtasks). Continue?')
              : (isEs
                    ? '¿Borrar la tarea en Folio?'
                    : 'Delete this task in Folio?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isEs ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isEs ? 'Borrar' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleteBusy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Collect children (task blocks) by parentTaskId.
      final page = widget.session.pages.firstWhereOrNull(
        (p) => p.id == widget.taskRef.pageId,
      );
      final toDeleteBlockIds = <String>[];
      if (page != null) {
        for (final blk in page.blocks) {
          if (blk.type != 'task') continue;
          if (blk.id == widget.taskRef.blockId) continue;
          final t = FolioTaskData.tryParse(blk.text);
          if (t == null) continue;
          if (t.parentTaskId == widget.taskRef.blockId) {
            toDeleteBlockIds.add(blk.id);
          }
        }
      }
      // Delete children first, then parent.
      toDeleteBlockIds.add(widget.taskRef.blockId);

      // Delete in Jira where linked.
      for (final blockId in toDeleteBlockIds) {
        final blk = page?.blocks.firstWhereOrNull((b) => b.id == blockId);
        if (blk == null) continue;
        final t = FolioTaskData.tryParse(blk.text);
        final ext = t?.external;
        if (ext == null || ext.provider != 'jira') continue;
        final client = _jiraClientFor(ext);
        if (client == null) {
          throw StateError(
            isEs
                ? 'No se encontró la conexión Jira para borrar el issue.'
                : 'Jira connection not found to delete issue.',
          );
        }
        final issueIdOrKey = (ext.issueKey ?? '').trim().isNotEmpty
            ? ext.issueKey!.trim()
            : ext.issueId;
        await client.deleteIssue(issueIdOrKey);
      }

      // Delete locally (single undo step).
      widget.session.removeBlocksIfMultiple(
        widget.taskRef.pageId,
        toDeleteBlockIds,
      );

      messenger.showSnackBar(
        SnackBar(content: Text(isEs ? 'Tarea borrada.' : 'Task deleted.')),
      );
      widget.onClose();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_formatJiraError(e, isEs: isEs))),
      );
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  JiraApiClient? _jiraClientFor(FolioExternalTaskLink ext) {
    final dep = (ext.deployment ?? '').trim().toLowerCase();
    JiraConnection? conn;
    if (dep == 'server') {
      final base = (ext.baseUrl ?? '').trim();
      conn = widget.session.jiraConnections.firstWhereOrNull(
        (c) =>
            c.deployment == JiraDeployment.server &&
            (c.baseUrl ?? '').trim() == base,
      );
    } else {
      final cloudId = (ext.cloudId ?? '').trim();
      conn = widget.session.jiraConnections.firstWhereOrNull(
        (c) =>
            c.deployment == JiraDeployment.cloud &&
            (c.cloudId ?? '').trim() == cloudId,
      );
    }
    if (conn == null) return null;
    return JiraApiClient(connection: conn);
  }

  JiraApiClient? _jiraClientOrSetError(FolioExternalTaskLink ext) {
    final client = _jiraClientFor(ext);
    if (client != null) return client;
    setState(() {
      _jiraError = Localizations.localeOf(context).languageCode == 'es'
          ? 'No se encontró la conexión Jira para esta tarea. Re-conecta Jira en Ajustes → Integraciones.'
          : 'Jira connection not found for this task. Reconnect Jira in Settings → Integrations.';
    });
    return null;
  }

  Future<void> _jiraRefresh() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'jira') return;
    final client = _jiraClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _jiraBusy = true;
      _jiraError = null;
    });
    try {
      final issue = await client.getIssueExpanded(ext.issueKey ?? ext.issueId);
      setState(() => _jiraIssue = issue);
    } catch (e) {
      setState(() => _jiraError = '$e');
    } finally {
      if (mounted) setState(() => _jiraBusy = false);
    }
  }

  Future<void> _jiraLoadComments() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'jira') return;
    final client = _jiraClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _jiraBusy = true;
      _jiraError = null;
    });
    try {
      final comments = await client.listComments(
        issueIdOrKey: ext.issueKey ?? ext.issueId,
        maxResults: 50,
      );
      setState(() => _jiraComments = comments);
    } catch (e) {
      setState(() => _jiraError = '$e');
    } finally {
      if (mounted) setState(() => _jiraBusy = false);
    }
  }

  Future<void> _jiraAddComment() async {
    final text = _jiraNewCommentCtrl.text.trim();
    if (text.isEmpty) return;
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'jira') return;
    final client = _jiraClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _jiraBusy = true;
      _jiraError = null;
    });
    try {
      await client.addComment(
        issueIdOrKey: ext.issueKey ?? ext.issueId,
        bodyText: text,
      );
      _jiraNewCommentCtrl.clear();
      await _jiraLoadComments();
    } catch (e) {
      setState(() => _jiraError = '$e');
    } finally {
      if (mounted) setState(() => _jiraBusy = false);
    }
  }

  Future<void> _jiraLoadWorklogs() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'jira') return;
    final client = _jiraClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _jiraBusy = true;
      _jiraError = null;
    });
    try {
      final items = await client.listWorklogs(ext.issueKey ?? ext.issueId);
      setState(() => _jiraWorklogs = items);
    } catch (e) {
      setState(() => _jiraError = '$e');
    } finally {
      if (mounted) setState(() => _jiraBusy = false);
    }
  }

  Future<void> _jiraAddWorklog() async {
    final mins = int.tryParse(_jiraWorklogMinutesCtrl.text.trim());
    if (mins == null || mins <= 0) return;
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'jira') return;
    final client = _jiraClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _jiraBusy = true;
      _jiraError = null;
    });
    try {
      await client.addWorklog(
        issueIdOrKey: ext.issueKey ?? ext.issueId,
        timeSpentSeconds: mins * 60,
      );
      _jiraWorklogMinutesCtrl.clear();
      await _jiraLoadWorklogs();
    } catch (e) {
      setState(() => _jiraError = '$e');
    } finally {
      if (mounted) setState(() => _jiraBusy = false);
    }
  }

  String? _pageJiraSourceId() {
    try {
      final page = widget.session.pages.firstWhereOrNull(
        (p) => p.id == widget.taskRef.pageId,
      );
      if (page == null) return null;
      final kanban = page.blocks.firstWhereOrNull((b) => b.type == 'kanban');
      if (kanban == null) return null;
      final kd = FolioKanbanData.tryParse(kanban.text);
      final sid = (kd?.jiraSourceId ?? '').trim();
      return sid.isEmpty ? null : sid;
    } catch (_) {
      return null;
    }
  }

  Future<void> _jiraResolveKeepRemote() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'jira') return;
    setState(() {
      _jiraBusy = true;
      _jiraError = null;
    });
    try {
      final sid = _pageJiraSourceId();
      if (sid != null) {
        await const JiraSyncService().pullIssuesIntoPage(
          session: widget.session,
          pageId: widget.taskRef.pageId,
          jiraSourceId: sid,
          maxIssues: 200,
        );
      } else {
        // Fallback: pull only this issue and overwrite local mirror fields.
        final client = _jiraClientOrSetError(ext);
        if (client == null) return;
        final issue = await client.getIssueExpanded(
          ext.issueKey ?? ext.issueId,
        );
        final nextExt = ext.copyWith(
          remoteUpdatedAtMs:
              DateTime.tryParse(
                (issue.updatedAt ?? '').trim(),
              )?.millisecondsSinceEpoch ??
              ext.remoteUpdatedAtMs,
          syncState: 'ok',
          lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        _emit(
          data.copyWith(
            title: issue.summary,
            description: issue.descriptionText ?? '',
            dueDate: issue.dueDateIso,
            priority: data.priority, // kept; full mapping happens in full pull
            external: nextExt,
          ),
        );
      }
    } catch (e) {
      setState(() => _jiraError = '$e');
    } finally {
      if (mounted) setState(() => _jiraBusy = false);
    }
  }

  Future<void> _jiraResolveKeepLocalForcePush() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'jira') return;
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEs ? 'Forzar push a Jira' : 'Force push to Jira'),
        content: Text(
          isEs
              ? 'Esto sobrescribirá en Jira los cambios remotos detectados para este issue con lo que tienes en Folio. ¿Continuar?'
              : 'This will overwrite the remote Jira changes for this issue with your Folio version. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isEs ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isEs ? 'Forzar push' : 'Force push'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final client = _jiraClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _jiraBusy = true;
      _jiraError = null;
    });
    try {
      final issueIdOrKey = (ext.issueKey ?? '').trim().isNotEmpty
          ? ext.issueKey!.trim()
          : ext.issueId;
      // Force push: write current local mirror fields, regardless of remoteUpdatedAtMs.
      final desiredPriorityName = switch ((data.priority ?? '')
          .trim()
          .toLowerCase()) {
        'highest' => 'Highest',
        'high' => 'High',
        'medium' => 'Medium',
        'low' => 'Low',
        'lowest' => 'Lowest',
        _ => null,
      };
      await client.updateIssueFields(
        issueIdOrKey: issueIdOrKey,
        summary: data.title.trim(),
        description: data.description,
        dueDateIso: data.dueDate,
        priorityName: desiredPriorityName,
      );
      // Refresh remote updatedAt and clear conflict.
      int? remoteUpdatedAtMs = ext.remoteUpdatedAtMs;
      try {
        final refreshed = await client.getIssueExpanded(issueIdOrKey);
        remoteUpdatedAtMs =
            DateTime.tryParse(
              (refreshed.updatedAt ?? '').trim(),
            )?.millisecondsSinceEpoch ??
            remoteUpdatedAtMs;
        setState(() => _jiraIssue = refreshed);
      } catch (_) {}
      final nextExt = ext.copyWith(
        remoteUpdatedAtMs: remoteUpdatedAtMs,
        syncState: 'ok',
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      _emit(data.copyWith(external: nextExt));
    } catch (e) {
      setState(() => _jiraError = '$e');
    } finally {
      if (mounted) setState(() => _jiraBusy = false);
    }
  }

  Uri? _jiraBrowseUri(FolioExternalTaskLink ext) {
    if (ext.provider != 'jira') return null;
    final issueKey = (ext.issueKey ?? '').trim();
    final target = issueKey.isNotEmpty ? issueKey : ext.issueId.trim();
    if (target.isEmpty) return null;
    final dep = (ext.deployment ?? '').trim().toLowerCase();
    if (dep == 'server') {
      final base = (ext.baseUrl ?? '').trim();
      final baseUri = Uri.tryParse(base);
      if (baseUri == null) return null;
      return baseUri.replace(path: '${baseUri.path}/browse/$target');
    }
    // Cloud: try infer from known connections (siteUrl).
    final cloudId = (ext.cloudId ?? '').trim();
    final conn = widget.session.jiraConnections.firstWhereOrNull(
      (c) =>
          c.deployment == JiraDeployment.cloud &&
          (c.cloudId ?? '').trim() == cloudId,
    );
    final site = (conn?.siteUrl ?? '').trim();
    final siteUri = Uri.tryParse(site);
    if (siteUri == null) return null;
    return siteUri.replace(path: '${siteUri.path}/browse/$target');
  }

  DateTime? _parseIso(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso.trim());
  }

  String? _iso(DateTime? d) {
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _isoWithTime(DateTime d, TimeOfDay t) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '$y-$m-${day}T$h:$min';
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
    if (start) {
      _emit(cur.copyWith(startDate: _iso(picked)));
      return;
    }
    final existingDt = _parseIso(cur.dueDate);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: existingDt != null && (cur.dueDate?.contains('T') ?? false)
          ? TimeOfDay(hour: existingDt.hour, minute: existingDt.minute)
          : TimeOfDay.now(),
    );
    if (!mounted) return;
    final iso = pickedTime != null
        ? _isoWithTime(picked, pickedTime)
        : _iso(picked);
    _emit(cur.copyWith(dueDate: iso));
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
          : SingleChildScrollView(
              child: Column(
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
                        tooltip: l10n.delete,
                        onPressed: _deleteBusy
                            ? null
                            : _deleteTaskWithJiraIfLinked,
                        icon: _deleteBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                      ),
                      IconButton(
                        tooltip: l10n.cancel,
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: FolioSpace.sm),
                  if (data.external?.provider == 'jira') ...[
                    Builder(
                      builder: (ctx) {
                        final isEs =
                            Localizations.localeOf(ctx).languageCode == 'es';
                        final ext = data.external!;
                        final uri = _jiraBrowseUri(ext);
                        final label =
                            (ext.issueKey ?? '').trim().isNotEmpty == true
                            ? ext.issueKey!.trim()
                            : ext.issueId;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.25,
                            ),
                            borderRadius: BorderRadius.circular(FolioRadius.md),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.grid_view_rounded, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Jira · $label',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: uri == null
                                    ? null
                                    : () async {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: Text(isEs ? 'Abrir' : l10n.taskHubOpen),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _JiraDetailsSection(
                      scheme: scheme,
                      data: data,
                      busy: _jiraBusy,
                      error: _jiraError,
                      issue: _jiraIssue,
                      comments: _jiraComments,
                      worklogs: _jiraWorklogs,
                      newCommentCtrl: _jiraNewCommentCtrl,
                      worklogMinutesCtrl: _jiraWorklogMinutesCtrl,
                      onRefresh: _jiraRefresh,
                      onResolveKeepRemote: _jiraResolveKeepRemote,
                      onResolveKeepLocalForcePush:
                          _jiraResolveKeepLocalForcePush,
                      onLoadComments: _jiraLoadComments,
                      onAddComment: _jiraAddComment,
                      onLoadWorklogs: _jiraLoadWorklogs,
                      onAddWorklog: _jiraAddWorklog,
                    ),
                    const SizedBox(height: 10),
                  ],
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
                        child: DropdownButtonFormField<String?>(
                          initialValue: data.priority,
                          decoration: InputDecoration(
                            labelText: l10n.priority,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n.none),
                            ),
                            const DropdownMenuItem(
                              value: 'lowest',
                              child: Text('Lowest'),
                            ),
                            DropdownMenuItem(
                              value: 'low',
                              child: Text(l10n.low),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text(l10n.medium),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text(l10n.high),
                            ),
                            const DropdownMenuItem(
                              value: 'highest',
                              child: Text('Highest'),
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
                          onChanged: (v) =>
                              _emit(data.copyWith(status: v ?? 'todo')),
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
                                : '${l10n.dueDate}: ${_fmtDue(data.dueDate!)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Recurrence + reminder row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: data.recurrence,
                          decoration: InputDecoration(
                            labelText: l10n.taskRecurrenceLabel,
                            prefixIcon: const Icon(
                              Icons.repeat_rounded,
                              size: 20,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n.taskRecurrenceNone),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'daily',
                              child: Text(l10n.taskRecurrenceDaily),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'weekly',
                              child: Text(l10n.taskRecurrenceWeekly),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'monthly',
                              child: Text(l10n.taskRecurrenceMonthly),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'yearly',
                              child: Text(l10n.taskRecurrenceYearly),
                            ),
                          ],
                          onChanged: (v) => _emit(data.copyWith(recurrence: v)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: data.reminderEnabled
                            ? l10n.taskReminderOnTooltip
                            : l10n.taskReminderTooltip,
                        child: FilterChip(
                          avatar: Icon(
                            data.reminderEnabled
                                ? Icons.notifications_rounded
                                : Icons.notifications_none_rounded,
                            size: 18,
                          ),
                          label: Text(
                            data.reminderEnabled
                                ? l10n.taskReminderOnTooltip
                                : l10n.taskReminderTooltip,
                          ),
                          selected: data.reminderEnabled,
                          onSelected: (v) =>
                              _emit(data.copyWith(reminderEnabled: v)),
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
                  _childTasks.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.kanbanEmptyColumn,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _childTasks.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final child = _childTasks[i];
                            final s = child.data;
                            return Card(
                              elevation: 0,
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.25,
                              ),
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
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                        ),
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
                ],
              ),
            ),
    );
  }
}

class _JiraDetailsSection extends StatelessWidget {
  const _JiraDetailsSection({
    required this.scheme,
    required this.data,
    required this.busy,
    required this.error,
    required this.issue,
    required this.comments,
    required this.worklogs,
    required this.newCommentCtrl,
    required this.worklogMinutesCtrl,
    required this.onRefresh,
    required this.onResolveKeepRemote,
    required this.onResolveKeepLocalForcePush,
    required this.onLoadComments,
    required this.onAddComment,
    required this.onLoadWorklogs,
    required this.onAddWorklog,
  });

  final ColorScheme scheme;
  final FolioTaskData data;
  final bool busy;
  final String? error;
  final JiraIssueExpanded? issue;
  final List<JiraComment> comments;
  final List<JiraWorklog> worklogs;
  final TextEditingController newCommentCtrl;
  final TextEditingController worklogMinutesCtrl;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onResolveKeepRemote;
  final Future<void> Function() onResolveKeepLocalForcePush;
  final Future<void> Function() onLoadComments;
  final Future<void> Function() onAddComment;
  final Future<void> Function() onLoadWorklogs;
  final Future<void> Function() onAddWorklog;

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final ext = data.external!;
    final snap = data.jira;
    final state = (ext.syncState ?? 'ok').trim().isEmpty
        ? 'ok'
        : ext.syncState!.trim();
    Color stateColor() => switch (state) {
      'conflict' => scheme.error,
      'needsPush' => scheme.tertiary,
      'needsPull' => scheme.secondary,
      _ => scheme.primary,
    };

    Widget pill(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: stateColor().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stateColor().withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: stateColor(),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(FolioRadius.md),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Image.asset('appLogos/jira.png'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEs ? 'Jira' : 'Jira',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              pill(state),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onRefresh,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isEs ? 'Pull' : 'Pull'),
              ),
            ],
          ),
          if (state == 'conflict') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEs
                        ? 'Conflicto: hubo cambios en Jira y en Folio.'
                        : 'Conflict: there were changes in Jira and Folio.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx) {
                      String norm(String? s) => (s ?? '').trim();
                      String cut(String s, {int max = 120}) {
                        final t = s.trim();
                        if (t.isEmpty) return '—';
                        if (t.length <= max) return t;
                        return '${t.substring(0, max)}…';
                      }

                      Widget diffRow(String label, String folio, String jira) {
                        final same = folio.trim() == jira.trim();
                        final folioText = folio.trim().isEmpty
                            ? '—'
                            : folio.trim();
                        final jiraText = jira.trim().isEmpty
                            ? '—'
                            : jira.trim();
                        final baseStyle = Theme.of(ctx).textTheme.bodySmall
                            ?.copyWith(
                              color: scheme.onErrorContainer.withValues(
                                alpha: 0.92,
                              ),
                            );
                        final hi = Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                        );
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: same
                                  ? scheme.outlineVariant.withValues(
                                      alpha: 0.35,
                                    )
                                  : scheme.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                label,
                                style: Theme.of(ctx).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onErrorContainer,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${isEs ? 'Folio' : 'Folio'}: $folioText',
                                style: same ? baseStyle : hi,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${isEs ? 'Jira' : 'Jira'}: $jiraText',
                                style: baseStyle,
                              ),
                            ],
                          ),
                        );
                      }

                      final jira = issue;
                      if (jira == null) {
                        return Text(
                          isEs
                              ? 'Pulsa Pull para cargar el estado remoto y ver las diferencias.'
                              : 'Press Pull to load remote state and see differences.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        );
                      }

                      final localTitle = norm(data.title);
                      final remoteTitle = norm(jira.summary);
                      final localDesc = cut(norm(data.description), max: 140);
                      final remoteDesc = cut(
                        norm(jira.descriptionText),
                        max: 140,
                      );
                      final localDue = norm(data.dueDate);
                      final remoteDue = norm(jira.dueDateIso);
                      final localPriority = norm(data.priority);
                      final remotePriority = norm(jira.priorityName);
                      final localStatus = norm(data.status);
                      final remoteStatus = norm(jira.statusName);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          diffRow(
                            isEs ? 'Título' : 'Title',
                            localTitle,
                            remoteTitle,
                          ),
                          const SizedBox(height: 8),
                          diffRow(
                            isEs ? 'Descripción' : 'Description',
                            localDesc,
                            remoteDesc,
                          ),
                          const SizedBox(height: 8),
                          diffRow(
                            isEs ? 'Prioridad' : 'Priority',
                            localPriority,
                            remotePriority,
                          ),
                          const SizedBox(height: 8),
                          diffRow(
                            isEs ? 'Estado/columna' : 'Status/column',
                            localStatus,
                            remoteStatus,
                          ),
                          const SizedBox(height: 8),
                          diffRow(
                            isEs ? 'Fecha límite' : 'Due date',
                            localDue,
                            remoteDue,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: busy ? null : onResolveKeepRemote,
                        child: Text(
                          isEs ? 'Mantener Jira (Pull)' : 'Keep Jira (Pull)',
                        ),
                      ),
                      FilledButton(
                        onPressed: busy ? null : onResolveKeepLocalForcePush,
                        child: Text(
                          isEs
                              ? 'Mantener Folio (Force push)'
                              : 'Keep Folio (Force push)',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if ((error ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kvChip(
                context,
                isEs ? 'Estado' : 'Status',
                snap?.statusName ?? issue?.statusName ?? '—',
              ),
              _kvChip(
                context,
                isEs ? 'Assignee' : 'Assignee',
                snap?.assigneeDisplayName ?? issue?.assigneeDisplayName ?? '—',
              ),
              _kvChip(
                context,
                isEs ? 'Labels' : 'Labels',
                (snap?.labels ?? issue?.labels ?? const []).join(', '),
              ),
              _kvChip(
                context,
                isEs ? 'Componentes' : 'Components',
                (snap?.components ?? issue?.components ?? const []).join(', '),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              isEs ? 'Comentarios' : 'Comments',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onLoadComments,
                  child: Text(isEs ? 'Cargar' : 'Load'),
                ),
              ],
            ),
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newCommentCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: isEs ? 'Nuevo comentario' : 'New comment',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: busy ? null : onAddComment,
                    child: Text(isEs ? 'Enviar' : 'Send'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (comments.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEs ? 'Sin comentarios cargados.' : 'No comments loaded.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...comments.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.authorDisplayName ?? '—'} · ${(c.created ?? '').trim()}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(c.bodyText ?? ''),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
          const SizedBox(height: 6),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              isEs ? 'Adjuntos' : 'Attachments',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            children: [
              const SizedBox(height: 8),
              if ((issue?.attachments ?? const []).isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEs
                        ? 'Pulsa Pull para ver adjuntos.'
                        : 'Press Pull to see attachments.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...issue!.attachments.map(
                  (a) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attachment_rounded),
                    title: Text(a.filename),
                    subtitle: Text('${a.size ?? 0} bytes'),
                    trailing: IconButton(
                      tooltip: isEs ? 'Abrir' : 'Open',
                      onPressed: (a.contentUrl ?? '').trim().isEmpty
                          ? null
                          : () async {
                              final uri = Uri.tryParse(a.contentUrl!);
                              if (uri == null) return;
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              isEs ? 'Worklog / Tiempo' : 'Worklog / Time',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            trailing: OutlinedButton(
              onPressed: busy ? null : onLoadWorklogs,
              child: Text(isEs ? 'Cargar' : 'Load'),
            ),
            children: [
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _kvChip(
                    context,
                    isEs ? 'Estimación' : 'Estimate',
                    issue?.timetracking?.originalEstimateSeconds == null
                        ? '—'
                        : '${(issue!.timetracking!.originalEstimateSeconds! / 60).round()} min',
                  ),
                  _kvChip(
                    context,
                    isEs ? 'Restante' : 'Remaining',
                    issue?.timetracking?.remainingEstimateSeconds == null
                        ? '—'
                        : '${(issue!.timetracking!.remainingEstimateSeconds! / 60).round()} min',
                  ),
                  _kvChip(
                    context,
                    isEs ? 'Gastado' : 'Spent',
                    issue?.timetracking?.timeSpentSeconds == null
                        ? '—'
                        : '${(issue!.timetracking!.timeSpentSeconds! / 60).round()} min',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: worklogMinutesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isEs ? 'Añadir (minutos)' : 'Add (minutes)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: busy ? null : onAddWorklog,
                    child: Text(isEs ? 'Registrar' : 'Log'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (worklogs.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEs ? 'Sin worklogs cargados.' : 'No worklogs loaded.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...worklogs.map(
                  (w) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(
                      '${w.authorDisplayName ?? '—'} · ${(w.timeSpentSeconds ?? 0) ~/ 60} min',
                    ),
                    subtitle: Text((w.started ?? '').trim()),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kvChip(BuildContext context, String k, String v) {
    final text = v.trim().isEmpty ? '—' : v.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '$k: $text',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChildTaskRow {
  const _ChildTaskRow({required this.blockId, required this.data});
  final String blockId;
  final FolioTaskData data;
}
