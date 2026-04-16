import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_feedback.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_task_data.dart';
import '../../../services/tasks/task_quick_capture_parser.dart';
import '../../../session/vault_session.dart';

String? _isoDateOrNull(DateTime? d) {
  if (d == null) return null;
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime? _tryParseIsoDate(String? iso) {
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

/// Editor UI de tarea (reemplaza el input por texto como flujo principal).
class _TaskQuickAddDialog extends StatefulWidget {
  const _TaskQuickAddDialog();

  @override
  State<_TaskQuickAddDialog> createState() => _TaskQuickAddDialogState();
}

class _TaskQuickAddDialogState extends State<_TaskQuickAddDialog> {
  late final TextEditingController _titleCtrl = TextEditingController();
  late final TextEditingController _descCtrl = TextEditingController();
  late final TextEditingController _timeCtrl = TextEditingController();
  String _status = 'todo';
  String? _priority;
  DateTime? _start;
  DateTime? _due;
  final List<FolioTaskSubtask> _subtasks = <FolioTaskSubtask>[];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  int? _timeMinutesOrNull() {
    final raw = _timeCtrl.text.trim();
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    if (v == null || v < 0) return null;
    return v;
  }

  FolioTaskData _buildTask() {
    return FolioTaskData(
      title: _titleCtrl.text.trim(),
      status: _status,
      columnId: _status,
      priority: _priority,
      description: _descCtrl.text,
      startDate: _isoDateOrNull(_start),
      dueDate: _isoDateOrNull(_due),
      timeSpentMinutes: _timeMinutesOrNull(),
      subtasks: List<FolioTaskSubtask>.from(_subtasks),
    );
  }

  void _submit() {
    final t = _buildTask();
    if (t.title.trim().isEmpty) return;
    Navigator.of(context).pop<FolioTaskData>(t);
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? _start : _due) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _due = picked;
      }
    });
  }

  Future<void> _fillFromText() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final raw = await showDialog<String?>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.taskQuickAddTitle),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.taskQuickAddHint,
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
            child: Text(l10n.taskQuickAddConfirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final line = raw?.trim() ?? '';
    if (!mounted || line.isEmpty) return;
    final parsed = TaskQuickCaptureParser.parse(
      line,
      nowLocal: DateTime.now(),
      aliasToPageId: const {},
    );
    setState(() {
      _titleCtrl.text = parsed.task.title;
      _status = parsed.task.status;
      _priority = parsed.task.priority;
      _due = _tryParseIsoDate(parsed.task.dueDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.taskQuickAddTitle),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: l10n.taskQuickAddHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.taskHubDashboardHelpTitle,
                  onPressed: _fillFromText,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.description,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: InputDecoration(
                      labelText: l10n.priority,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.none),
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
                    ],
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
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
                    onChanged: (v) => setState(() => _status = v ?? 'todo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _start == null
                          ? l10n.startDate
                          : '${l10n.startDate}: ${_isoDateOrNull(_start)}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: false),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(
                      _due == null
                          ? l10n.dueDate
                          : '${l10n.dueDate}: ${_isoDateOrNull(_due)}',
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
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.subtasks,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _subtasks.add(
                        FolioTaskSubtask(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          title: '',
                          status: 'todo',
                        ),
                      );
                    });
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.add),
                ),
              ],
            ),
            if (_subtasks.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...List.generate(_subtasks.length, (i) {
                final s = _subtasks[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.delete,
                        onPressed: () => setState(() => _subtasks.removeAt(i)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('subtask_title_${s.id}'),
                          initialValue: s.title,
                          onChanged: (v) => _subtasks[i] = _subtasks[i].copyWith(
                            title: v,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.title,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: s.status,
                        onChanged: (v) {
                          setState(() {
                            _subtasks[i] = _subtasks[i].copyWith(
                              status: v ?? 'todo',
                            );
                          });
                        },
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
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<FolioTaskData>(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.taskQuickAddConfirm),
        ),
      ],
    );
  }
}

Future<void> showTaskQuickAddDialog({
  required BuildContext context,
  required VaultSession session,
  required AppSettings appSettings,
  /// Si se indica, la tarea se añade en esta página (sin bandeja ni alias como destino).
  String? targetPageId,
}) async {
  final l10n = AppLocalizations.of(context);
  final task = await showDialog<FolioTaskData?>(
        context: context,
        builder: (_) => const _TaskQuickAddDialog(),
      );

  if (task == null || task.title.trim().isEmpty) return;

  final fixedTarget = targetPageId?.trim();
  final vaultId = session.activeVaultId;
  final aliases = await appSettings.getTaskAliasPageMap(vaultId);
  // Mantener en el flujo global: resolver alias `#foo/@foo` si está al final
  // del título (como antes), sin forzar captura por texto.
  final aliasParsed = TaskQuickCaptureParser.parse(
    task.title,
    nowLocal: DateTime.now(),
    aliasToPageId: aliases,
  );
  final parsed = TaskQuickCaptureResult(
    task: task.copyWith(title: aliasParsed.task.title),
    consumedAliasTag: aliasParsed.consumedAliasTag,
    targetPageIdFromAlias: aliasParsed.targetPageIdFromAlias,
  );

  String resolvedTarget;
  if (fixedTarget != null && fixedTarget.isNotEmpty) {
    if (!session.pages.any((p) => p.id == fixedTarget)) {
      if (!context.mounted) return;
      showFolioSnack(context, l10n.taskQuickAddAliasTargetMissing, error: true);
      return;
    }
    resolvedTarget = fixedTarget;
  } else {
    resolvedTarget = parsed.targetPageIdFromAlias ?? '';
    if (resolvedTarget.isEmpty) {
      var inboxId = await appSettings.getTaskInboxPageId(vaultId);
      if (inboxId != null &&
          inboxId.isNotEmpty &&
          session.pages.any((p) => p.id == inboxId)) {
        resolvedTarget = inboxId;
      } else {
        final newInboxId = session.createTaskInboxPage(
          title: l10n.taskInboxDefaultTitle,
        );
        await appSettings.setTaskInboxPageId(vaultId, newInboxId);
        resolvedTarget = newInboxId;
      }
    } else if (!session.pages.any((p) => p.id == resolvedTarget)) {
      if (!context.mounted) return;
      showFolioSnack(context, l10n.taskQuickAddAliasTargetMissing, error: true);
      return;
    }
  }

  final blockId = session.appendTaskBlockReturningId(
    pageId: resolvedTarget,
    task: parsed.task,
  );
  if (blockId.isEmpty) {
    if (!context.mounted) return;
    showFolioSnack(context, l10n.taskHubEmpty, error: true);
    return;
  }

  session.selectPage(resolvedTarget);
  session.requestScrollToBlock(blockId);
  if (context.mounted) {
    showFolioSnack(context, l10n.taskQuickAddSuccess);
  }
}
