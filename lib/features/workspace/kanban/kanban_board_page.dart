import 'dart:math' as math;
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
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
import '../../../models/youtrack_integration_state.dart';
import '../../../services/youtrack/youtrack_api_client.dart';
import '../../../services/youtrack/youtrack_sync_service.dart';
import '../../../services/app_store/app_store_service.dart';
import '../../../services/app_store/folio_built_in_apps.dart';
import '../tasks/task_quick_add_dialog.dart';
import 'kanban_ui_helpers.dart';

enum _KanbanFilter { all, active, done, dueToday, dueWeek, overdue }

/// Formatea 'YYYY-MM-DD' o 'YYYY-MM-DDTHH:MM' para mostrarlo en la UI.
String _fmtDue(String due) => due.replaceFirst('T', ' ');

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

String _formatJiraError(
  Object e,
  AppLocalizations l10n, {
  required bool isEs,
}) {
  if (e is JiraApiException) {
    if (e.statusCode == 410) {
      return isEs
          ? 'Jira devolvió 410 (Gone). Suele ocurrir si la conexión/sitio ya no es válido (acceso revocado o cloudId incorrecto). Re-conecta Jira y vuelve a intentar.\nDetalle: $e'
          : 'Jira returned 410 (Gone). This usually means the connection/site is no longer valid (access revoked or wrong cloudId). Reconnect Jira and try again.\nDetails: $e';
    }
    return l10n.kanbanJiraError('$e');
  }
  return l10n.kanbanJiraError('$e');
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
  var _detailsFullScreen = false;
  var _jiraSyncBusy = false;
  var _youtrackSyncBusy = false;

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

  Future<void> _syncYouTrack({required String youtrackSourceId}) async {
    if (_youtrackSyncBusy) return;
    setState(() => _youtrackSyncBusy = true);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isEs ? 'YouTrack: sincronizando (pull).' : 'YouTrack: syncing (pull).'),
        ),
      );
      final pull = await const YouTrackSyncService().pullIssuesIntoPage(
        session: widget.session,
        pageId: widget.pageId,
        youtrackSourceId: youtrackSourceId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(isEs ? 'YouTrack: pull OK - ahora push.' : 'YouTrack: pull OK - now push.'),
        ),
      );
      final push = await const YouTrackSyncService().pushLinkedTasksFromPage(
        session: widget.session,
        pageId: widget.pageId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'YouTrack: pull ${pull.pulled} · +${pull.created} · ~${pull.updated} · push ${push.pushed} (omitidos ${push.skipped})'
                : 'YouTrack: pull ${pull.pulled} · +${pull.created} · ~${pull.updated} · push ${push.pushed} (skipped ${push.skipped})',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error YouTrack: $e')),
      );
    } finally {
      if (mounted) setState(() => _youtrackSyncBusy = false);
    }
  }

  Future<void> _syncJira({required String jiraSourceId}) async {
    if (_jiraSyncBusy) return;
    setState(() => _jiraSyncBusy = true);
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
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
            isEs
                ? 'Jira: pull ${pull.pulled} · +${pull.created} · ~${pull.updated} · push ${push.pushed} (omitidos ${push.skipped})'
                : 'Jira: pull ${pull.pulled} · +${pull.created} · ~${pull.updated} · push ${push.pushed} (skipped ${push.skipped})',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_formatJiraError(e, l10n, isEs: isEs))),
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
      final ytSourceId = (data.youtrackSourceId ?? '').trim();
      if (ytSourceId.isNotEmpty && data.youtrackCreateIssuesOnQuickAdd) {
        final created = await _quickAddToYouTrack(
          page: page,
          kanbanBlockId: cfg.blockId,
          youtrackSourceId: ytSourceId,
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
    if (!mounted) return;
    await showTaskQuickAddDialog(
      context: context,
      session: widget.session,
      appSettings: widget.appSettings,
      targetPageId: widget.pageId,
      kanbanColumns: widget.session.kanbanDataForPage(widget.pageId).columns,
    );
    if (mounted) setState(() {});
  }

  Future<void> _quickAddForGroup(String columnId, {String? youtrackProjectId, String? youtrackProjectShortName}) async {
    final page = _resolvePage();
    if (page == null) return;
    final cfg = _kanbanConfigFor(page);
    final data = cfg.data;

    // Check if the board has YouTrack configured, and if the group is for a specific YouTrack project
    final ytSourceId = (data.youtrackSourceId ?? '').trim();
    if (ytSourceId.isNotEmpty && youtrackProjectId != null) {
      // Create issue in YouTrack directly for this specific project!
      final connection = widget.session.youtrackConnections.firstWhereOrNull(
        (c) => c.id == widget.session.youtrackSources.firstWhereOrNull((s) => s.id == ytSourceId)?.connectionId,
      );
      if (connection != null) {
        final l10n = AppLocalizations.of(context);
        final isEs = Localizations.localeOf(context).languageCode == 'es';

        final summaryCtrl = TextEditingController();
        final descCtrl = TextEditingController();
        final priorityCtrl = TextEditingController(text: 'Normal');
        final typeCtrl = TextEditingController(text: 'Task');
        final assigneeCtrl = TextEditingController();
        final subsystemCtrl = TextEditingController();
        final fixVersionsCtrl = TextEditingController();
        final affectedVersionsCtrl = TextEditingController();
        final fixedInBuildCtrl = TextEditingController();
        final estimateCtrl = TextEditingController();
        final spentTimeCtrl = TextEditingController();

        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDlgState) {
              return FolioDialog(
                title: Text(isEs ? 'Nueva tarea en YouTrack' : 'New YouTrack Task'),
                content: SizedBox(
                  width: 550,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: summaryCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Título' : 'Title',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Descripción' : 'Description',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: priorityCtrl.text,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Prioridad' : 'Priority',
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  for (final p in ['Showstopper', 'Critical', 'Major', 'Normal', 'Minor', 'Minimal'])
                                    DropdownMenuItem(value: p, child: Text(p)),
                                ],
                                onChanged: (v) => priorityCtrl.text = v ?? 'Normal',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: typeCtrl,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Tipo' : 'Type',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: assigneeCtrl,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Usuario asignado' : 'Assignee',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: subsystemCtrl,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Subsistema' : 'Subsystem',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fixVersionsCtrl,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Solucionar versiones' : 'Fix versions',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: affectedVersionsCtrl,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Versiones afectadas' : 'Affected versions',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fixedInBuildCtrl,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Solucionado en el build' : 'Fixed in build',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: estimateCtrl,
                                decoration: InputDecoration(
                                  labelText: isEs ? 'Estimación' : 'Estimation',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: spentTimeCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Tiempo empleado' : 'Spent time',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(isEs ? 'Crear' : l10n.add),
                  ),
                ],
              );
            },
          ),
        );

        final titleText = summaryCtrl.text.trim();
        final descText = descCtrl.text.trim();
        final priorityVal = priorityCtrl.text.trim();
        final typeVal = typeCtrl.text.trim();
        final assigneeVal = assigneeCtrl.text.trim();
        final subsystemVal = subsystemCtrl.text.trim();
        final fixVersionsVal = fixVersionsCtrl.text.trim();
        final affectedVersionsVal = affectedVersionsCtrl.text.trim();
        final fixedInBuildVal = fixedInBuildCtrl.text.trim();
        final estimateVal = estimateCtrl.text.trim();
        final spentTimeVal = spentTimeCtrl.text.trim();

        summaryCtrl.dispose();
        descCtrl.dispose();
        priorityCtrl.dispose();
        typeCtrl.dispose();
        assigneeCtrl.dispose();
        subsystemCtrl.dispose();
        fixVersionsCtrl.dispose();
        affectedVersionsCtrl.dispose();
        fixedInBuildCtrl.dispose();
        estimateCtrl.dispose();
        spentTimeCtrl.dispose();

        if (!mounted || result != true) return;
        if (titleText.isEmpty) return;

        setState(() => _youtrackSyncBusy = true);
        try {
          final client = YouTrackApiClient(connection: connection);
          final createdIssue = await client.createIssue(
            projectId: youtrackProjectId,
            summary: titleText,
            description: descText,
          );

          final remoteIssue = await client.getIssue(createdIssue.id);

          final fieldValues = <String, String?>{
            'Priority': priorityVal,
            'Type': typeVal,
            'Assignee': assigneeVal,
            'Subsystem': subsystemVal,
            'Fix versions': fixVersionsVal,
            'Affected versions': affectedVersionsVal,
            'Fixed in build': fixedInBuildVal,
            'Estimation': estimateVal,
            'Spent time': spentTimeVal,
          };

          await client.updateIssueFields(
            issueIdOrKey: createdIssue.id,
            summary: titleText,
            description: descText,
            customFieldIds: remoteIssue.customFieldIds,
            customFieldValues: fieldValues,
          );

          final created = await client.getIssue(createdIssue.id);

          final external = FolioExternalTaskLink(
            provider: 'youtrack',
            issueId: created.id,
            issueKey: created.idReadable,
            deployment: 'server',
            baseUrl: connection.baseUrl,
            lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
            syncState: 'ok',
          );

          final task = FolioTaskData.defaults().copyWith(
            title: titleText,
            description: descText,
            status: columnId,
            columnId: columnId,
            priority: created.priorityName,
            assignee: created.assigneeName,
            external: external,
            youtrack: FolioYouTrackIssueSnapshot(
              projectId: youtrackProjectId,
              projectShortName: youtrackProjectShortName,
              projectName: youtrackProjectShortName, // best effort
              stateName: created.stateName,
              priorityName: created.priorityName,
              assigneeName: created.assigneeName,
              subsystem: created.subsystemName,
              type: created.typeName,
              fixVersions: created.fixVersions,
              affectedVersions: created.affectedVersions,
              fixedInBuild: created.fixedInBuild,
              estimation: created.estimation,
              spentTime: created.spentTime,
            ),
          );

          // Insert the new task block into the page
          final blockId = 'task_${DateTime.now().microsecondsSinceEpoch}';
          final newBlock = FolioBlock(id: blockId, type: 'task', text: task.encode());
          widget.session.insertBlockAfter(
            pageId: page.id,
            afterBlockId: cfg.blockId,
            block: newBlock,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${isEs ? 'Error YouTrack' : 'YouTrack error'}: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _youtrackSyncBusy = false);
        }
        return;
      }
    }

    // Otherwise, create a standard local task in Folio for this column!
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final summaryCtrl = TextEditingController();
    final summary = await showDialog<String?>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(isEs ? 'Nueva tarea local' : 'New Local Task'),
        content: TextField(
          controller: summaryCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop<String?>(summaryCtrl.text),
            child: Text(isEs ? 'Crear' : l10n.add),
          ),
        ],
      ),
    );
    final title = summaryCtrl.text.trim();
    summaryCtrl.dispose();
    if (summary == null || title.isEmpty) return;

    final task = FolioTaskData.defaults().copyWith(
      title: title,
      status: columnId,
      columnId: columnId,
    );

    final blockId = 'task_${DateTime.now().microsecondsSinceEpoch}';
    final newBlock = FolioBlock(id: blockId, type: 'task', text: task.encode());
    widget.session.insertBlockAfter(
      pageId: page.id,
      afterBlockId: cfg.blockId,
      block: newBlock,
    );
    setState(() {});
  }

  Future<bool> _quickAddToYouTrack({
    required FolioPage page,
    required String kanbanBlockId,
    required String youtrackSourceId,
    required String defaultColumnId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final source = widget.session.youtrackSources.firstWhereOrNull(
      (s) => s.id == youtrackSourceId,
    );
    if (source == null) return false;
    if (source.type != YouTrackSourceType.project ||
        (source.projectId ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'Para crear tareas desde Kanban, usa una fuente de YouTrack de tipo Project.'
                : 'To create tasks from Kanban, use a YouTrack Project source.',
          ),
        ),
      );
      return false;
    }
    final connection = widget.session.youtrackConnections.firstWhereOrNull(
      (c) => c.id == source.connectionId,
    );
    if (connection == null) return false;

    final summaryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final summary = await showDialog<String?>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(isEs ? 'Nueva tarea en YouTrack' : 'New YouTrack Task'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: summaryCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.title,
                  hintText: 'e.g. Implement payment flow',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  hintText: 'Describe the task details...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
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
      final client = YouTrackApiClient(connection: connection);
      final created = await client.createIssue(
        projectId: source.projectId!.trim(),
        summary: normalized,
        description: desc.trim(),
      );
      final external = FolioExternalTaskLink(
        provider: 'youtrack',
        issueId: created.id,
        issueKey: created.idReadable,
        deployment: 'server',
        baseUrl: connection.baseUrl,
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
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'Tarea creada: ${created.idReadable}'
                : 'Task created: ${created.idReadable}',
          ),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isEs ? 'Error YouTrack' : 'YouTrack error'}: $e')),
      );
      return false;
    }
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
        title: Text(l10n.kanbanJiraNewIssue),
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
      if (!mounted) return true;
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
      if (!mounted) return false;
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
    setState(() {
      _openTask = _TaskRef(pageId: e.pageId, blockId: e.blockId);
      _detailsFullScreen = false;
    });
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
                          Builder(
                            builder: (ctx) {
                              final isJiraInstalled = AppStoreService.instance.isInstalled(FolioBuiltInApps.jiraId);
                              final isYouTrackInstalled = AppStoreService.instance.isInstalled(FolioBuiltInApps.youtrackId);
                              final isEs = Localizations.localeOf(ctx).languageCode == 'es';
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (isJiraInstalled) ...[
                                    Text(
                                      'Jira',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (ctx) {
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
                                              initialValue: selectedValue,
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
                                  ],
                                  if (isYouTrackInstalled) ...[
                                    Text(
                                      'YouTrack',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (ctx) {
                                        final sourcesById = <String, YouTrackSource>{};
                                        for (final s in widget.session.youtrackSources) {
                                          sourcesById[s.id] = s;
                                        }
                                        final sources = sourcesById.values.toList(
                                          growable: false,
                                        );
                                        final selected = (data.youtrackSourceId ?? '').trim();
                                        final selectedValue =
                                            selected.isEmpty ||
                                                !sourcesById.containsKey(selected)
                                            ? null
                                            : selected;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            DropdownButtonFormField<String?>(
                                              initialValue: selectedValue,
                                              decoration: InputDecoration(
                                                labelText: isEs
                                                    ? 'Fuente YouTrack (opcional)'
                                                    : 'YouTrack source (optional)',
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
                                                    youtrackSourceId:
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
                                                      ? 'Auto-importar desde YouTrack'
                                                      : 'Auto-import from YouTrack',
                                                ),
                                                value: data.youtrackAutoImport,
                                                onChanged: (v) {
                                                  _persistKanbanData(
                                                    latestPage.id,
                                                    latestCfg.blockId,
                                                    data.copyWith(youtrackAutoImport: v),
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
                                                value: data.youtrackCreateIssuesOnQuickAdd,
                                                onChanged: (v) {
                                                  _persistKanbanData(
                                                    latestPage.id,
                                                    latestCfg.blockId,
                                                    data.copyWith(
                                                      youtrackCreateIssuesOnQuickAdd: v,
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
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.sync_rounded),
              ),
            if ((data.jiraSourceId ?? '').trim().isNotEmpty)
              const SizedBox(width: FolioSpace.xs),
            if ((data.youtrackSourceId ?? '').trim().isNotEmpty)
              IconButton(
                tooltip: isEs
                    ? 'Sincronizar YouTrack (pull + push)'
                    : 'Sync YouTrack (pull + push)',
                onPressed: _youtrackSyncBusy
                    ? null
                    : () => _syncYouTrack(youtrackSourceId: data.youtrackSourceId!.trim()),
                icon: _youtrackSyncBusy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.sync_rounded, color: Colors.orange),
              ),
            if ((data.youtrackSourceId ?? '').trim().isNotEmpty)
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
              child: _TaskDetailsPanel(
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
        subtitle.write(_fmtDue(e.dueDate!));
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

    Widget? youtrackBadge() {
      if (youtrackState == null) return null;
      if (youtrackState == 'ok') return null;
      final isEs =
          Localizations.localeOf(context).languageCode ==
          'es';
      Color c() => switch (youtrackState) {
        'conflict' => scheme.error,
        'needsPush' => scheme.tertiary,
        'needsPull' => scheme.secondary,
        _ => scheme.primary,
      };
      String label() => switch (youtrackState) {
        'conflict' => isEs ? 'Conflicto' : 'Conflict',
        'needsPush' =>
          isEs ? 'Pendiente push' : 'Needs push',
        'needsPull' =>
          isEs ? 'Pendiente pull' : 'Needs pull',
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
      final isEs = Localizations.localeOf(context).languageCode == 'es';

      for (final key in sortedKeys) {
        final groupEntries = grouped[key] ?? [];
        final displayName = key.isEmpty
            ? (isEs ? 'Tarjetas sin categoría' : 'Uncategorized cards')
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

class _TaskDetailsPanel extends StatelessWidget {
  const _TaskDetailsPanel({
    required this.session,
    required this.taskRef,
    required this.onClose,
    required this.onOpenTaskRef,
    required this.isFullScreen,
    required this.onToggleFullScreen,
  });

  final VaultSession session;
  final _TaskRef taskRef;
  final VoidCallback onClose;
  final void Function(_TaskRef ref) onOpenTaskRef;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 10,
      borderRadius: BorderRadius.circular(isFullScreen ? 0 : FolioRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: _TaskDetailsContent(
        session: session,
        taskRef: taskRef,
        onClose: onClose,
        onOpenTaskRef: onOpenTaskRef,
        isFullScreen: isFullScreen,
        onToggleFullScreen: onToggleFullScreen,
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
          isFullScreen: false,
          onToggleFullScreen: null,
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
    required this.isFullScreen,
    required this.onToggleFullScreen,
  });

  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;

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
  late final TextEditingController _ytSubsystemCtrl = TextEditingController();
  late final TextEditingController _ytTypeCtrl = TextEditingController();
  late final TextEditingController _ytAssigneeCtrl = TextEditingController();
  late final TextEditingController _ytFixVersionsCtrl = TextEditingController();
  late final TextEditingController _ytAffectedVersionsCtrl = TextEditingController();
  late final TextEditingController _ytFixedInBuildCtrl = TextEditingController();
  late final TextEditingController _ytEstimationCtrl = TextEditingController();
  late final TextEditingController _ytSpentTimeCtrl = TextEditingController();
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

   var _youtrackBusy = false;
   String? _youtrackError;
   YouTrackIssue? _youtrackIssue;
   final _youtrackNewCommentCtrl = TextEditingController();
   bool _youtrackAutoPulledOnce = false;

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
    _ytSubsystemCtrl.dispose();
    _ytTypeCtrl.dispose();
    _ytAssigneeCtrl.dispose();
    _ytFixVersionsCtrl.dispose();
    _ytAffectedVersionsCtrl.dispose();
    _ytFixedInBuildCtrl.dispose();
    _ytEstimationCtrl.dispose();
    _ytSpentTimeCtrl.dispose();
    _jiraNewCommentCtrl.dispose();
    _jiraWorklogMinutesCtrl.dispose();
    _youtrackNewCommentCtrl.dispose();
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
    // YouTrack snapshot fields
    final yt = parsed.youtrack;
    if (yt != null) {
      if (!keepUserTextIfSame || _ytSubsystemCtrl.text != (yt.subsystem ?? '')) _ytSubsystemCtrl.text = yt.subsystem ?? '';
      if (!keepUserTextIfSame || _ytTypeCtrl.text != (yt.type ?? '')) _ytTypeCtrl.text = yt.type ?? '';
      if (!keepUserTextIfSame || _ytAssigneeCtrl.text != (yt.assigneeName ?? '')) _ytAssigneeCtrl.text = yt.assigneeName ?? '';
      if (!keepUserTextIfSame || _ytFixVersionsCtrl.text != (yt.fixVersions ?? '')) _ytFixVersionsCtrl.text = yt.fixVersions ?? '';
      if (!keepUserTextIfSame || _ytAffectedVersionsCtrl.text != (yt.affectedVersions ?? '')) _ytAffectedVersionsCtrl.text = yt.affectedVersions ?? '';
      if (!keepUserTextIfSame || _ytFixedInBuildCtrl.text != (yt.fixedInBuild ?? '')) _ytFixedInBuildCtrl.text = yt.fixedInBuild ?? '';
      if (!keepUserTextIfSame || _ytEstimationCtrl.text != (yt.estimation ?? '')) _ytEstimationCtrl.text = yt.estimation ?? '';
      if (!keepUserTextIfSame || _ytSpentTimeCtrl.text != (yt.spentTime ?? '')) _ytSpentTimeCtrl.text = yt.spentTime ?? '';
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
    // Best-effort: auto pull YouTrack details once per task open.
    if (!_youtrackAutoPulledOnce &&
        ext != null &&
        ext.provider == 'youtrack' &&
        ext.issueId.trim().isNotEmpty) {
      _youtrackAutoPulledOnce = true;
      unawaited(_youtrackRefresh());
    }
  }

  void _emit(FolioTaskData next) {
    // If this task is linked to Jira or YouTrack, mark it dirty for incremental push.
    final ext = next.external;
    if (ext != null && (ext.provider == 'jira' || ext.provider == 'youtrack')) {
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
    final l10n = AppLocalizations.of(context);
    final confirmText = data.external?.provider == 'jira' || data.external?.provider == 'youtrack'
        ? (isEs
              ? 'Esta acción borrará la tarea en Folio y también el issue en ${data.external?.provider == 'jira' ? 'Jira' : 'YouTrack'} (incluyendo subtareas vinculadas). ¿Continuar?'
              : 'This will delete the task in Folio and also the issue in ${data.external?.provider == 'jira' ? 'Jira' : 'YouTrack'} (including linked subtasks). Continue?')
        : (isEs
              ? '¿Borrar la tarea en Folio?'
              : 'Delete this task in Folio?');

    final confirm = await FolioDialog.confirm(
      context,
      title: Text(l10n.kanbanDeleteTaskTitle),
      content: Text(confirmText),
      confirmLabel: l10n.kanbanDeleteTaskButton,
      destructive: true,
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

      // Delete in external provider where linked.
      for (final blockId in toDeleteBlockIds) {
        final blk = page?.blocks.firstWhereOrNull((b) => b.id == blockId);
        if (blk == null) continue;
        final t = FolioTaskData.tryParse(blk.text);
        final ext = t?.external;
        if (ext == null) continue;

        if (ext.provider == 'jira') {
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
        } else if (ext.provider == 'youtrack') {
          final client = _youtrackClientFor(ext);
          if (client == null) {
            throw StateError(
              isEs
                  ? 'No se encontró la conexión YouTrack para borrar el issue.'
                  : 'YouTrack connection not found to delete issue.',
            );
          }
          final issueIdOrKey = (ext.issueKey ?? '').trim().isNotEmpty
              ? ext.issueKey!.trim()
              : ext.issueId;
          await client.deleteIssue(issueIdOrKey);
        }
      }

      // Delete locally (single undo step).
      widget.session.removeBlocksIfMultiple(
        widget.taskRef.pageId,
        toDeleteBlockIds,
      );

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.kanbanTaskDeleted)),
      );
      widget.onClose();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_formatJiraError(e, l10n, isEs: isEs))),
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

  YouTrackApiClient? _youtrackClientFor(FolioExternalTaskLink ext) {
    final conn = widget.session.youtrackConnections.firstWhereOrNull(
      (c) => (c.baseUrl).trim().toLowerCase() == (ext.baseUrl ?? '').trim().toLowerCase()
    );
    if (conn == null) return null;
    return YouTrackApiClient(connection: conn);
  }

  YouTrackApiClient? _youtrackClientOrSetError(FolioExternalTaskLink ext) {
    final client = _youtrackClientFor(ext);
    if (client != null) return client;
    setState(() {
      _youtrackError = Localizations.localeOf(context).languageCode == 'es'
          ? 'No se encontró la conexión YouTrack para esta tarea. Re-conecta YouTrack en Ajustes → Integraciones.'
          : 'YouTrack connection not found for this task. Reconnect YouTrack in Settings → Integrations.';
    });
    return null;
  }

  Future<void> _youtrackRefresh() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'youtrack') return;
    final client = _youtrackClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _youtrackBusy = true;
      _youtrackError = null;
    });
    try {
      final issue = await client.getIssue(ext.issueKey ?? ext.issueId);
      setState(() => _youtrackIssue = issue);
    } catch (e) {
      setState(() => _youtrackError = '$e');
    } finally {
      if (mounted) setState(() => _youtrackBusy = false);
    }
  }

  Future<void> _youtrackAddComment() async {
    final text = _youtrackNewCommentCtrl.text.trim();
    if (text.isEmpty) return;
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'youtrack') return;
    final client = _youtrackClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _youtrackBusy = true;
      _youtrackError = null;
    });
    try {
      await client.addComment(
        issueIdOrKey: ext.issueKey ?? ext.issueId,
        text: text,
      );
      _youtrackNewCommentCtrl.clear();
      await _youtrackRefresh();
    } catch (e) {
      setState(() => _youtrackError = '$e');
    } finally {
      if (mounted) setState(() => _youtrackBusy = false);
    }
  }

  Future<void> _youtrackResolveKeepRemote() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'youtrack') return;
    final client = _youtrackClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _youtrackBusy = true;
      _youtrackError = null;
    });
    try {
      final remote = await client.getIssue(ext.issueKey ?? ext.issueId);
      final folioPriority = _mapYouTrackPriorityToFolio(remote.priorityName);
      final folioStatus = _mapYouTrackStatusToFolio(remote.stateName);

      final nextSnapshot = FolioYouTrackIssueSnapshot(
        projectId: remote.projectId,
        projectShortName: remote.projectShortName,
        stateName: remote.stateName,
        priorityName: remote.priorityName,
        assigneeName: remote.assigneeName,
        subsystem: remote.subsystemName,
        commentCount: remote.commentCount,
        attachmentCount: remote.attachmentCount,
        type: remote.typeName,
        fixVersions: remote.fixVersions,
        affectedVersions: remote.affectedVersions,
        fixedInBuild: remote.fixedInBuild,
        estimation: remote.estimation,
        spentTime: remote.spentTime,
      );

      final nextExternal = ext.copyWith(
        remoteUpdatedAtMs: remote.updatedAtMs,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        syncState: 'ok',
      );

      final next = data.copyWith(
        title: remote.summary.trim(),
        description: remote.description,
        priority: folioPriority,
        status: folioStatus,
        columnId: folioStatus,
        assignee: remote.assigneeName,
        external: nextExternal,
        youtrack: nextSnapshot,
      );

      _emit(next);
      setState(() {
        _youtrackIssue = remote;
      });
    } catch (e) {
      setState(() => _youtrackError = '$e');
    } finally {
      if (mounted) setState(() => _youtrackBusy = false);
    }
  }

  Future<void> _youtrackResolveKeepLocalForcePush() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'youtrack') return;
    final client = _youtrackClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _youtrackBusy = true;
      _youtrackError = null;
    });
    try {
      final youTrackPriority = _mapPriorityToYouTrack(data.priority);
      final desiredState = _mapStatusToYouTrack(data.columnId ?? data.status);

      await client.updateIssueFields(
        issueIdOrKey: ext.issueKey ?? ext.issueId,
        summary: data.title.trim(),
        description: data.description,
        stateName: desiredState,
        priorityName: youTrackPriority,
      );

      final remote = await client.getIssue(ext.issueKey ?? ext.issueId);

      final nextSnapshot = FolioYouTrackIssueSnapshot(
        projectId: remote.projectId,
        projectShortName: remote.projectShortName,
        stateName: remote.stateName,
        priorityName: remote.priorityName,
        assigneeName: remote.assigneeName,
        subsystem: remote.subsystemName,
        commentCount: remote.commentCount,
        attachmentCount: remote.attachmentCount,
        type: remote.typeName,
        fixVersions: remote.fixVersions,
        affectedVersions: remote.affectedVersions,
        fixedInBuild: remote.fixedInBuild,
        estimation: remote.estimation,
        spentTime: remote.spentTime,
      );

      final nextExternal = ext.copyWith(
        remoteUpdatedAtMs: remote.updatedAtMs,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        syncState: 'ok',
      );

      _emit(data.copyWith(
        priority: remote.priorityName,
        assignee: remote.assigneeName,
        external: nextExternal,
        youtrack: nextSnapshot,
      ));
      setState(() {
        _youtrackIssue = remote;
      });
    } catch (e) {
      setState(() => _youtrackError = '$e');
    } finally {
      if (mounted) setState(() => _youtrackBusy = false);
    }
  }

  String? _mapYouTrackPriorityToFolio(String? youtrackPriority) {
    return youtrackPriority;
  }

  String? _mapPriorityToYouTrack(String? folioPriority) {
    final p = (folioPriority ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    switch (p) {
      case 'high':
        return 'Major';
      case 'medium':
        return 'Normal';
      case 'low':
      case 'lowest':
        return 'Minor';
      default:
        if (p == 'showstopper') return 'Showstopper';
        if (p == 'critical') return 'Critical';
        if (p == 'major') return 'Major';
        if (p == 'normal') return 'Normal';
        if (p == 'minor') return 'Minor';
        if (p == 'minimal') return 'Minimal';
        return folioPriority;
    }
  }

  String _mapYouTrackStatusToFolio(String? youtrackState) {
    final state = (youtrackState ?? '').trim().toLowerCase();
    if (state.isEmpty) return 'todo';
    if (state.contains('fixed') ||
        state.contains('done') ||
        state.contains('complete') ||
        state.contains('resolved') ||
        state.contains('closed')) {
      return 'done';
    }
    if (state.contains('progress') ||
        state.contains('curso') ||
        state.contains('haciendo')) {
      return 'in_progress';
    }
    return 'todo';
  }

  String _mapStatusToYouTrack(String folioStatus) {
    switch (folioStatus) {
      case 'done':
        return 'Fixed';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'To Do';
    }
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
    final l10n = AppLocalizations.of(context);
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.kanbanForcePushTitle),
      content: Text(
        isEs
            ? 'Esto sobrescribirá en Jira los cambios remotos detectados para este issue con lo que tienes en Folio. ¿Continuar?'
            : 'This will overwrite the remote Jira changes for this issue with your Folio version. Continue?',
      ),
      confirmLabel: l10n.kanbanForcePushButton,
      destructive: true,
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

  Uri? _youtrackBrowseUri(FolioExternalTaskLink ext) {
    if (ext.provider != 'youtrack') return null;
    final issueKey = (ext.issueKey ?? '').trim();
    final target = issueKey.isNotEmpty ? issueKey : ext.issueId.trim();
    if (target.isEmpty) return null;
    final base = (ext.baseUrl ?? '').trim();
    final baseUri = Uri.tryParse(base);
    if (baseUri == null) return null;
    return baseUri.replace(path: '${baseUri.path}/issue/$target');
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
    final kanbanCols = widget.session.kanbanDataForPage(widget.taskRef.pageId).columns;
    final allowedColIds = kanbanCols.map((c) => c.id).toSet();
    final isEs = Localizations.localeOf(context).languageCode == 'es';

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
          : Builder(builder: (context) {
              // ──────────────────────────────────────────────────────────────
              // Build reusable content blocks
              // ──────────────────────────────────────────────────────────────

              // Header row (title bar + action icons)
              final headerRow = Row(
                children: [
                  const Icon(Icons.task_alt_rounded),
                  const SizedBox(width: FolioSpace.sm),
                  Expanded(
                    child: Text(
                      isEs ? 'Detalle de la tarea' : 'Task Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isEs ? 'Borrar tarea' : l10n.delete,
                    onPressed: _deleteBusy ? null : _deleteTaskWithJiraIfLinked,
                    icon: _deleteBusy
                        ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                        : const Icon(Icons.delete_outline_rounded),
                  ),
                  if (widget.onToggleFullScreen != null)
                    IconButton(
                      tooltip: widget.isFullScreen
                          ? (isEs ? 'Restaurar tamaño' : 'Restore size')
                          : (isEs ? 'Pantalla completa' : 'Full screen'),
                      onPressed: widget.onToggleFullScreen,
                      icon: Icon(
                        widget.isFullScreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                      ),
                    ),
                  IconButton(
                    tooltip: isEs ? 'Cerrar' : l10n.cancel,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              );

              // YouTrack link banner
              final ytBanner = data.external?.provider == 'youtrack'
                  ? Builder(
                      builder: (ctx) {
                        final isEs2 = Localizations.localeOf(ctx).languageCode == 'es';
                        final ext = data.external!;
                        final uri = _youtrackBrowseUri(ext);
                        final label = (ext.issueKey ?? '').trim().isNotEmpty == true
                            ? ext.issueKey!.trim()
                            : ext.issueId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(FolioRadius.md),
                            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.grid_view_rounded, size: 18, color: Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'YouTrack · $label',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: uri == null
                                    ? null
                                    : () async { await launchUrl(uri, mode: LaunchMode.externalApplication); },
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: Text(isEs2 ? 'Abrir' : l10n.taskHubOpen),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : null;

              // Jira link banner
              final jiraBanner = data.external?.provider == 'jira'
                  ? Builder(
                      builder: (ctx) {
                        final isEs2 = Localizations.localeOf(ctx).languageCode == 'es';
                        final ext = data.external!;
                        final uri = _jiraBrowseUri(ext);
                        final label = (ext.issueKey ?? '').trim().isNotEmpty == true
                            ? ext.issueKey!.trim()
                            : ext.issueId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(FolioRadius.md),
                            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
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
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: uri == null
                                    ? null
                                    : () async { await launchUrl(uri, mode: LaunchMode.externalApplication); },
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: Text(isEs2 ? 'Abrir' : l10n.taskHubOpen),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : null;

              // Title field
              final titleField = TextField(
                controller: _titleCtrl,
                maxLines: 2,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: data.blocked ? scheme.error : null,
                  decoration: data.blocked ? TextDecoration.lineThrough : null,
                  decorationColor: data.blocked ? scheme.error : null,
                ),
                decoration: InputDecoration(labelText: l10n.title, border: const OutlineInputBorder()),
                onChanged: (v) => _emit(data.copyWith(title: v.trim())),
              );

              // Description field
              final descField = TextField(
                controller: _descCtrl,
                minLines: 2,
                maxLines: 8,
                decoration: InputDecoration(labelText: l10n.description, border: const OutlineInputBorder()),
                onChanged: (v) => _emit(data.copyWith(description: v)),
              );

              // Priority + Status row
              final priorityStatusRow = Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (dropdownCtx) {
                        final ext = data.external;
                        final isYouTrack = ext?.provider == 'youtrack';
                        final isJira = ext?.provider == 'jira';
                        final List<DropdownMenuItem<String?>> priorityItems;
                        if (isYouTrack) {
                          priorityItems = [
                            DropdownMenuItem<String?>(value: null, child: Text(l10n.none)),
                            const DropdownMenuItem<String?>(value: 'Showstopper', child: Text('Showstopper')),
                            const DropdownMenuItem<String?>(value: 'Critical', child: Text('Critical')),
                            const DropdownMenuItem<String?>(value: 'Major', child: Text('Major')),
                            const DropdownMenuItem<String?>(value: 'Normal', child: Text('Normal')),
                            const DropdownMenuItem<String?>(value: 'Minor', child: Text('Minor')),
                            const DropdownMenuItem<String?>(value: 'Minimal', child: Text('Minimal')),
                          ];
                        } else if (isJira) {
                          priorityItems = [
                            DropdownMenuItem<String?>(value: null, child: Text(l10n.none)),
                            const DropdownMenuItem<String?>(value: 'Highest', child: Text('Highest')),
                            const DropdownMenuItem<String?>(value: 'High', child: Text('High')),
                            const DropdownMenuItem<String?>(value: 'Medium', child: Text('Medium')),
                            const DropdownMenuItem<String?>(value: 'Low', child: Text('Low')),
                            const DropdownMenuItem<String?>(value: 'Lowest', child: Text('Lowest')),
                          ];
                        } else {
                          priorityItems = [
                            DropdownMenuItem<String?>(value: null, child: Text(l10n.none)),
                            const DropdownMenuItem<String?>(value: 'lowest', child: Text('Lowest')),
                            DropdownMenuItem<String?>(value: 'low', child: Text('Low')),
                            DropdownMenuItem<String?>(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem<String?>(value: 'high', child: Text('High')),
                            const DropdownMenuItem<String?>(value: 'highest', child: Text('Highest')),
                          ];
                        }
                        final hasSelected = priorityItems.any((item) => item.value == data.priority);
                        if (!hasSelected && data.priority != null) {
                          priorityItems.add(DropdownMenuItem<String?>(value: data.priority, child: Text(data.priority!)));
                        }
                        return DropdownButtonFormField<String?>(
                          initialValue: data.priority,
                          decoration: InputDecoration(labelText: l10n.priority, border: const OutlineInputBorder()),
                          items: priorityItems,
                          onChanged: (v) => _emit(data.copyWith(priority: v)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final eff = data.effectiveColumnId(allowedColumnIds: allowedColIds);
                        final colMenuItems = <DropdownMenuItem<String>>[
                          for (final c in kanbanCols)
                            DropdownMenuItem(value: c.id, child: Text(folioKanbanColumnLabel(c, l10n))),
                        ];
                        var dropdownVal = eff;
                        if (eff.isNotEmpty && !allowedColIds.contains(eff)) {
                          colMenuItems.insert(0, DropdownMenuItem(value: eff, child: Text(eff)));
                        }
                        if (colMenuItems.isNotEmpty && !colMenuItems.any((i) => i.value == dropdownVal)) {
                          dropdownVal = colMenuItems.first.value!;
                        }
                        return DropdownButtonFormField<String>(
                          key: ValueKey('task-col-$dropdownVal-${kanbanCols.map((c) => c.id).join('|')}'),
                          // ignore: deprecated_member_use
                          value: dropdownVal,
                          decoration: InputDecoration(labelText: l10n.status, border: const OutlineInputBorder()),
                          items: colMenuItems,
                          onChanged: (v) { if (v != null) _emit(data.withKanbanColumn(v)); },
                        );
                      },
                    ),
                  ),
                ],
              );

              // Blocked toggle + reason
              final blockedSection = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      decoration: InputDecoration(labelText: l10n.taskBlockedReason, border: const OutlineInputBorder()),
                      onChanged: (v) => _emit(data.copyWith(blockedReason: v)),
                    ),
                  ],
                ],
              );

              // Dates row
              final datesRow = Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: true),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(data.startDate == null ? l10n.startDate : '${l10n.startDate}: ${data.startDate}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: false),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(data.dueDate == null ? l10n.dueDate : '${l10n.dueDate}: ${_fmtDue(data.dueDate!)}'),
                    ),
                  ),
                ],
              );

              // Recurrence + reminder row
              final recurrenceRow = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: data.recurrence,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.taskRecurrenceLabel,
                        prefixIcon: const Icon(Icons.repeat_rounded, size: 20),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(l10n.taskRecurrenceNone)),
                        DropdownMenuItem<String?>(value: 'daily', child: Text(l10n.taskRecurrenceDaily)),
                        DropdownMenuItem<String?>(value: 'weekly', child: Text(l10n.taskRecurrenceWeekly)),
                        DropdownMenuItem<String?>(value: 'monthly', child: Text(l10n.taskRecurrenceMonthly)),
                        DropdownMenuItem<String?>(value: 'yearly', child: Text(l10n.taskRecurrenceYearly)),
                      ],
                      onChanged: (v) => _emit(data.copyWith(recurrence: v)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: data.reminderEnabled ? l10n.taskReminderOnTooltip : l10n.taskReminderTooltip,
                    child: IconButton.filledTonal(
                      onPressed: () => _emit(data.copyWith(reminderEnabled: !data.reminderEnabled)),
                      style: IconButton.styleFrom(
                        backgroundColor: data.reminderEnabled ? Theme.of(context).colorScheme.primaryContainer : null,
                      ),
                      icon: Icon(data.reminderEnabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                    ),
                  ),
                ],
              );

              // Time spent field
              final timeField = TextField(
                controller: _timeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.timeSpentMinutes, border: const OutlineInputBorder()),
                onChanged: (v) => _emit(data.copyWith(timeSpentMinutes: int.tryParse(v.trim()))),
              );

              // YouTrack custom fields editor
              final isYouTrack = data.external?.provider == 'youtrack';
              final ytFieldsSection = isYouTrack
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 24),
                        Text(
                          isEs ? 'Campos YouTrack' : 'YouTrack Fields',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytTypeCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Tipo' : 'Type',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.category_outlined, size: 18),
                          ),
                          onChanged: (v) => _emit(data.copyWith(youtrack: data.youtrack?.copyWith(type: v.trim()))),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytAssigneeCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Asignado' : 'Assignee',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                          ),
                          onChanged: (v) {
                            final trimmed = v.trim();
                            _emit(data.copyWith(
                              assignee: trimmed.isEmpty ? null : trimmed,
                              youtrack: data.youtrack?.copyWith(assigneeName: trimmed),
                            ));
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytSubsystemCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Subsistema' : 'Subsystem',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.account_tree_outlined, size: 18),
                          ),
                          onChanged: (v) => _emit(data.copyWith(youtrack: data.youtrack?.copyWith(subsystem: v.trim()))),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytFixVersionsCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Solucionar versiones' : 'Fix Versions',
                            hintText: isEs ? 'p. ej. 1.0, 2.3' : 'e.g. 1.0, 2.3',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          ),
                          onChanged: (v) => _emit(data.copyWith(youtrack: data.youtrack?.copyWith(fixVersions: v.trim()))),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytAffectedVersionsCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Versiones afectadas' : 'Affected Versions',
                            hintText: isEs ? 'p. ej. 0.9, 1.0' : 'e.g. 0.9, 1.0',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.bug_report_outlined, size: 18),
                          ),
                          onChanged: (v) => _emit(data.copyWith(youtrack: data.youtrack?.copyWith(affectedVersions: v.trim()))),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytFixedInBuildCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Solucionado en el build' : 'Fixed in Build',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.build_outlined, size: 18),
                          ),
                          onChanged: (v) => _emit(data.copyWith(youtrack: data.youtrack?.copyWith(fixedInBuild: v.trim()))),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytEstimationCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Estimación' : 'Estimation',
                            hintText: isEs ? 'p. ej. 2h 30m' : 'e.g. 2h 30m',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.timer_outlined, size: 18),
                          ),
                          onChanged: (v) => _emit(data.copyWith(youtrack: data.youtrack?.copyWith(estimation: v.trim()))),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytSpentTimeCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Tiempo empleado' : 'Spent Time',
                            hintText: isEs ? 'p. ej. 1h 15m' : 'e.g. 1h 15m',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.hourglass_bottom_rounded, size: 18),
                          ),
                          onChanged: (v) => _emit(data.copyWith(youtrack: data.youtrack?.copyWith(spentTime: v.trim()))),
                        ),
                      ],
                    )
                  : null;

              // YouTrack sync/comments section
              final ytDetailsSection = isYouTrack
                  ? _YouTrackDetailsSection(
                      scheme: scheme,
                      data: data,
                      busy: _youtrackBusy,
                      error: _youtrackError,
                      issue: _youtrackIssue,
                      newCommentCtrl: _youtrackNewCommentCtrl,
                      onRefresh: _youtrackRefresh,
                      onResolveKeepRemote: _youtrackResolveKeepRemote,
                      onResolveKeepLocalForcePush: _youtrackResolveKeepLocalForcePush,
                      onAddComment: _youtrackAddComment,
                    )
                  : null;

              // Jira sync/comments section
              final jiraDetailsSection = data.external?.provider == 'jira'
                  ? _JiraDetailsSection(
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
                      onResolveKeepLocalForcePush: _jiraResolveKeepLocalForcePush,
                      onLoadComments: _jiraLoadComments,
                      onAddComment: _jiraAddComment,
                      onLoadWorklogs: _jiraLoadWorklogs,
                      onAddWorklog: _jiraAddWorklog,
                    )
                  : null;

              // Subtasks section
              final subtasksSection = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.subtasks,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _childTasks.length,
                          separatorBuilder: (context, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final child = _childTasks[i];
                            final s = child.data;
                            return Card(
                              elevation: 0,
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => widget.onOpenTaskRef(
                                  _TaskRef(pageId: widget.taskRef.pageId, blockId: child.blockId),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: s.status == 'done',
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (v) {
                                          final next = s.copyWith(status: v == true ? 'done' : 'todo');
                                          widget.session.updateBlockText(widget.taskRef.pageId, child.blockId, next.encode());
                                        },
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          key: ValueKey('detail_subtask_${child.blockId}'),
                                          initialValue: s.title,
                                          decoration: InputDecoration(labelText: l10n.title, border: const OutlineInputBorder()),
                                          onChanged: (v) {
                                            final next = s.copyWith(title: v);
                                            widget.session.updateBlockText(widget.taskRef.pageId, child.blockId, next.encode());
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: l10n.taskHubOpen,
                                        onPressed: () => widget.onOpenTaskRef(
                                          _TaskRef(pageId: widget.taskRef.pageId, blockId: child.blockId),
                                        ),
                                        icon: const Icon(Icons.open_in_new_rounded),
                                      ),
                                      IconButton(
                                        tooltip: l10n.delete,
                                        onPressed: () {
                                          widget.session.removeBlockIfMultiple(widget.taskRef.pageId, child.blockId);
                                        },
                                        icon: const Icon(Icons.delete_outline_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              );

              // ──────────────────────────────────────────────────────────────
              // FULL-SCREEN: Two-column layout
              // ──────────────────────────────────────────────────────────────
              if (widget.isFullScreen) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerRow,
                      const SizedBox(height: FolioSpace.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Left column: 62% — main content ──────────────
                          Expanded(
                            flex: 62,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (ytBanner != null) ytBanner,
                                if (jiraBanner != null) jiraBanner,
                                titleField,
                                const SizedBox(height: 10),
                                descField,
                                const SizedBox(height: FolioSpace.md),
                                subtasksSection,
                                if (ytDetailsSection != null) ...[
                                  const SizedBox(height: 10),
                                  ytDetailsSection,
                                ],
                                if (jiraDetailsSection != null) ...[
                                  const SizedBox(height: 10),
                                  jiraDetailsSection,
                                ],
                                const SizedBox(height: FolioSpace.md),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // ── Right sidebar: 38% — metadata ────────────────
                          Expanded(
                            flex: 38,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(FolioRadius.md),
                                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.30)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    isEs ? 'Propiedades' : 'Properties',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 12),
                                  priorityStatusRow,
                                  const SizedBox(height: 10),
                                  blockedSection,
                                  const SizedBox(height: 10),
                                  datesRow,
                                  const SizedBox(height: 10),
                                  recurrenceRow,
                                  const SizedBox(height: 10),
                                  timeField,
                                  if (ytFieldsSection != null) ytFieldsSection,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              // ──────────────────────────────────────────────────────────────
              // COMPACT: Single-column layout (original)
              // ──────────────────────────────────────────────────────────────
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerRow,
                    const SizedBox(height: FolioSpace.sm),
                    if (ytBanner != null) ytBanner,
                    if (ytDetailsSection != null) ...[
                      ytDetailsSection,
                      const SizedBox(height: 10),
                    ],
                    if (jiraBanner != null) jiraBanner,
                    if (jiraDetailsSection != null) ...[
                      jiraDetailsSection,
                      const SizedBox(height: 10),
                    ],
                    titleField,
                    const SizedBox(height: 10),
                    descField,
                    const SizedBox(height: 10),
                    priorityStatusRow,
                    const SizedBox(height: 10),
                    blockedSection,
                    const SizedBox(height: 10),
                    datesRow,
                    const SizedBox(height: 10),
                    recurrenceRow,
                    const SizedBox(height: 10),
                    timeField,
                    if (ytFieldsSection != null) ytFieldsSection,
                    const SizedBox(height: FolioSpace.md),
                    subtasksSection,
                    const SizedBox(height: FolioSpace.md),
                  ],
                ),
              );
          }),
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
    final l10n = AppLocalizations.of(context);
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
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.kanbanPull),
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

class _YouTrackDetailsSection extends StatelessWidget {
  const _YouTrackDetailsSection({
    required this.scheme,
    required this.data,
    required this.busy,
    required this.error,
    required this.issue,
    required this.newCommentCtrl,
    required this.onRefresh,
    required this.onResolveKeepRemote,
    required this.onResolveKeepLocalForcePush,
    required this.onAddComment,
  });

  final ColorScheme scheme;
  final FolioTaskData data;
  final bool busy;
  final String? error;
  final YouTrackIssue? issue;
  final TextEditingController newCommentCtrl;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onResolveKeepRemote;
  final Future<void> Function() onResolveKeepLocalForcePush;
  final Future<void> Function() onAddComment;

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final ext = data.external!;
    final snap = data.youtrack;
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
              const Icon(Icons.grid_view_rounded, size: 18, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEs ? 'YouTrack' : 'YouTrack',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              pill(state),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onRefresh,
                icon: busy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isEs ? 'Actualizar' : 'Refresh'),
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
                        ? 'Conflicto: hubo cambios en YouTrack y en Folio.'
                        : 'Conflict: there were changes in YouTrack and Folio.',
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

                      Widget diffRow(String label, String folio, String yt) {
                        final same = folio.trim() == yt.trim();
                        final folioText = folio.trim().isEmpty ? '—' : folio.trim();
                        final ytText = yt.trim().isEmpty ? '—' : yt.trim();
                        final baseStyle = Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer.withValues(alpha: 0.92),
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
                                  ? scheme.outlineVariant.withValues(alpha: 0.35)
                                  : scheme.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                label,
                                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Folio: $folioText',
                                style: same ? baseStyle : hi,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'YouTrack: $ytText',
                                style: baseStyle,
                              ),
                            ],
                          ),
                        );
                      }

                      final yt = issue;
                      if (yt == null) {
                        return Text(
                          isEs
                              ? 'Pulsa Actualizar para cargar el estado remoto y ver las diferencias.'
                              : 'Press Refresh to load remote state and see differences.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer.withValues(alpha: 0.9),
                          ),
                        );
                      }

                      final localTitle = norm(data.title);
                      final remoteTitle = norm(yt.summary);
                      final localDesc = cut(norm(data.description), max: 140);
                      final remoteDesc = cut(norm(yt.description), max: 140);
                      final localPriority = norm(data.priority);
                      final remotePriority = norm(yt.priorityName);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          diffRow(isEs ? 'Título' : 'Title', localTitle, remoteTitle),
                          const SizedBox(height: 8),
                          diffRow(isEs ? 'Descripción' : 'Description', localDesc, remoteDesc),
                          const SizedBox(height: 8),
                          diffRow(isEs ? 'Prioridad' : 'Priority', localPriority, remotePriority),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onResolveKeepRemote,
                                  child: Text(isEs ? 'Mantener YouTrack' : 'Keep YouTrack'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: onResolveKeepLocalForcePush,
                                  child: Text(isEs ? 'Forzar Folio' : 'Force Folio'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          // Snapshot info
          Row(
            children: [
              if (snap?.stateName != null) ...[
                _Tag(label: '${isEs ? "Estado" : "State"}: ${snap!.stateName}'),
                const SizedBox(width: 6),
              ],
              if (snap?.priorityName != null) ...[
                _Tag(label: '${isEs ? "Prioridad" : "Priority"}: ${snap!.priorityName}'),
                const SizedBox(width: 6),
              ],
              if (snap?.assigneeName != null) ...[
                _Tag(label: '${isEs ? "Asignado" : "Assignee"}: ${snap!.assigneeName}'),
              ],
            ],
          ),
          const Divider(height: 24),
          Text(
            isEs ? 'Comentarios YouTrack' : 'YouTrack Comments',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (issue != null && issue!.comments.isNotEmpty) ...[
            for (final c in issue!.comments)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.authorName.isEmpty ? 'YouTrack User' : c.authorName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          DateTime.fromMillisecondsSinceEpoch(c.createdMs).toString().substring(0, 16),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.text, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ] else
            Text(
              isEs ? 'Sin comentarios o no cargados.' : 'No comments or not loaded.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newCommentCtrl,
                  decoration: InputDecoration(
                    hintText: isEs ? 'Añadir comentario...' : 'Add a comment...',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: busy ? null : onAddComment,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}
