import 'dart:convert';

/// Datos de un bloque de tarea enriquecido (tipo `task`).
///
/// El contenido se almacena serializado en [FolioBlock.text] como JSON,
/// siguiendo el mismo patrón que [FolioToggleData] y [FolioTemplateButtonData].
class FolioTaskData {
  FolioTaskData({
    required this.title,
    required this.status,
    this.columnId,
    this.parentTaskId,
    this.blocked = false,
    this.blockedReason = '',
    this.priority,
    this.description = '',
    this.startDate,
    this.dueDate,
    this.timeSpentMinutes,
    List<FolioTaskSubtask>? subtasks,
  }) : subtasks = List<FolioTaskSubtask>.from(subtasks ?? const []);

  /// Texto descriptivo de la tarea.
  final String title;

  /// Estado de la tarea: `'todo'`, `'in_progress'` o `'done'`.
  final String status;

  /// Columna Kanban (configurable por página). Si es null/vacío, la UI puede
  /// derivarla de [status] (compatibilidad).
  final String? columnId;

  /// Si no es null, esta tarea se considera subtarea de la tarea cuyo bloque id
  /// coincide con este valor (subtareas como tareas anidadas).
  final String? parentTaskId;

  /// Si true, la tarea está bloqueada.
  final bool blocked;

  /// Motivo de bloqueo (opcional).
  final String blockedReason;

  /// Prioridad opcional: `'low'`, `'medium'` o `'high'`.
  final String? priority;

  /// Descripción de la tarea (texto libre).
  final String description;

  /// Fecha de inicio opcional (ISO-8601 `'YYYY-MM-DD'`). Útil para Timeline.
  final String? startDate;

  /// Fecha límite opcional en formato ISO-8601 (`'YYYY-MM-DD'`).
  final String? dueDate;

  /// Tiempo invertido (acumulado) en minutos.
  final int? timeSpentMinutes;

  /// Subtareas opcionales asociadas a la tarea principal.
  final List<FolioTaskSubtask> subtasks;

  static const _validStatuses = {'todo', 'in_progress', 'done'};
  static const _validPriorities = {'low', 'medium', 'high'};

  static FolioTaskData defaults() => FolioTaskData(
    title: '',
    status: 'todo',
    columnId: null,
    parentTaskId: null,
    blocked: false,
    blockedReason: '',
    priority: null,
    description: '',
    startDate: null,
    dueDate: null,
    timeSpentMinutes: null,
    subtasks: const [],
  );

  FolioTaskData copyWith({
    String? title,
    String? status,
    Object? columnId = _sentinel,
    Object? parentTaskId = _sentinel,
    bool? blocked,
    Object? blockedReason = _sentinel,
    Object? priority = _sentinel,
    Object? description = _sentinel,
    Object? startDate = _sentinel,
    Object? dueDate = _sentinel,
    Object? timeSpentMinutes = _sentinel,
    Object? subtasks = _sentinel,
  }) {
    return FolioTaskData(
      title: title ?? this.title,
      status: status ?? this.status,
      columnId: columnId == _sentinel ? this.columnId : columnId as String?,
      parentTaskId: parentTaskId == _sentinel
          ? this.parentTaskId
          : parentTaskId as String?,
      blocked: blocked ?? this.blocked,
      blockedReason: blockedReason == _sentinel
          ? this.blockedReason
          : (blockedReason as String),
      priority: priority == _sentinel ? this.priority : priority as String?,
      description: description == _sentinel
          ? this.description
          : (description as String),
      startDate:
          startDate == _sentinel ? this.startDate : startDate as String?,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as String?,
      timeSpentMinutes: timeSpentMinutes == _sentinel
          ? this.timeSpentMinutes
          : timeSpentMinutes as int?,
      subtasks: subtasks == _sentinel
          ? this.subtasks
          : (subtasks as List<FolioTaskSubtask>),
    );
  }

  static const Object _sentinel = Object();

  /// Columna efectiva para la UI Kanban.
  String effectiveColumnId({Set<String>? allowedColumnIds}) {
    final cid = (columnId ?? '').trim();
    if (cid.isNotEmpty &&
        (allowedColumnIds == null || allowedColumnIds.contains(cid))) {
      return cid;
    }
    if (status == 'in_progress') return 'in_progress';
    if (status == 'done') return 'done';
    return 'todo';
  }

  String encode() => jsonEncode({
    'v': 3,
    'title': title,
    'status': status,
    if ((columnId ?? '').trim().isNotEmpty) 'columnId': columnId,
    if ((parentTaskId ?? '').trim().isNotEmpty) 'parentTaskId': parentTaskId,
    if (blocked) 'blocked': true,
    if (blockedReason.trim().isNotEmpty) 'blockedReason': blockedReason,
    if (priority != null) 'priority': priority,
    if (description.trim().isNotEmpty) 'description': description,
    if (startDate != null) 'startDate': startDate,
    if (dueDate != null) 'dueDate': dueDate,
    if (timeSpentMinutes != null) 'timeSpentMinutes': timeSpentMinutes,
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
      final rawColumnId = (m['columnId'] as String?)?.trim();
      final rawParent = (m['parentTaskId'] as String?)?.trim();
      final rawBlocked = m['blocked'] == true;
      final rawBlockedReason = (m['blockedReason'] as String?) ?? '';
      final rawDescription = (m['description'] as String?) ?? '';
      final rawStartDate = (m['startDate'] as String?)?.trim();
      final rawTimeSpent = m['timeSpentMinutes'];
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
        columnId: (rawColumnId?.isEmpty ?? true) ? null : rawColumnId,
        parentTaskId: (rawParent?.isEmpty ?? true) ? null : rawParent,
        blocked: rawBlocked,
        blockedReason: rawBlockedReason,
        description: rawDescription,
        startDate: (rawStartDate?.isEmpty ?? true) ? null : rawStartDate,
        dueDate: (m['dueDate'] as String?),
        timeSpentMinutes: rawTimeSpent is num ? rawTimeSpent.toInt() : null,
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
    required this.status,
    this.columnId,
    this.priority,
    this.description = '',
    this.startDate,
    this.dueDate,
    this.timeSpentMinutes,
  });

  final String id;
  final String title;
  final String status;
  final String? columnId;
  final String? priority;
  final String description;
  final String? startDate;
  final String? dueDate;
  final int? timeSpentMinutes;

  FolioTaskSubtask copyWith({
    String? id,
    String? title,
    String? status,
    Object? columnId = FolioTaskData._sentinel,
    Object? priority = FolioTaskData._sentinel,
    Object? description = FolioTaskData._sentinel,
    Object? startDate = FolioTaskData._sentinel,
    Object? dueDate = FolioTaskData._sentinel,
    Object? timeSpentMinutes = FolioTaskData._sentinel,
  }) {
    return FolioTaskSubtask(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      columnId: columnId == FolioTaskData._sentinel
          ? this.columnId
          : columnId as String?,
      priority: priority == FolioTaskData._sentinel
          ? this.priority
          : priority as String?,
      description: description == FolioTaskData._sentinel
          ? this.description
          : (description as String),
      startDate: startDate == FolioTaskData._sentinel
          ? this.startDate
          : startDate as String?,
      dueDate: dueDate == FolioTaskData._sentinel ? this.dueDate : dueDate as String?,
      timeSpentMinutes: timeSpentMinutes == FolioTaskData._sentinel
          ? this.timeSpentMinutes
          : timeSpentMinutes as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        if ((columnId ?? '').trim().isNotEmpty) 'columnId': columnId,
        if (priority != null) 'priority': priority,
        if (description.trim().isNotEmpty) 'description': description,
        if (startDate != null) 'startDate': startDate,
        if (dueDate != null) 'dueDate': dueDate,
        if (timeSpentMinutes != null) 'timeSpentMinutes': timeSpentMinutes,
      };

  static FolioTaskSubtask? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final title = (map['title'] as String? ?? '').trim();
    if (id.isEmpty && title.isEmpty) return null;
    final rawStatus = (map['status'] as String?) ??
        ((map['done'] == true) ? 'done' : 'todo'); // compat v1
    final status =
        FolioTaskData._validStatuses.contains(rawStatus) ? rawStatus : 'todo';
    final rawPriority = map['priority'] as String?;
    final priority = FolioTaskData._validPriorities.contains(rawPriority)
        ? rawPriority
        : null;
    return FolioTaskSubtask(
      id: id.isEmpty ? title.hashCode.toString() : id,
      title: title,
      status: status,
      columnId: (map['columnId'] as String?)?.trim().isNotEmpty == true
          ? (map['columnId'] as String).trim()
          : null,
      priority: priority,
      description: (map['description'] as String?) ?? '',
      startDate: (map['startDate'] as String?)?.trim(),
      dueDate: (map['dueDate'] as String?)?.trim(),
      timeSpentMinutes:
          map['timeSpentMinutes'] is num ? (map['timeSpentMinutes'] as num).toInt() : null,
    );
  }
}
