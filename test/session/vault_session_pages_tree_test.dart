import 'package:flutter_test/flutter_test.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('VaultSession pages tree + ordering', () {
    test('tracks order per parent and can reorder within root', () {
      final s = VaultSession();
      s.addPage(parentId: null);
      final a = s.selectedPage!.id;
      s.addPage(parentId: null);
      final b = s.selectedPage!.id;
      s.addPage(parentId: null);
      final c = s.selectedPage!.id;

      expect(s.pageOrderForParent(null), [a, b, c]);

      s.movePage(pageId: c, newParentId: null, newIndex: 0);
      expect(s.pageOrderForParent(null), [c, a, b]);
    });

    test('can nest into a folder and prevents cycles', () {
      final s = VaultSession();
      s.addFolder(parentId: null);
      final folderId = s.pages.last.id;
      expect(s.pages.last.isFolder, isTrue);

      s.addPage(parentId: null);
      final pageId = s.selectedPage!.id;

      s.movePage(pageId: pageId, newParentId: folderId, newIndex: 0);
      final moved = s.pages.firstWhere((p) => p.id == pageId);
      expect(moved.parentId, folderId);
      expect(s.pageOrderForParent(folderId), [pageId]);

      // cycle: try moving folder under its descendant => no-op
      s.movePage(pageId: folderId, newParentId: pageId, newIndex: 0);
      final folder = s.pages.firstWhere((p) => p.id == folderId);
      expect(folder.parentId, isNull);
    });

    test('deleteFolderMoveChildrenToRoot moves children and deletes folder', () {
      final s = VaultSession();
      s.addFolder(parentId: null);
      final folderId = s.pages.last.id;

      s.addPage(parentId: null);
      final childId = s.selectedPage!.id;
      s.movePage(pageId: childId, newParentId: folderId, newIndex: 0);

      s.deleteFolderMoveChildrenToRoot(folderId);

      expect(s.pages.any((p) => p.id == folderId), isFalse);
      final child = s.pages.firstWhere((p) => p.id == childId);
      expect(child.parentId, isNull);
      expect(s.pageOrderForParent(null).contains(childId), isTrue);
    });
  });
}

