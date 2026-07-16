import 'dart:async';

import '../../models/folio_task_data.dart';
import '../../session/vault_session.dart';

/// Información de una tarea vencida o que vence hoy.
class TaskReminderEvent {
  const TaskReminderEvent({
    required this.pageId,
    required this.pageTitle,
    required this.blockId,
    required this.taskTitle,
    required this.dueDate,
    required this.isOverdue,
  });

  final String pageId;
  final String pageTitle;
  final String blockId;
  final String taskTitle;

  /// Fecha límite en formato 'YYYY-MM-DD'.
  final String dueDate;

  /// true si la fecha ya pasó, false si es hoy.
  final bool isOverdue;
}

/// Servicio ligero que comprueba periódicamente las tareas con recordatorio
/// activo y emite eventos cuando una tarea vence hoy o ya está vencida.
///
/// No usa notificaciones nativas: emite por [stream] para que la UI muestre
/// un banner in-app. Se puede ampliar con flutter_local_notifications en el
/// futuro sin cambiar la lógica de detección.
class TaskReminderService {
  TaskReminderService({required VaultSession session}) : _session = session;

  final VaultSession _session;

  final _controller = StreamController<List<TaskReminderEvent>>.broadcast();
  Timer? _timer;

  /// Stream de listas de tareas que vencen hoy o están vencidas y tienen
  /// [FolioTaskData.reminderEnabled] == true.
  Stream<List<TaskReminderEvent>> get stream => _controller.stream;

  /// Inicia las comprobaciones periódicas.
  ///
  /// [checkInterval] controla la frecuencia. Por defecto comprueba una vez al
  /// día, pero en tests se puede pasar un intervalo más corto.
  void start({Duration checkInterval = const Duration(hours: 1)}) {
    _check();
    _timer = Timer.periodic(checkInterval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _check() {
    final today = _todayIso();
    final events = <TaskReminderEvent>[];

    for (final page in _session.pages) {
      for (final block in page.blocks) {
        if (block.type != 'task') continue;
        final data = FolioTaskData.tryParse(block.text);
        if (data == null) continue;
        if (!data.reminderEnabled) continue;
        if (data.status == 'done') continue;
        final due = data.dueDate;
        if (due == null) continue;

        final dueDay = due.length >= 10 ? due.substring(0, 10) : due;
        final isToday = dueDay == today;
        final isOverdue = dueDay.compareTo(today) < 0;

        if (isToday || isOverdue) {
          events.add(
            TaskReminderEvent(
              pageId: page.id,
              pageTitle: page.title,
              blockId: block.id,
              taskTitle: data.title.trim().isNotEmpty
                  ? data.title.trim()
                  : 'Tarea sin título',
              dueDate: due,
              isOverdue: isOverdue,
            ),
          );
        }
      }
    }

    if (events.isNotEmpty) {
      _controller.add(events);
    }
  }

  /// Avanza la fecha de vencimiento según la recurrencia de [data] y devuelve
  /// el nuevo [FolioTaskData] con [status] reseteado a `'todo'` y la nueva
  /// fecha. Devuelve null si no hay recurrencia configurada.
  static FolioTaskData? advanceRecurrence(FolioTaskData data) {
    final due = data.dueDate;
    var recurrence = data.recurrence;
    if (recurrence == null) {
      final rr = (data.recurringRule ?? '').trim().toUpperCase();
      if (rr.startsWith('FREQ=DAILY')) {
        recurrence = 'daily';
      } else if (rr.startsWith('FREQ=WEEKLY')) {
        recurrence = 'weekly';
      } else if (rr.startsWith('FREQ=MONTHLY')) {
        recurrence = 'monthly';
      } else if (rr.startsWith('FREQ=YEARLY')) {
        recurrence = 'yearly';
      }
    }
    if (due == null || recurrence == null) return null;

    final date = DateTime.tryParse(due);
    if (date == null) return null;

    final DateTime next;
    switch (recurrence) {
      case 'daily':
        next = date.add(const Duration(days: 1));
        break;
      case 'weekly':
        next = date.add(const Duration(days: 7));
        break;
      case 'monthly':
        next = DateTime(date.year, date.month + 1, date.day);
        break;
      case 'yearly':
        next = DateTime(date.year + 1, date.month, date.day);
        break;
      default:
        return null;
    }

    final hasTime = due.contains('T');
    final timeStr = hasTime ? due.substring(10) : ''; // e.g. 'T14:30'

    final iso =
        '${next.year.toString().padLeft(4, '0')}-'
        '${next.month.toString().padLeft(2, '0')}-'
        '${next.day.toString().padLeft(2, '0')}'
        '$timeStr';

    return data.copyWith(status: 'todo', dueDate: iso);
  }

  static String _todayIso() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
