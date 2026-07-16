import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/tasks/task_quick_capture_parser.dart';

void main() {
  final fixedNow = DateTime(2026, 4, 16, 12);

  test('parse title and due tomorrow', () {
    final r = TaskQuickCaptureParser.parse(
      'Comprar leche mañana',
      nowLocal: fixedNow,
    );
    expect(r.task.title, 'Comprar leche');
    expect(r.task.dueDate, '2026-04-17');
    expect(r.task.status, 'todo');
  });

  test('parse explicit due and priority', () {
    final r = TaskQuickCaptureParser.parse(
      'Reunión due:2026-04-20 alta',
      nowLocal: fixedNow,
    );
    expect(r.task.title, 'Reunión');
    expect(r.task.dueDate, '2026-04-20');
    expect(r.task.priority, 'high');
  });

  test('alias routes to page id', () {
    final r = TaskQuickCaptureParser.parse(
      'Hacer informe #trabajo',
      nowLocal: fixedNow,
      aliasToPageId: {'#trabajo': 'page-1', 'trabajo': 'page-1'},
    );
    expect(r.task.title, 'Hacer informe');
    expect(r.targetPageIdFromAlias, 'page-1');
  });

  test('parse !! as highest priority and inline #tags', () {
    final r = TaskQuickCaptureParser.parse(
      'Revisar PR !! #review #cliente',
      nowLocal: fixedNow,
    );
    expect(r.task.priority, 'highest');
    expect(r.task.tags, containsAll(['review', 'cliente']));
    expect(r.task.title, 'Revisar PR');
  });

  test('parse time 3pm with tomorrow', () {
    final r = TaskQuickCaptureParser.parse(
      'Llamar mañana 3pm',
      nowLocal: fixedNow,
    );
    expect(r.task.dueDate, '2026-04-17T15:00');
    expect(r.task.title, 'Llamar');
  });

  test('parse 24h time', () {
    final r = TaskQuickCaptureParser.parse(
      'due:2026-04-20 14:30 reunión',
      nowLocal: fixedNow,
    );
    expect(r.task.dueDate, '2026-04-20T14:30');
    expect(r.task.title, 'reunión');
  });
}
