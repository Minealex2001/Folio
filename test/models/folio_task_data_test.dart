import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_task_data.dart';

void main() {
  group('FolioTaskData', () {
    test('serializa y parsea subtareas', () {
      final data = FolioTaskData(
        title: 'Implementar bloque',
        status: 'in_progress',
        priority: 'high',
        dueDate: '2026-03-31',
        subtasks: const [
          FolioTaskSubtask(id: 's1', title: 'Modelo', status: 'done'),
          FolioTaskSubtask(id: 's2', title: 'UI', status: 'todo'),
        ],
      );

      final parsed = FolioTaskData.tryParse(data.encode());
      expect(parsed, isNotNull);
      expect(parsed!.title, 'Implementar bloque');
      expect(parsed.status, 'in_progress');
      expect(parsed.priority, 'high');
      expect(parsed.dueDate, '2026-03-31');
      expect(parsed.subtasks.length, 2);
      expect(parsed.subtasks.first.status, 'done');
      expect(parsed.subtasks.last.title, 'UI');
    });

    test('mantiene compatibilidad con payload sin subtareas', () {
      const raw = '{"v":1,"title":"Legacy","status":"todo"}';
      final parsed = FolioTaskData.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.title, 'Legacy');
      expect(parsed.subtasks, isEmpty);
    });

    test('copyWith permite reemplazar subtareas', () {
      final base = FolioTaskData.defaults();
      final next = base.copyWith(
        subtasks: const [
          FolioTaskSubtask(id: 'a', title: 'Primera', status: 'todo'),
        ],
      );
      expect(next.subtasks.length, 1);
      expect(next.subtasks.first.id, 'a');
    });
  });
}
