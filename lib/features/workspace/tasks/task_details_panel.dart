import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_kanban_data.dart';
import '../../../models/folio_task_data.dart';
import '../../../models/folio_page.dart';
import '../../../models/jira_integration_state.dart';
import '../../../session/vault_session.dart';
import '../../../services/jira/jira_api_client.dart';
import '../../../services/jira/jira_sync_service.dart';
import '../../../services/trello/trello_api_client.dart';
import '../../../services/youtrack/youtrack_api_client.dart';
import '../kanban/kanban_ui_helpers.dart';
import '../../../models/trello_integration_state.dart';

/// Formatea 'YYYY-MM-DD' o 'YYYY-MM-DDTHH:MM' para mostrarlo en la UI.
String folioFmtTaskDue(String due) => due.replaceFirst('T', ' ');

String folioFormatJiraError(
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

class TaskRef {
  const TaskRef({required this.pageId, required this.blockId});
  final String pageId;
  final String blockId;
}

/// Crea un bloque `task` borrador y devuelve su [TaskRef], o null si falla.
TaskRef? createTaskDraft({
  required VaultSession session,
  required String pageId,
  String? columnId,
  String? afterBlockId,
}) {
  final cols = session.kanbanDataForPage(pageId).columns;
  final col = (columnId ?? '').trim().isNotEmpty
      ? columnId!.trim()
      : (cols.isNotEmpty ? cols.first.id : 'todo');
  final task = FolioTaskData.defaults().copyWith(
    status: col,
    columnId: col,
  );
  if (afterBlockId != null && afterBlockId.trim().isNotEmpty) {
    final blockId = '${pageId}_${DateTime.now().microsecondsSinceEpoch}';
    session.insertBlockAfter(
      pageId: pageId,
      afterBlockId: afterBlockId,
      block: FolioBlock(id: blockId, type: 'task', text: task.encode()),
    );
    return TaskRef(pageId: pageId, blockId: blockId);
  }
  final blockId = session.appendTaskBlockReturningId(
    pageId: pageId,
    task: task,
  );
  if (blockId.isEmpty) return null;
  return TaskRef(pageId: pageId, blockId: blockId);
}

/// Abre el detalle de tarea como overlay (sheet en compacto, diálogo ancho en desktop).
Future<void> showTaskDetails({
  required BuildContext context,
  required VaultSession session,
  required TaskRef taskRef,
}) async {
  final width = MediaQuery.sizeOf(context).width;
  final compact = width < FolioDesktop.compactBreakpoint;

  Future<void> openRef(TaskRef ref) async {
    if (!context.mounted) return;
    await showTaskDetails(context: context, session: session, taskRef: ref);
  }

  if (compact) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FolioSpace.md),
          child: TaskDetailsSheet(
            session: session,
            taskRef: taskRef,
            onClose: () => Navigator.of(sheetContext).pop(),
            onOpenTaskRef: (ref) {
              Navigator.of(sheetContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(openRef(ref));
              });
            },
          ),
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      var fullScreen = false;
      return StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Dialog(
            insetPadding: fullScreen
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Align(
              alignment: fullScreen ? Alignment.center : Alignment.centerRight,
              child: ConstrainedBox(
                constraints: fullScreen
                    ? const BoxConstraints.expand()
                    : BoxConstraints(
                        maxWidth: 420,
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
                      ),
                child: TaskDetailsPanel(
                  session: session,
                  taskRef: taskRef,
                  onClose: () => Navigator.of(dialogContext).pop(),
                  onOpenTaskRef: (ref) {
                    Navigator.of(dialogContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      unawaited(openRef(ref));
                    });
                  },
                  isFullScreen: fullScreen,
                  onToggleFullScreen: () =>
                      setDlgState(() => fullScreen = !fullScreen),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Crea un borrador y abre el panel de detalle.
Future<TaskRef?> createTaskDraftAndOpenDetails({
  required BuildContext context,
  required VaultSession session,
  required String pageId,
  String? columnId,
  String? afterBlockId,
  bool selectPage = false,
}) async {
  final ref = createTaskDraft(
    session: session,
    pageId: pageId,
    columnId: columnId,
    afterBlockId: afterBlockId,
  );
  if (ref == null) return null;
  if (selectPage) {
    session.selectPage(pageId);
  }
  if (!context.mounted) return ref;
  await showTaskDetails(context: context, session: session, taskRef: ref);
  return ref;
}

class TaskDetailsPanel extends StatelessWidget {
  const TaskDetailsPanel({
    required this.session,
    required this.taskRef,
    required this.onClose,
    required this.onOpenTaskRef,
    required this.isFullScreen,
    required this.onToggleFullScreen,
  });

  final VaultSession session;
  final TaskRef taskRef;
  final VoidCallback onClose;
  final void Function(TaskRef ref) onOpenTaskRef;
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
      child: TaskDetailsContent(
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

class TaskDetailsSheet extends StatelessWidget {
  const TaskDetailsSheet({
    required this.session,
    required this.taskRef,
    required this.onClose,
    required this.onOpenTaskRef,
  });

  final VaultSession session;
  final TaskRef taskRef;
  final VoidCallback onClose;
  final void Function(TaskRef ref) onOpenTaskRef;

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
        child: TaskDetailsContent(
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

class TaskDetailsContent extends StatefulWidget {
  const TaskDetailsContent({
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
  final TaskRef taskRef;
  final VoidCallback onClose;
  final void Function(TaskRef ref) onOpenTaskRef;

  @override
  State<TaskDetailsContent> createState() => TaskDetailsContentState();
}

class TaskDetailsContentState extends State<TaskDetailsContent> {
  static const _uuid = Uuid();

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
  List<_ChildTaskRow> _childTasks = const [];
  var _deleteBusy = false;

  /// Debounce de campos de texto libre: evita un `updateBlockText` (y su
  /// cascada de notificaciones de sesión) por cada tecla pulsada.
  Timer? _emitDebounceTimer;
  FolioTaskData? _pendingEmitData;
  String? _pendingEmitPageId;
  String? _pendingEmitBlockId;
  static const Duration _emitDebounceDuration = Duration(milliseconds: 400);

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

   var _trelloBusy = false;
   String? _trelloError;
   TrelloCard? _trelloCard;
   List<TrelloComment> _trelloComments = const [];
   final _trelloNewCommentCtrl = TextEditingController();
   bool _trelloAutoPulledOnce = false;

  @override
  void initState() {
    super.initState();
    _reloadFromSession();
    widget.session.addListener(_onSession);
  }

  @override
  void didUpdateWidget(covariant TaskDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskRef.pageId != widget.taskRef.pageId ||
        oldWidget.taskRef.blockId != widget.taskRef.blockId) {
      // Vacía cambios pendientes de la tarea ANTERIOR antes de recargar la
      // nueva (usa los ids capturados en el flush, no widget.taskRef, que ya
      // apunta a la tarea nueva).
      _flushPendingEmit();
      _reloadFromSession();
    }
  }

  @override
  void dispose() {
    _flushPendingEmit();
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
    _trelloNewCommentCtrl.dispose();
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
    final parsed = FolioTaskData.tryParse(b.text);
    if (parsed == null) return;
    // Si hay un flush de tecleo pendiente para ESTA tarea, `b.text` todavía
    // no refleja lo último escrito (va detrás del debounce). Recargar ahora
    // pisaría los controllers con datos obsoletos y borraría lo que el
    // usuario acaba de teclear. Se salta solo la sincronización de datos /
    // controllers; el resto de `_reloadFromSession` (subtareas, auto-pull)
    // sigue ejecutándose siempre.
    final hasPendingEditForThisTask =
        _emitDebounceTimer != null &&
        _pendingEmitPageId == widget.taskRef.pageId &&
        _pendingEmitBlockId == widget.taskRef.blockId;
    if (!hasPendingEditForThisTask) {
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
    // Best-effort: auto pull Trello details once per task open.
    if (!_trelloAutoPulledOnce &&
        ext != null &&
        ext.provider == 'trello' &&
        ext.issueId.trim().isNotEmpty) {
      _trelloAutoPulledOnce = true;
      unawaited(_trelloRefresh());
    }
  }

  void _emit(FolioTaskData next) =>
      _emitNow(widget.taskRef.pageId, widget.taskRef.blockId, next);

  void _emitNow(String pageId, String blockId, FolioTaskData next) {
    // Una escritura inmediata ya incorpora el `_data` más reciente (ver el
    // `setState` en `_emitDebounced`), así que descarta cualquier debounce en
    // curso: si no, su flush tardío sobrescribiría este cambio con una copia
    // vieja de antes de la última tecla debounced.
    _emitDebounceTimer?.cancel();
    _emitDebounceTimer = null;
    _pendingEmitData = null;
    _pendingEmitPageId = null;
    _pendingEmitBlockId = null;
    // If this task is linked to Jira, YouTrack or Trello, mark it dirty for incremental push.
    final ext = next.external;
    if (ext != null &&
        (ext.provider == 'jira' ||
            ext.provider == 'youtrack' ||
            ext.provider == 'trello')) {
      final cur = (ext.syncState ?? '').trim();
      if (cur != 'conflict') {
        next = next.copyWith(external: ext.copyWith(syncState: 'needsPush'));
      }
    }
    widget.session.updateBlockText(pageId, blockId, next.encode());
  }

  /// Para campos de texto libre: coalesce las teclas en una sola escritura a
  /// la sesión ~[_emitDebounceDuration] después de la última, en vez de una
  /// por tecla (evita disparar la cascada de guardado/notificación en cada
  /// pulsación). Actualiza `_data` y hace `setState` de inmediato para que el
  /// resto de la UI (y cualquier `_emit` inmediato posterior, p. ej. un
  /// dropdown) vea siempre el texto ya escrito.
  void _emitDebounced(FolioTaskData next) {
    _data = next;
    if (mounted) setState(() {});
    _pendingEmitData = next;
    _pendingEmitPageId = widget.taskRef.pageId;
    _pendingEmitBlockId = widget.taskRef.blockId;
    _emitDebounceTimer?.cancel();
    _emitDebounceTimer = Timer(_emitDebounceDuration, _flushPendingEmit);
  }

  /// Vuelca de inmediato (sin esperar el debounce) el último cambio de texto
  /// pendiente, si lo hay. Debe llamarse antes de cualquier acción que lea o
  /// dependa del estado persistido de la tarea (cerrar el panel, cambiar de
  /// tarea, borrar, sync manual, etc.), para no perder texto tecleado.
  void _flushPendingEmit() {
    _emitDebounceTimer?.cancel();
    _emitDebounceTimer = null;
    final pending = _pendingEmitData;
    final pageId = _pendingEmitPageId;
    final blockId = _pendingEmitBlockId;
    _pendingEmitData = null;
    _pendingEmitPageId = null;
    _pendingEmitBlockId = null;
    if (pending == null || pageId == null || blockId == null) return;
    _emitNow(pageId, blockId, pending);
  }

  Future<void> _deleteTaskWithJiraIfLinked() async {
    if (_deleteBusy) return;
    _flushPendingEmit();
    final data = _data;
    if (data == null) return;

    final l10n = AppLocalizations.of(context);
    final provider = data.external?.provider;
    final String confirmText;
    if (provider == 'jira' || provider == 'youtrack') {
      confirmText = Localizations.localeOf(context).languageCode == 'es'
          ? 'Esta acción borrará la tarea en Folio y también el issue en ${provider == 'jira' ? 'Jira' : 'YouTrack'} (incluyendo subtareas vinculadas). ¿Continuar?'
          : 'This will delete the task in Folio and also the issue in ${provider == 'jira' ? 'Jira' : 'YouTrack'} (including linked subtasks). Continue?';
    } else if (provider == 'trello') {
      confirmText = l10n.trelloDeleteRemoteConfirm;
    } else {
      confirmText = Localizations.localeOf(context).languageCode == 'es'
          ? '¿Borrar la tarea en Folio?'
          : 'Delete this task in Folio?';
    }

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
    final isEs = Localizations.localeOf(context).languageCode == 'es';

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
        } else if (ext.provider == 'trello') {
          final client = _trelloClientFor(ext);
          if (client == null) {
            throw StateError(l10n.trelloConnectionMissingDelete);
          }
          final cardId = ext.issueId.trim();
          if (cardId.isNotEmpty) {
            await client.archiveCard(cardId);
          }
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
        SnackBar(content: Text(folioFormatJiraError(e, l10n, isEs: isEs))),
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

  TrelloApiClient? _trelloClientFor(FolioExternalTaskLink ext) {
    final connectionId = (ext.cloudId ?? '').trim();
    if (connectionId.isEmpty) return null;
    final conn = widget.session.trelloConnections.firstWhereOrNull(
      (c) => c.id == connectionId,
    );
    if (conn == null) return null;
    return TrelloApiClient(connection: conn);
  }

  TrelloApiClient? _trelloClientOrSetError(FolioExternalTaskLink ext) {
    final client = _trelloClientFor(ext);
    if (client != null) return client;
    setState(() {
      _trelloError = AppLocalizations.of(context).trelloConnectionMissing;
    });
    return null;
  }

  TrelloSource? _trelloSourceForPage() {
    final page = widget.session.pages.firstWhereOrNull(
      (p) => p.id == widget.taskRef.pageId,
    );
    if (page == null) return null;
    for (final b in page.blocks) {
      if (b.type != 'kanban') continue;
      final kd = FolioKanbanData.tryParse(b.text);
      final sid = (kd?.trelloSourceId ?? '').trim();
      if (sid.isEmpty) continue;
      return widget.session.trelloSources.firstWhereOrNull((s) => s.id == sid);
    }
    return null;
  }

  FolioTrelloCardSnapshot _trelloSnapshotFromCard(
    TrelloCard card, {
    TrelloSource? source,
  }) {
    final mapping = source?.columnMappings.firstWhereOrNull(
      (m) => m.listId == card.idList,
    );
    return FolioTrelloCardSnapshot(
      boardId: card.idBoard,
      boardName: source?.boardName,
      listId: card.idList,
      listName: mapping?.listName,
      labels: card.labels.isEmpty
          ? null
          : card.labels
              .map((l) => l.name.isNotEmpty ? l.name : (l.color ?? ''))
              .join(', '),
      memberNames: card.memberNames,
      checklistItemCount: card.checklistItemCount,
      checklistCheckedCount: card.checklistCheckedCount,
      commentCount: card.commentCount,
      attachmentCount: card.attachmentCount,
      due: card.due,
      shortUrl: card.browseUrl,
    );
  }

  String? _mapTrelloPriorityFromLabels(
    List<TrelloLabel> labels,
    List<TrelloPriorityLabelMapping> mappings,
  ) {
    if (labels.isEmpty || mappings.isEmpty) return null;
    for (final label in labels) {
      final mapping = mappings.firstWhereOrNull((m) => m.labelId == label.id);
      if (mapping != null) return mapping.priority;
    }
    return null;
  }

  String _mapTrelloColumnFromList(
    String listId,
    List<TrelloColumnMapping> mappings,
  ) {
    final mapped = mappings.firstWhereOrNull((m) => m.listId == listId);
    if (mapped != null) return mapped.columnId;
    return 'todo';
  }

  String? _mapPriorityToTrelloLabelId(
    String? folioPriority,
    List<TrelloPriorityLabelMapping> mappings,
  ) {
    final p = (folioPriority ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    return mappings.firstWhereOrNull((m) => m.priority.toLowerCase() == p)?.labelId;
  }

  Future<void> _trelloRefresh() async {
    _flushPendingEmit();
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'trello') return;
    final client = _trelloClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _trelloBusy = true;
      _trelloError = null;
    });
    try {
      final cardId = ext.issueId.trim();
      final card = await client.getCard(cardId);
      final comments = await client.getCardComments(cardId);
      setState(() {
        _trelloCard = card;
        _trelloComments = comments;
      });
    } catch (e) {
      setState(() => _trelloError = '$e');
    } finally {
      if (mounted) setState(() => _trelloBusy = false);
    }
  }

  Future<void> _trelloAddComment() async {
    final text = _trelloNewCommentCtrl.text.trim();
    if (text.isEmpty) return;
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'trello') return;
    final client = _trelloClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _trelloBusy = true;
      _trelloError = null;
    });
    try {
      await client.addComment(cardId: ext.issueId.trim(), text: text);
      _trelloNewCommentCtrl.clear();
      await _trelloRefresh();
    } catch (e) {
      setState(() => _trelloError = '$e');
    } finally {
      if (mounted) setState(() => _trelloBusy = false);
    }
  }

  Future<void> _trelloResolveKeepRemote() async {
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'trello') return;
    final client = _trelloClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _trelloBusy = true;
      _trelloError = null;
    });
    try {
      final source = _trelloSourceForPage();
      final card = await client.getCard(ext.issueId.trim());
      final folioPriority = _mapTrelloPriorityFromLabels(
        card.labels,
        source?.priorityLabelMappings ?? const [],
      );
      final folioStatus = _mapTrelloColumnFromList(
        card.idList,
        source?.columnMappings ?? const [],
      );
      final tags = <String>[];
      final seen = <String>{};
      for (final l in card.labels) {
        final name = l.name.trim();
        if (name.isEmpty) continue;
        if (seen.add(name.toLowerCase())) tags.add(name);
      }

      List<FolioTaskSubtask> subtasks = data.subtasks;
      if (source?.importOptions.includeChecklists != false) {
        final checklists = await client.getCardChecklists(card.id);
        final prefix = checklists.length > 1;
        final nextSub = <FolioTaskSubtask>[];
        for (final cl in checklists) {
          final clName = cl.name.trim();
          for (final item in cl.checkItems) {
            final itemId = item.id.trim();
            final itemTitle = item.name.trim();
            if (itemId.isEmpty && itemTitle.isEmpty) continue;
            final title = prefix && clName.isNotEmpty
                ? '$clName: $itemTitle'
                : itemTitle;
            nextSub.add(
              FolioTaskSubtask(
                id: itemId.isEmpty ? title.hashCode.toString() : itemId,
                title: title,
                status: item.isComplete ? 'done' : 'todo',
              ),
            );
          }
        }
        subtasks = nextSub;
      }

      final dueRaw = (card.due ?? '').trim();
      String? dueDate;
      if (dueRaw.isNotEmpty) {
        dueDate = DateTime.tryParse(dueRaw)?.toUtc().toIso8601String() ?? dueRaw;
      }

      final nextExternal = ext.copyWith(
        remoteUpdatedAtMs: card.updatedAtMs,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        syncState: 'ok',
      );

      final next = data.copyWith(
        title: card.name.trim(),
        description: card.desc,
        priority: folioPriority,
        status: folioStatus,
        columnId: folioStatus,
        dueDate: dueDate,
        assignee: card.memberNames,
        tags: tags,
        subtasks: subtasks,
        external: nextExternal,
        trello: _trelloSnapshotFromCard(card, source: source),
      );

      _emit(next);
      final comments = await client.getCardComments(card.id);
      setState(() {
        _trelloCard = card;
        _trelloComments = comments;
      });
    } catch (e) {
      setState(() => _trelloError = '$e');
    } finally {
      if (mounted) setState(() => _trelloBusy = false);
    }
  }

  Future<void> _trelloResolveKeepLocalForcePush() async {
    _flushPendingEmit();
    final data = _data;
    final ext = data?.external;
    if (data == null || ext == null || ext.provider != 'trello') return;
    final client = _trelloClientOrSetError(ext);
    if (client == null) return;
    setState(() {
      _trelloBusy = true;
      _trelloError = null;
    });
    try {
      final source = _trelloSourceForPage();
      final cardId = ext.issueId.trim();
      final effectiveColumn = (data.columnId ?? '').trim().isNotEmpty
          ? data.columnId!.trim()
          : data.status.trim();
      final mapping = source?.columnMappings.firstWhereOrNull(
        (m) => m.columnId.trim() == effectiveColumn,
      );

      await client.updateCard(
        cardId: cardId,
        name: data.title.trim(),
        desc: data.description,
        idList: mapping?.listId,
      );

      if (source != null && source.priorityLabelMappings.isNotEmpty) {
        final remote = await client.getCard(cardId);
        final desiredLabelId = _mapPriorityToTrelloLabelId(
          data.priority,
          source.priorityLabelMappings,
        );
        final priorityLabelIds =
            source.priorityLabelMappings.map((m) => m.labelId).toSet();
        final nextLabelIds = remote.labels
            .map((l) => l.id)
            .where((id) => !priorityLabelIds.contains(id))
            .toList();
        if (desiredLabelId != null) nextLabelIds.add(desiredLabelId);
        await client.updateCardLabels(cardId: cardId, idLabels: nextLabelIds);
      }

      if (data.subtasks.isNotEmpty) {
        final checklists = await client.getCardChecklists(cardId);
        final remoteById = <String, TrelloCheckItem>{};
        for (final cl in checklists) {
          for (final item in cl.checkItems) {
            final id = item.id.trim();
            if (id.isEmpty) continue;
            remoteById[id] = item;
          }
        }
        for (final sub in data.subtasks) {
          final id = sub.id.trim();
          if (id.isEmpty) continue;
          final remoteItem = remoteById[id];
          if (remoteItem == null) continue;
          final wantComplete = sub.status.trim() == 'done';
          if (wantComplete == remoteItem.isComplete) continue;
          await client.updateCheckItemState(
            cardId: cardId,
            checkItemId: id,
            complete: wantComplete,
          );
        }
      }

      final updatedRemote = await client.getCard(cardId);
      final nextExternal = ext.copyWith(
        remoteUpdatedAtMs: updatedRemote.updatedAtMs,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        syncState: 'ok',
      );

      _emit(
        data.copyWith(
          external: nextExternal,
          trello: _trelloSnapshotFromCard(updatedRemote, source: source),
        ),
      );
      final comments = await client.getCardComments(cardId);
      setState(() {
        _trelloCard = updatedRemote;
        _trelloComments = comments;
      });
    } catch (e) {
      setState(() => _trelloError = '$e');
    } finally {
      if (mounted) setState(() => _trelloBusy = false);
    }
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
    _flushPendingEmit();
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
    _flushPendingEmit();
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
    _flushPendingEmit();
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
    _flushPendingEmit();
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

  Uri? _trelloBrowseUri(FolioTaskData data) {
    final ext = data.external;
    if (ext == null || ext.provider != 'trello') return null;
    final fromSnap = (data.trello?.shortUrl ?? '').trim();
    if (fromSnap.isNotEmpty) return Uri.tryParse(fromSnap);
    final fromLive = (_trelloCard?.browseUrl ?? '').trim();
    if (fromLive.isNotEmpty) return Uri.tryParse(fromLive);
    final cardId = ext.issueId.trim();
    if (cardId.isEmpty) return null;
    return Uri.tryParse('https://trello.com/c/$cardId');
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
    if (cur == null) return;
    final next = [
      ...cur.subtasks,
      FolioTaskSubtask(id: 'st_${_uuid.v4()}', title: '', status: 'todo'),
    ];
    _emit(cur.copyWith(subtasks: next));
  }

  void _setInlineSubtaskDone(String subtaskId, bool done) {
    final cur = _data;
    if (cur == null) return;
    final next = cur.subtasks
        .map(
          (s) => s.id == subtaskId
              ? s.copyWith(status: done ? 'done' : 'todo')
              : s,
        )
        .toList(growable: false);
    _emit(cur.copyWith(subtasks: next));
  }

  void _setInlineSubtaskTitle(String subtaskId, String title) {
    final cur = _data;
    if (cur == null) return;
    final next = cur.subtasks
        .map((s) => s.id == subtaskId ? s.copyWith(title: title) : s)
        .toList(growable: false);
    _emit(cur.copyWith(subtasks: next));
  }

  void _removeInlineSubtask(String subtaskId) {
    final cur = _data;
    if (cur == null) return;
    final next =
        cur.subtasks.where((s) => s.id != subtaskId).toList(growable: false);
    _emit(cur.copyWith(subtasks: next));
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
                      l10n.taskDetailsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.taskDetailsDeleteTooltip,
                    onPressed: _deleteBusy ? null : _deleteTaskWithJiraIfLinked,
                    icon: _deleteBusy
                        ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                        : const Icon(Icons.delete_outline_rounded),
                  ),
                  if (widget.onToggleFullScreen != null)
                    IconButton(
                      tooltip: widget.isFullScreen
                          ? l10n.taskDetailsExitFullscreen
                          : l10n.taskDetailsEnterFullscreen,
                      onPressed: widget.onToggleFullScreen,
                      icon: Icon(
                        widget.isFullScreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                      ),
                    ),
                  IconButton(
                    tooltip: l10n.taskDetailsCloseTooltip,
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

              // Trello link banner
              final trelloBanner = data.external?.provider == 'trello'
                  ? Builder(
                      builder: (ctx) {
                        final ext = data.external!;
                        final uri = _trelloBrowseUri(data);
                        final label = ext.issueId.trim();
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
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: Image(
                                  image: AssetImage('appLogos/trello.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.trelloBannerLabel(label),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: Text(l10n.taskHubOpen),
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
                onChanged: (v) => _emitDebounced(data.copyWith(title: v.trim())),
              );

              // Description field
              final descField = TextField(
                controller: _descCtrl,
                minLines: 2,
                maxLines: 8,
                decoration: InputDecoration(labelText: l10n.description, border: const OutlineInputBorder()),
                onChanged: (v) => _emitDebounced(data.copyWith(description: v)),
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
                      onChanged: (v) => _emitDebounced(data.copyWith(blockedReason: v)),
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
                      label: Text(data.dueDate == null ? l10n.dueDate : '${l10n.dueDate}: ${folioFmtTaskDue(data.dueDate!)}'),
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
                onChanged: (v) => _emitDebounced(data.copyWith(timeSpentMinutes: int.tryParse(v.trim()))),
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
                          onChanged: (v) => _emitDebounced(data.copyWith(youtrack: data.youtrack?.copyWith(type: v.trim()))),
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
                            _emitDebounced(data.copyWith(
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
                          onChanged: (v) => _emitDebounced(data.copyWith(youtrack: data.youtrack?.copyWith(subsystem: v.trim()))),
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
                          onChanged: (v) => _emitDebounced(data.copyWith(youtrack: data.youtrack?.copyWith(fixVersions: v.trim()))),
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
                          onChanged: (v) => _emitDebounced(data.copyWith(youtrack: data.youtrack?.copyWith(affectedVersions: v.trim()))),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ytFixedInBuildCtrl,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Solucionado en el build' : 'Fixed in Build',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.build_outlined, size: 18),
                          ),
                          onChanged: (v) => _emitDebounced(data.copyWith(youtrack: data.youtrack?.copyWith(fixedInBuild: v.trim()))),
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
                          onChanged: (v) => _emitDebounced(data.copyWith(youtrack: data.youtrack?.copyWith(estimation: v.trim()))),
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
                          onChanged: (v) => _emitDebounced(data.copyWith(youtrack: data.youtrack?.copyWith(spentTime: v.trim()))),
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

              // Trello sync/comments section
              final trelloDetailsSection = data.external?.provider == 'trello'
                  ? _TrelloDetailsSection(
                      scheme: scheme,
                      data: data,
                      busy: _trelloBusy,
                      error: _trelloError,
                      card: _trelloCard,
                      comments: _trelloComments,
                      newCommentCtrl: _trelloNewCommentCtrl,
                      onRefresh: _trelloRefresh,
                      onResolveKeepRemote: _trelloResolveKeepRemote,
                      onResolveKeepLocalForcePush: _trelloResolveKeepLocalForcePush,
                      onAddComment: _trelloAddComment,
                    )
                  : null;

              // Subtasks section: inline FolioTaskSubtask (Trello/kanban) +
              // child task blocks (Jira parentTaskId).
              final inlineSubtasks = data.subtasks;
              final hasAnySubtasks =
                  inlineSubtasks.isNotEmpty || _childTasks.isNotEmpty;
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
                  if (!hasAnySubtasks)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.kanbanEmptyColumn,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else ...[
                    if (inlineSubtasks.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: inlineSubtasks.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = inlineSubtasks[i];
                          return Card(
                            elevation: 0,
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: s.status == 'done',
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (v) =>
                                        _setInlineSubtaskDone(s.id, v == true),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      key: ValueKey('detail_inline_subtask_${s.id}'),
                                      initialValue: s.title,
                                      decoration: InputDecoration(
                                        labelText: l10n.title,
                                        border: const OutlineInputBorder(),
                                        hintText: l10n.taskSubtaskHint,
                                      ),
                                      onChanged: (v) =>
                                          _setInlineSubtaskTitle(s.id, v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: l10n.delete,
                                    onPressed: () => _removeInlineSubtask(s.id),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    if (inlineSubtasks.isNotEmpty && _childTasks.isNotEmpty)
                      const SizedBox(height: 8),
                    if (_childTasks.isNotEmpty)
                      ListView.separated(
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
                                TaskRef(pageId: widget.taskRef.pageId, blockId: child.blockId),
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
                                        TaskRef(pageId: widget.taskRef.pageId, blockId: child.blockId),
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
                                if (trelloBanner != null) trelloBanner,
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
                                if (trelloDetailsSection != null) ...[
                                  const SizedBox(height: 10),
                                  trelloDetailsSection,
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
                    if (trelloBanner != null) trelloBanner,
                    if (trelloDetailsSection != null) ...[
                      trelloDetailsSection,
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

class _TrelloDetailsSection extends StatelessWidget {
  const _TrelloDetailsSection({
    required this.scheme,
    required this.data,
    required this.busy,
    required this.error,
    required this.card,
    required this.comments,
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
  final TrelloCard? card;
  final List<TrelloComment> comments;
  final TextEditingController newCommentCtrl;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onResolveKeepRemote;
  final Future<void> Function() onResolveKeepLocalForcePush;
  final Future<void> Function() onAddComment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ext = data.external!;
    final snap = data.trello;
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
              const SizedBox(
                width: 18,
                height: 18,
                child: Image(
                  image: AssetImage('appLogos/trello.png'),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.trelloDetailsTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              pill(state),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onRefresh,
                icon: busy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.trelloRefresh),
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
                    l10n.trelloConflictMessage,
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

                      Widget diffRow(String label, String folio, String remote) {
                        final same = folio.trim() == remote.trim();
                        final folioText =
                            folio.trim().isEmpty ? '—' : folio.trim();
                        final remoteText =
                            remote.trim().isEmpty ? '—' : remote.trim();
                        final baseStyle =
                            Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: scheme.onErrorContainer
                                      .withValues(alpha: 0.92),
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
                                  ? scheme.outlineVariant
                                      .withValues(alpha: 0.35)
                                  : scheme.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                label,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
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
                                'Trello: $remoteText',
                                style: baseStyle,
                              ),
                            ],
                          ),
                        );
                      }

                      final remote = card;
                      if (remote == null) {
                        return Text(
                          l10n.trelloConflictLoadHint,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer
                                    .withValues(alpha: 0.9),
                              ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          diffRow(
                            l10n.title,
                            norm(data.title),
                            norm(remote.name),
                          ),
                          const SizedBox(height: 8),
                          diffRow(
                            l10n.description,
                            cut(norm(data.description), max: 140),
                            cut(norm(remote.desc), max: 140),
                          ),
                          const SizedBox(height: 8),
                          diffRow(
                            l10n.kanbanStatusColumn,
                            norm(data.columnId ?? data.status),
                            norm(snap?.listName ?? remote.idList),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onResolveKeepRemote,
                                  child: Text(l10n.trelloKeepRemote),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: onResolveKeepLocalForcePush,
                                  child: Text(l10n.trelloForceFolio),
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if ((snap?.listName ?? '').trim().isNotEmpty)
                _Tag(label: '${l10n.trelloListHint}: ${snap!.listName}'),
              if ((snap?.labels ?? '').trim().isNotEmpty)
                _Tag(label: '${l10n.trelloLabelHint}: ${snap!.labels}'),
              if ((snap?.memberNames ?? '').trim().isNotEmpty)
                _Tag(label: snap!.memberNames!),
              if ((snap?.due ?? '').trim().isNotEmpty)
                _Tag(label: '${l10n.kanbanDueDate}: ${snap!.due}'),
              if (snap?.commentCount != null)
                _Tag(label: '${l10n.trelloComments}: ${snap!.commentCount}'),
              if (snap?.attachmentCount != null)
                _Tag(
                  label: '${l10n.trelloAttachments}: ${snap!.attachmentCount}',
                ),
            ],
          ),
          const Divider(height: 24),
          Text(
            l10n.trelloCommentsTitle,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (comments.isNotEmpty) ...[
            for (final c in comments)
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
                          c.authorName.isEmpty
                              ? l10n.trelloDetailsTitle
                              : c.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        if (c.createdMs > 0)
                          Text(
                            DateTime.fromMillisecondsSinceEpoch(c.createdMs)
                                .toString()
                                .substring(0, 16),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
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
              l10n.trelloNoComments,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newCommentCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.trelloAddCommentHint,
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
