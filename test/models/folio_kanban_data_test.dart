import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_kanban_data.dart';

void main() {
  group('FolioKanbanData', () {
    test('defaults encode y parse', () {
      final d = FolioKanbanData.defaults();
      final parsed = FolioKanbanData.tryParse(d.encode());
      expect(parsed, isNotNull);
      expect(parsed!.v, 2);
      expect(parsed.includeSimpleTodos, isTrue);
      expect(parsed.columns.length, 3);
      expect(parsed.viewMode, FolioKanbanViewMode.kanban);
      expect(parsed.columns.map((c) => c.id).toSet(),
          containsAll(<String>{'todo', 'in_progress', 'done'}));
    });

    test('preserva includeSimpleTodos y columnas válidas', () {
      final raw =
          '{"v":2,"includeSimpleTodos":false,"viewMode":"list","columns":['
          '{"id":"todo","title":"A","colorArgb":4287137920},'
          '{"id":"in_progress","title":"","colorArgb":4282540741},'
          '{"id":"done","title":"C","colorArgb":4284923690}'
          ']}';
      final parsed = FolioKanbanData.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.includeSimpleTodos, isFalse);
      expect(parsed.viewMode, FolioKanbanViewMode.list);
      expect(parsed.columns.first.title, 'A');
      expect(parsed.columns[2].title, 'C');
    });

    test('serializa y parsea config Jira mínima (jiraSourceId)', () {
      final d = FolioKanbanData.defaults().copyWith(
        jiraSourceId: 'jira_source_1',
        jiraAutoImport: true,
        jiraCreateIssuesOnQuickAdd: true,
      );
      final parsed = FolioKanbanData.tryParse(d.encode());
      expect(parsed, isNotNull);
      expect(parsed!.jiraSourceId, 'jira_source_1');
      expect(parsed.jiraAutoImport, isTrue);
      expect(parsed.jiraCreateIssuesOnQuickAdd, isTrue);
    });

    test('permite columnas parciales (usuario puede personalizar)', () {
      const raw = '{"v":2,"includeSimpleTodos":true,"columns":[{"id":"todo"}]}';
      final parsed = FolioKanbanData.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.columns.length, 1);
    });
  });
}
