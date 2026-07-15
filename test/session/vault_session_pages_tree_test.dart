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

  group('VaultSession page trash', () {
    test('movePageToTrash soft-deletes entire active subtree', () {
      final s = VaultSession();
      s.addFolder(parentId: null);
      final folderId = s.pages.last.id;
      s.addPage(parentId: null);
      final keepId = s.selectedPage!.id;
      s.addPage(parentId: null);
      final childId = s.selectedPage!.id;
      s.movePage(pageId: childId, newParentId: folderId, newIndex: 0);

      expect(s.canMovePageToTrash(folderId), isTrue);
      s.movePageToTrash(folderId);

      expect(s.activePages.map((p) => p.id), [keepId]);
      expect(s.trashedPages.map((p) => p.id).toSet(), {folderId, childId});
      expect(s.pages.firstWhere((p) => p.id == folderId).isTrashed, isTrue);
      expect(s.pages.firstWhere((p) => p.id == childId).isTrashed, isTrue);
      expect(s.trashRootPages.map((p) => p.id), [folderId]);
    });

    test('restoreFromTrash restores subtree together', () {
      final s = VaultSession();
      s.addFolder(parentId: null);
      final folderId = s.pages.last.id;
      s.addPage(parentId: null);
      final keepId = s.selectedPage!.id;
      s.addPage(parentId: null);
      final childId = s.selectedPage!.id;
      s.movePage(pageId: childId, newParentId: folderId, newIndex: 0);

      s.movePageToTrash(folderId);
      s.restoreFromTrash(folderId);

      expect(s.trashedPages, isEmpty);
      expect(s.activePages.map((p) => p.id).toSet(), {folderId, keepId, childId});
      expect(s.pages.firstWhere((p) => p.id == childId).parentId, folderId);
    });

    test('blocks trashing when it would leave zero active pages', () {
      final s = VaultSession();
      s.addPage(parentId: null);
      final onlyId = s.selectedPage!.id;
      expect(s.canMovePageToTrash(onlyId), isFalse);
      s.movePageToTrash(onlyId);
      expect(s.activePages.map((p) => p.id), [onlyId]);
      expect(s.trashedPages, isEmpty);
    });

    test('permanentlyDeleteFromTrash hard-deletes subtree', () {
      final s = VaultSession();
      s.addFolder(parentId: null);
      final folderId = s.pages.last.id;
      s.addPage(parentId: null);
      final keepId = s.selectedPage!.id;
      s.addPage(parentId: null);
      final childId = s.selectedPage!.id;
      s.movePage(pageId: childId, newParentId: folderId, newIndex: 0);

      s.movePageToTrash(folderId);
      s.permanentlyDeleteFromTrash(folderId);

      expect(s.pages.map((p) => p.id), [keepId]);
      expect(s.trashedPages, isEmpty);
    });

    test('purgeExpiredTrash removes pages older than retention', () {
      final s = VaultSession();
      s.addPage(parentId: null);
      final keepId = s.selectedPage!.id;
      s.addPage(parentId: null);
      final oldId = s.selectedPage!.id;
      s.addPage(parentId: null);
      final freshId = s.selectedPage!.id;

      s.movePageToTrash(oldId);
      s.movePageToTrash(freshId);
      final oldPage = s.pages.firstWhere((p) => p.id == oldId);
      oldPage.trashedAt = DateTime.now().toUtc().subtract(const Duration(days: 31));

      s.purgeExpiredTrash(retention: const Duration(days: 30));

      expect(s.pages.any((p) => p.id == oldId), isFalse);
      expect(s.pages.any((p) => p.id == freshId), isTrue);
      expect(s.pages.any((p) => p.id == keepId), isTrue);
      expect(s.trashedPages.map((p) => p.id), [freshId]);
    });

    test('emptyTrash permanently deletes all trashed pages', () {
      final s = VaultSession();
      s.addPage(parentId: null);
      final keepId = s.selectedPage!.id;
      s.addPage(parentId: null);
      final a = s.selectedPage!.id;
      s.addPage(parentId: null);
      final b = s.selectedPage!.id;

      s.movePageToTrash(a);
      s.movePageToTrash(b);
      s.emptyTrash();

      expect(s.pages.map((p) => p.id), [keepId]);
      expect(s.trashedPages, isEmpty);
    });
  });
}
