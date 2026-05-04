import '../../models/folio_task_data.dart';

/// Resultado de analizar una línea de captura rápida.
class TaskQuickCaptureResult {
  TaskQuickCaptureResult({
    required this.task,
    this.consumedAliasTag,
    this.targetPageIdFromAlias,
  });

  final FolioTaskData task;

  /// Etiqueta `#foo` o `@foo` retirada del título, si hubo coincidencia en el mapa.
  final String? consumedAliasTag;

  /// Página destino si [consumedAliasTag] resolvió en [aliasToPageId].
  final String? targetPageIdFromAlias;
}

/// Parser heurístico (es/en) para título, prioridad, fecha y alias.
class TaskQuickCaptureParser {
  TaskQuickCaptureParser._();

  static TaskQuickCaptureResult parse(
    String raw, {
    required DateTime nowLocal,
    Map<String, String> aliasToPageId = const {},
  }) {
    var line = raw.trim();
    if (line.isEmpty) {
      return TaskQuickCaptureResult(task: FolioTaskData.defaults());
    }

    String? aliasTag;
    String? targetPageId;

    final aliasMatch = RegExp(r'(?:^|\s)([#@])([\w\-]+)$').firstMatch(line);
    if (aliasMatch != null) {
      final sym = aliasMatch.group(1)!;
      final tag = aliasMatch.group(2)!.toLowerCase();
      final key = '$sym$tag';
      final pageId = aliasToPageId[key] ?? aliasToPageId[tag];
      if (pageId != null && pageId.isNotEmpty) {
        aliasTag = key;
        targetPageId = pageId;
        line = line.substring(0, aliasMatch.start).trimRight();
      }
    }

    String? due;
    line = line.replaceAllMapped(
      RegExp(
        r'\b(?:due|vence|para)\s*:\s*(\d{4}-\d{2}-\d{2})\b',
        caseSensitive: false,
      ),
      (m) {
        due = m.group(1);
        return '';
      },
    );
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();

    final lowerBeforeRelative = line.toLowerCase();
    final relative = _relativeDueAndStrippedLine(lowerBeforeRelative, line, nowLocal);
    due ??= relative.$1;
    line = relative.$2;
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();

    final timeStrip = _consumeTimeFromLine(line);
    line = timeStrip.stripped;
    if (due != null && timeStrip.hhmm != null && !due!.contains('T')) {
      due = '$due${timeStrip.hhmm}';
    }
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();

    final hashTags = <String>[];
    line = line.replaceAllMapped(
      RegExp(r'(?:^|\s)#([\w\-]+)(?=\s|$)', caseSensitive: false),
      (m) {
        hashTags.add(m.group(1)!);
        return ' ';
      },
    );
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();

    final lower = line.toLowerCase();
    String? priority;
    if (lower.contains('!!')) {
      priority = 'highest';
    } else if (_containsWord(lower, const ['p1', 'urgente', 'urgent', '!', 'alta', 'high'])) {
      priority = 'high';
    } else if (_containsWord(lower, const ['p2', 'media', 'medium', 'normal'])) {
      priority = 'medium';
    } else if (_containsWord(lower, const ['p3', 'baja', 'low'])) {
      priority = 'low';
    }

    var status = 'todo';
    if (_containsPhrase(lower, const [
      'en progreso',
      'in progress',
      'doing',
      'wip',
    ])) {
      status = 'in_progress';
    }

    var title = _stripPriorityTokens(_stripStatusTokens(line)).trim();
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) {
      title = FolioTaskData.defaults().title;
    }

    return TaskQuickCaptureResult(
      task: FolioTaskData(
        title: title,
        status: status,
        columnId: status,
        priority: priority,
        dueDate: due,
        tags: hashTags,
        subtasks: const [],
      ),
      consumedAliasTag: aliasTag,
      targetPageIdFromAlias: targetPageId,
    );
  }

  /// Quita la primera hora reconocida y devuelve sufijo `THH:MM` para combinar
  /// con una fecha `YYYY-MM-DD`.
  static _TimeStrip _consumeTimeFromLine(String line) {
    var s = line;
    String? hhmm;

    Match? m12 = RegExp(
      r'\b(?:@|at|a las|las)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(s);
    m12 ??= RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(s);
    if (m12 != null) {
      var h = int.parse(m12.group(1)!);
      final min = int.tryParse(m12.group(2) ?? '0') ?? 0;
      final ap = (m12.group(3) ?? '').toLowerCase();
      if (ap == 'pm' && h < 12) {
        h += 12;
      }
      if (ap == 'am' && h == 12) {
        h = 0;
      }
      if (h >= 0 && h < 24 && min >= 0 && min < 60) {
        hhmm =
            'T${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
        s = '${s.substring(0, m12.start)} ${s.substring(m12.end)}';
      }
    } else {
      final m24 = RegExp(
        r'\b([01]?\d|2[0-3]):([0-5]\d)\b',
        caseSensitive: false,
      ).firstMatch(s);
      if (m24 != null) {
        final h = int.parse(m24.group(1)!);
        final min = int.parse(m24.group(2)!);
        hhmm =
            'T${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
        s = '${s.substring(0, m24.start)} ${s.substring(m24.end)}';
      }
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _TimeStrip(s, hhmm);
  }

  static bool _containsWord(String lower, List<String> tokens) {
    for (final t in tokens) {
      if (t == '!') {
        if (lower.contains('!')) return true;
        continue;
      }
      if (RegExp('(^|\\s)${RegExp.escape(t)}(\\s|\$)').hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsPhrase(String lower, List<String> phrases) {
    for (final p in phrases) {
      if (lower.contains(p)) return true;
    }
    return false;
  }

  static String _stripPriorityTokens(String line) {
    var s = line;
    for (final p in ['p1', 'p2', 'p3', 'urgente', 'urgent', 'alta', 'high', 'media', 'medium', 'normal', 'baja', 'low']) {
      s = s.replaceAll(RegExp('(^|\\s)${RegExp.escape(p)}(\\s|\$)', caseSensitive: false), ' ');
    }
    s = s.replaceAll('!!', ' ');
    s = s.replaceAll('!', '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripStatusTokens(String line) {
    var s = line;
    for (final p in ['en progreso', 'in progress', 'doing', 'wip']) {
      s = s.replaceAll(RegExp(RegExp.escape(p), caseSensitive: false), ' ');
    }
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Si encuentra fecha relativa, devuelve (iso, línea sin esas palabras).
  static (String?, String) _relativeDueAndStrippedLine(
    String lower,
    String originalLine,
    DateTime nowLocal,
  ) {
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    var line = originalLine;

    void stripPhrase(String phrase) {
      line = line.replaceAll(RegExp(RegExp.escape(phrase), caseSensitive: false), ' ');
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    if (_containsPhrase(lower, const ['pasado mañana', 'day after tomorrow'])) {
      for (final p in ['pasado mañana', 'day after tomorrow']) {
        stripPhrase(p);
      }
      return (_isoDate(today.add(const Duration(days: 2))), line);
    }
    if (_containsPhrase(lower, const ['próxima semana', 'proxima semana', 'next week'])) {
      for (final p in ['próxima semana', 'proxima semana', 'next week']) {
        stripPhrase(p);
      }
      return (_isoDate(today.add(const Duration(days: 14))), line);
    }
    if (_containsPhrase(lower, const ['esta semana', 'this week'])) {
      for (final p in ['esta semana', 'this week']) {
        stripPhrase(p);
      }
      return (_isoDate(today.add(const Duration(days: 7))), line);
    }
    if (_containsWord(lower, const ['mañana', 'tomorrow'])) {
      for (final p in ['mañana', 'tomorrow']) {
        line = line.replaceAll(RegExp('(^|\\s)${RegExp.escape(p)}(\\s|\$)', caseSensitive: false), ' ');
      }
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      return (_isoDate(today.add(const Duration(days: 1))), line);
    }
    if (_containsWord(lower, const ['hoy', 'today'])) {
      for (final p in ['hoy', 'today']) {
        line = line.replaceAll(RegExp('(^|\\s)${RegExp.escape(p)}(\\s|\$)', caseSensitive: false), ' ');
      }
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      return (_isoDate(today), line);
    }
    return (null, originalLine);
  }

  static String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _TimeStrip {
  const _TimeStrip(this.stripped, this.hhmm);

  final String stripped;
  final String? hhmm;
}
