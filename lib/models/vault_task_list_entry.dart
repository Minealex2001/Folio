import 'folio_task_data.dart';

/// Referencia a un bloque de tarea o `todo` dentro del vault para vistas agregadas.
class VaultTaskListEntry {
  const VaultTaskListEntry({
    required this.pageId,
    required this.pageTitle,
    required this.blockId,
    required this.blockType,
    this.task,
    this.todoChecked,
    this.todoText = '',
  });

  final String pageId;
  final String pageTitle;
  final String blockId;

  /// `task` o `todo`.
  final String blockType;

  /// No nulo si [blockType] == `task`.
  final FolioTaskData? task;

  final bool? todoChecked;
  final String todoText;

  bool get isDone {
    if (blockType == 'task') {
      return task?.status == 'done';
    }
    return todoChecked == true;
  }

  String get displayTitle {
    if (blockType == 'task') {
      return (task?.title ?? '').trim();
    }
    return todoText.trim();
  }

  String? get dueDate => task?.dueDate;

  String? get startDate => task?.startDate;

  String? get priority => task?.priority;

  /// Columna del tablero Kanban.
  String get kanbanColumnKey {
    if (blockType == 'todo') {
      return todoChecked == true ? 'done' : 'todo';
    }
    final t = task;
    if (t == null) return 'todo';
    return t.effectiveColumnId();
  }
}
