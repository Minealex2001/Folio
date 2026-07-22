import '../../models/vault_task_list_entry.dart';

/// Exporta tareas del vault a iCalendar (.ics).
abstract final class FolioIcsExport {
  /// Genera un calendario con VEVENT all-day para tareas con fecha.
  static String exportTasks(List<VaultTaskListEntry> entries) {
    final withDate = entries.where((e) {
      if (e.blockType != 'task') return false;
      final due = (e.dueDate ?? '').trim();
      final start = (e.startDate ?? '').trim();
      return due.isNotEmpty || start.isNotEmpty;
    }).toList(growable: false);

    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Folio//Task Export//EN');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');

    for (final e in withDate) {
      final task = e.task;
      if (task == null) continue;
      final startRaw = (e.startDate ?? '').trim();
      final dueRaw = (e.dueDate ?? '').trim();
      final day = _ymd(startRaw.isNotEmpty ? startRaw : dueRaw);
      if (day == null) continue;
      // DTEND de un VEVENT all-day es exclusivo (RFC 5545): siempre un día
      // después del último día real del evento, o due==start produce un
      // evento de duración cero que algunos clientes descartan.
      final endDay = dueRaw.isNotEmpty && startRaw.isNotEmpty
          ? _addDays(_ymd(dueRaw) ?? day, 1)
          : _addDays(day, 1);

      buf.writeln('BEGIN:VEVENT');
      buf.writeln('UID:folio-${e.pageId}-${e.blockId}@folio.local');
      buf.writeln('DTSTAMP:${_utcStamp(DateTime.now().toUtc())}');
      buf.writeln('DTSTART;VALUE=DATE:$day');
      buf.writeln('DTEND;VALUE=DATE:$endDay');
      buf.writeln('SUMMARY:${_escape(e.displayTitle)}');
      final desc = (task.description).trim();
      if (desc.isNotEmpty) {
        buf.writeln('DESCRIPTION:${_escape(desc)}');
      }
      // Sin _escape(): RRULE es una línea de propiedad, no un valor TEXT, así
      // que no admite secuencias \n/\; — basta con impedir que un salto de
      // línea incrustado inyecte líneas ICS adicionales.
      final rrule = (task.recurringRule ?? '')
          .replaceAll('\r', '')
          .replaceAll('\n', ' ')
          .trim();
      if (rrule.isNotEmpty) {
        final rule = rrule.toUpperCase().startsWith('RRULE:')
            ? rrule
            : 'RRULE:$rrule';
        buf.writeln(rule);
      }
      if (task.reminderEnabled) {
        buf.writeln('BEGIN:VALARM');
        buf.writeln('TRIGGER:-PT9H');
        buf.writeln('ACTION:DISPLAY');
        buf.writeln('DESCRIPTION:${_escape(e.displayTitle)}');
        buf.writeln('END:VALARM');
      }
      if (e.isDone) {
        buf.writeln('STATUS:COMPLETED');
      } else if (e.isBlocked) {
        buf.writeln('STATUS:TENTATIVE');
      } else {
        buf.writeln('STATUS:CONFIRMED');
      }
      buf.writeln('END:VEVENT');
    }

    buf.writeln('END:VCALENDAR');
    return buf.toString().replaceAll('\n', '\r\n');
  }

  static String? _ymd(String iso) {
    final t = iso.trim();
    if (t.length >= 10) {
      final candidate = t.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(candidate)) {
        return candidate.replaceAll('-', '');
      }
    }
    final parsed = DateTime.tryParse(t);
    if (parsed == null) return null;
    final d = parsed.toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  static String _addDays(String yyyymmdd, int days) {
    final y = int.parse(yyyymmdd.substring(0, 4));
    final m = int.parse(yyyymmdd.substring(4, 6));
    final d = int.parse(yyyymmdd.substring(6, 8));
    final dt = DateTime.utc(y, m, d).add(Duration(days: days));
    final yy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$yy$mm$dd';
  }

  static String _utcStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min${s}Z';
  }

  static String _escape(String raw) {
    return raw
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
  }
}
