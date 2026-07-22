import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/models/vault_task_list_entry.dart';
import 'package:folio/services/calendar/folio_ics_export.dart';

void main() {
  test('exportTasks emits VEVENT for dated tasks', () {
    final ics = FolioIcsExport.exportTasks([
      VaultTaskListEntry(
        pageId: 'p1',
        pageTitle: 'Inbox',
        blockId: 'b1',
        blockType: 'task',
        task: FolioTaskData.defaults().copyWith(
          title: 'Ship Folio',
          dueDate: '2026-07-21',
          reminderEnabled: true,
        ),
      ),
    ]);
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('SUMMARY:Ship Folio'));
    expect(ics, contains('DTSTART;VALUE=DATE:20260721'));
    expect(ics, contains('BEGIN:VALARM'));
    expect(ics, contains('UID:folio-p1-b1@folio.local'));
  });

  test('exportTasks skips tasks without dates', () {
    final ics = FolioIcsExport.exportTasks([
      VaultTaskListEntry(
        pageId: 'p1',
        pageTitle: 'Inbox',
        blockId: 'b1',
        blockType: 'task',
        task: FolioTaskData.defaults().copyWith(title: 'No date'),
      ),
    ]);
    expect(ics, isNot(contains('BEGIN:VEVENT')));
  });
}
