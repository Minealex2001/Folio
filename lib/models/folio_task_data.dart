import 'dart:convert';

/// Datos de un bloque de tarea enriquecido (tipo `task`).
///
/// El contenido se almacena serializado en [FolioBlock.text] como JSON,
/// siguiendo el mismo patrón que [FolioToggleData] y [FolioTemplateButtonData].
class FolioTaskData {
  FolioTaskData({
    required this.title,
    required this.status,
    this.priority,
    this.dueDate,
    List<FolioTaskSubtask>? subtasks,
  }) : subtasks = List<FolioTaskSubtask>.from(subtasks ?? const []);

  /// Texto descriptivo de la tarea.
  final String title;

  /// Estado de la tarea: `'todo'`, `'in_progress'` o `'done'`.
  final String status;

  /// Prioridad opcional: `'low'`, `'medium'` o `'high'`.
  final String? priority;

  /// Fecha límite opcional en formato ISO-8601 (`'YYYY-MM-DD'`).
  final String? dueDate;

  /// Subtareas opcionales asociadas a la tarea principal.
  final List<FolioTaskSubtask> subtasks;

  static const _validStatuses = {'todo', 'in_progress', 'done'};
  static const _validPriorities = {'low', 'medium', 'high'};

  static FolioTaskData defaults() => FolioTaskData(
    title: '',
    status: 'todo',
    priority: null,
    dueDate: null,
    subtasks: const [],
  );

  FolioTaskData copyWith({
    String? title,
    String? status,
    Object? priority = _sentinel,
    Object? dueDate = _sentinel,
    Object? subtasks = _sentinel,
  }) {
    return FolioTaskData(
      title: title ?? this.title,
      status: status ?? this.status,
      priority: priority == _sentinel ? this.priority : priority as String?,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as String?,
      subtasks: subtasks == _sentinel
          ? this.subtasks
          : (subtasks as List<FolioTaskSubtask>),
    );
  }

  static const Object _sentinel = Object();

  String encode() => jsonEncode({
    'v': 1,
    'title': title,
    'status': status,
    if (priority != null) 'priority': priority,
    if (dueDate != null) 'dueDate': dueDate,
    if (subtasks.isNotEmpty)
      'subtasks': subtasks.map((s) => s.toJson()).toList(growable: false),
  });

  static FolioTaskData? tryParse(String raw) {
    if (raw.trim().isEmpty) return FolioTaskData.defaults();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final rawStatus = m['status'] as String? ?? 'todo';
      final rawPriority = m['priority'] as String?;
      final rawSubtasks = m['subtasks'];
      final subtasks = <FolioTaskSubtask>[];
      if (rawSubtasks is List) {
        for (final s in rawSubtasks) {
          if (s is Map) {
            final parsed = FolioTaskSubtask.tryParse(
              Map<String, dynamic>.from(s),
            );
            if (parsed != null) subtasks.add(parsed);
          }
        }
      }
      return FolioTaskData(
        title: (m['title'] as String?) ?? '',
        status: _validStatuses.contains(rawStatus) ? rawStatus : 'todo',
        priority: (_validPriorities.contains(rawPriority)) ? rawPriority : null,
        dueDate: (m['dueDate'] as String?),
        subtasks: subtasks,
      );
    } catch (_) {
      return null;
    }
  }
}

class FolioTaskSubtask {
  const FolioTaskSubtask({
    required this.id,
    required this.title,
    required this.done,
  });

  final String id;
  final String title;
  final bool done;

  FolioTaskSubtask copyWith({String? id, String? title, bool? done}) {
    return FolioTaskSubtask(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  static FolioTaskSubtask? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final title = (map['title'] as String? ?? '').trim();
    if (id.isEmpty && title.isEmpty) return null;
    return FolioTaskSubtask(
      id: id.isEmpty ? title.hashCode.toString() : id,
      title: title,
      done: map['done'] == true,
    );
  }
}
