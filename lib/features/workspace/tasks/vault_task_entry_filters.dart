import '../../../models/vault_task_list_entry.dart';

/// Vistas rápidas sobre [VaultTaskListEntry] en toda la libreta.
enum VaultTaskListPreset {
  all,
  active,
  done,
  dueToday,
  next7Days,
  overdue,
  noDueDate,
}

DateTime? vaultTaskDueDay(VaultTaskListEntry e) {
  final raw = e.dueDate;
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

bool vaultTaskEntryMatchesPreset(
  VaultTaskListPreset preset,
  VaultTaskListEntry e,
  DateTime nowLocal,
) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  switch (preset) {
    case VaultTaskListPreset.all:
      return true;
    case VaultTaskListPreset.active:
      return !e.isDone;
    case VaultTaskListPreset.done:
      return e.isDone;
    case VaultTaskListPreset.dueToday:
      if (e.isDone) return false;
      final due = vaultTaskDueDay(e);
      return due != null && due == today;
    case VaultTaskListPreset.next7Days:
      if (e.isDone) return false;
      final due = vaultTaskDueDay(e);
      if (due == null) return false;
      final end = today.add(const Duration(days: 7));
      return !due.isBefore(today) && !due.isAfter(end);
    case VaultTaskListPreset.overdue:
      if (e.isDone) return false;
      if (e.blockType != 'task') return false;
      final due = vaultTaskDueDay(e);
      return due != null && due.isBefore(today);
    case VaultTaskListPreset.noDueDate:
      if (e.isDone) return false;
      final raw = e.dueDate;
      return raw == null || raw.trim().isEmpty;
  }
}

bool vaultTaskEntryMatchesSearch(
  VaultTaskListEntry e,
  String queryLower,
) {
  if (queryLower.isEmpty) return true;
  final title = e.displayTitle.toLowerCase();
  final page = e.pageTitle.toLowerCase();
  if (title.contains(queryLower) || page.contains(queryLower)) {
    return true;
  }
  final tags = e.task?.tags ?? const [];
  for (final t in tags) {
    if (t.toLowerCase().contains(queryLower)) return true;
  }
  final assignee = (e.task?.assignee ?? '').toLowerCase();
  if (assignee.isNotEmpty && assignee.contains(queryLower)) return true;
  return false;
}

int vaultTaskSortByDueThenTitle(VaultTaskListEntry a, VaultTaskListEntry b) {
  final da = vaultTaskDueDay(a);
  final db = vaultTaskDueDay(b);
  if (da != null && db != null) {
    final c = da.compareTo(db);
    if (c != 0) return c;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  return a.displayTitle.compareTo(b.displayTitle);
}
