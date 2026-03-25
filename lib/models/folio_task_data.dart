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
  });

  /// Texto descriptivo de la tarea.
  final String title;

  /// Estado de la tarea: `'todo'`, `'in_progress'` o `'done'`.
  final String status;

  /// Prioridad opcional: `'low'`, `'medium'` o `'high'`.
  final String? priority;

  /// Fecha límite opcional en formato ISO-8601 (`'YYYY-MM-DD'`).
  final String? dueDate;

  static const _validStatuses = {'todo', 'in_progress', 'done'};
  static const _validPriorities = {'low', 'medium', 'high'};

  static FolioTaskData defaults() =>
      FolioTaskData(title: '', status: 'todo', priority: null, dueDate: null);

  FolioTaskData copyWith({
    String? title,
    String? status,
    Object? priority = _sentinel,
    Object? dueDate = _sentinel,
  }) {
    return FolioTaskData(
      title: title ?? this.title,
      status: status ?? this.status,
      priority: priority == _sentinel ? this.priority : priority as String?,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as String?,
    );
  }

  static const Object _sentinel = Object();

  String encode() => jsonEncode({
    'v': 1,
    'title': title,
    'status': status,
    if (priority != null) 'priority': priority,
    if (dueDate != null) 'dueDate': dueDate,
  });

  static FolioTaskData? tryParse(String raw) {
    if (raw.trim().isEmpty) return FolioTaskData.defaults();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final rawStatus = m['status'] as String? ?? 'todo';
      final rawPriority = m['priority'] as String?;
      return FolioTaskData(
        title: (m['title'] as String?) ?? '',
        status: _validStatuses.contains(rawStatus) ? rawStatus : 'todo',
        priority: (_validPriorities.contains(rawPriority)) ? rawPriority : null,
        dueDate: (m['dueDate'] as String?),
      );
    } catch (_) {
      return null;
    }
  }
}
