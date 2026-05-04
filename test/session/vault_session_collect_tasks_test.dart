import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('VaultSession collectTaskBlocks', () {
    test('pageId filtra a una sola página', () {
      final s = VaultSession();
      s.debugMarkUnlockedForTests();
      s.addPage(parentId: null);
      final p1 = s.selectedPage!.id;
      s.addPage(parentId: null);
      final p2 = s.selectedPage!.id;

      s.appendBlock(
        pageId: p1,
        block: FolioBlock(
          id: '${p1}_task1',
          type: 'task',
          text: FolioTaskData(title: 'A', status: 'todo').encode(),
        ),
      );
      s.appendBlock(
        pageId: p2,
        block: FolioBlock(
          id: '${p2}_task2',
          type: 'task',
          text: FolioTaskData(title: 'B', status: 'done').encode(),
        ),
      );

      final all = s.collectTaskBlocks();
      expect(all.length, 2);

      final only1 = s.collectTaskBlocks(pageId: p1);
      expect(only1.length, 1);
      expect(only1.single.displayTitle, 'A');

      final only2 = s.collectTaskBlocks(pageId: p2);
      expect(only2.length, 1);
      expect(only2.single.displayTitle, 'B');

      expect(s.collectTaskBlocks(pageId: 'missing'), isEmpty);
    });

    test('moveBlockToPage mueve bloque task y limpia parentTaskId', () {
      final s = VaultSession();
      s.debugMarkUnlockedForTests();
      s.addPage(parentId: null);
      final p1 = s.selectedPage!.id;
      s.addPage(parentId: null);
      final p2 = s.selectedPage!.id;
      const taskId = 'p1_taskmove';
      s.appendBlock(
        pageId: p1,
        block: FolioBlock(
          id: taskId,
          type: 'task',
          text: FolioTaskData(
            title: 'Move me',
            status: 'todo',
            parentTaskId: 'some_parent',
          ).encode(),
        ),
      );

      s.moveBlockToPage(fromPageId: p1, toPageId: p2, blockId: taskId);

      final p1page = s.pages.firstWhere((p) => p.id == p1);
      final p2page = s.pages.firstWhere((p) => p.id == p2);
      expect(p1page.blocks.any((b) => b.id == taskId), isFalse);
      final moved = p2page.blocks.where((b) => b.type == 'task').single;
      expect(moved.id.startsWith('${p2}_'), isTrue);
      final data = FolioTaskData.tryParse(moved.text);
      expect(data, isNotNull);
      expect(data!.title, 'Move me');
      expect(data.parentTaskId, isNull);
    });
  });
}
