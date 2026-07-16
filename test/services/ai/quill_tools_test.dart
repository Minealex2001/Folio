import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/services/ai/quill_tools.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  test('QuillToolExecutor.insertTodosFromLines appends todos', () {
    final session = VaultSession();
    session.addPage(parentId: null);
    final pageId = session.selectedPage!.id;
    QuillToolExecutor.insertTodosFromLines(
      session,
      pageId: pageId,
      lines: const ['  A  ', '', 'B'],
    );
    final page = session.pages.firstWhere((p) => p.id == pageId);
    final todos = page.blocks.where((b) => b.type == 'todo').toList();
    expect(todos.length, 2);
    expect(todos[0].text, 'A');
    expect(todos[1].text, 'B');
  });

  test('QuillToolExecutor.insertTasksFromEncodedLines appends task blocks', () {
    final session = VaultSession();
    session.addPage(parentId: null);
    final pageId = session.selectedPage!.id;
    final jsonLine = FolioTaskData(
      title: 'From JSON',
      status: 'todo',
      dueDate: '2026-06-01',
    ).encode();
    QuillToolExecutor.insertTasksFromEncodedLines(
      session,
      pageId: pageId,
      payloads: ['Plain title', jsonLine],
    );
    final page = session.pages.firstWhere((p) => p.id == pageId);
    final tasks = page.blocks.where((b) => b.type == 'task').toList();
    expect(tasks.length, 2);
    final first = FolioTaskData.tryParse(tasks[0].text);
    expect(first?.title, 'Plain title');
    final second = FolioTaskData.tryParse(tasks[1].text);
    expect(second?.title, 'From JSON');
    expect(second?.dueDate, '2026-06-01');
  });

  test('QuillToolCall execute dispatches insertTasksFromEncodedLines', () {
    final session = VaultSession();
    session.addPage(parentId: null);
    final pageId = session.selectedPage!.id;
    QuillToolExecutor.execute(
      session,
      QuillToolCall(
        kind: QuillToolKind.insertTasksFromEncodedLines,
        pageId: pageId,
        taskPayloads: const ['A'],
      ),
    );
    final page = session.pages.firstWhere((p) => p.id == pageId);
    expect(page.blocks.where((b) => b.type == 'task').length, 1);
  });
}
