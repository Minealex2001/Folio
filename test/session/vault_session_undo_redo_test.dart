import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('VaultSession undo/redo por pagina', () {
    test('undo/redo restaura cambios de texto del bloque', () {
      final session = VaultSession();
      session.addPage();

      final page = session.selectedPage!;
      final pageId = page.id;
      final blockId = page.blocks.first.id;

      session.updateBlockText(pageId, blockId, 'Hola mundo');
      expect(session.selectedPage!.blocks.first.text, 'Hola mundo');

      session.undoPageEdits(pageId: pageId);
      expect(session.selectedPage!.blocks.first.text, isEmpty);

      session.redoPageEdits(pageId: pageId);
      expect(session.selectedPage!.blocks.first.text, 'Hola mundo');
    });

    test('coalesce de tipeo permite deshacer varias teclas en un paso', () {
      final session = VaultSession();
      session.addPage();

      final page = session.selectedPage!;
      final pageId = page.id;
      final blockId = page.blocks.first.id;

      session.updateBlockText(pageId, blockId, 'H');
      session.updateBlockText(pageId, blockId, 'Ho');
      session.updateBlockText(pageId, blockId, 'Hol');
      session.updateBlockText(pageId, blockId, 'Hola');
      expect(session.selectedPage!.blocks.first.text, 'Hola');

      session.undoPageEdits(pageId: pageId);
      expect(session.selectedPage!.blocks.first.text, isEmpty);
    });

    test('undo/redo funciona para operaciones estructurales', () {
      final session = VaultSession();
      session.addPage();

      final page = session.selectedPage!;
      final pageId = page.id;
      final firstId = page.blocks.first.id;

      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: firstId,
        block: FolioBlock(
          id: '${pageId}_b1',
          type: 'paragraph',
          text: 'Segundo',
        ),
      );
      final secondId = session.selectedPage!.blocks.last.id;
      expect(session.selectedPage!.blocks.length, 2);

      session.reorderBlockAt(pageId, 1, 0);
      expect(session.selectedPage!.blocks.first.id, secondId);

      session.undoPageEdits(pageId: pageId);
      expect(session.selectedPage!.blocks.first.id, firstId);

      session.redoPageEdits(pageId: pageId);
      expect(session.selectedPage!.blocks.first.id, secondId);
    });

    test('undo/redo restaura la apariencia del bloque', () {
      final session = VaultSession();
      session.addPage();

      final page = session.selectedPage!;
      final pageId = page.id;
      final blockId = page.blocks.first.id;

      session.setBlockAppearance(
        pageId,
        blockId,
        const FolioBlockAppearance(
          textColorRole: 'primary',
          backgroundRole: 'surface',
          fontScale: 1.15,
        ),
      );

      final styled = session.selectedPage!.blocks.first.appearance;
      expect(styled, isNotNull);
      expect(styled!.textColorRole, 'primary');
      expect(styled.backgroundRole, 'surface');
      expect(styled.fontScale, 1.15);

      session.undoPageEdits(pageId: pageId);
      expect(session.selectedPage!.blocks.first.appearance, isNull);

      session.redoPageEdits(pageId: pageId);
      final restored = session.selectedPage!.blocks.first.appearance;
      expect(restored, isNotNull);
      expect(restored!.textColorRole, 'primary');
      expect(restored.backgroundRole, 'surface');
      expect(restored.fontScale, 1.15);
    });

    test('borrado multiple se deshace en un solo paso', () {
      final session = VaultSession();
      session.addPage();

      final page = session.selectedPage!;
      final pageId = page.id;
      final firstId = page.blocks.first.id;

      session.insertBlocksAfterMany(
        pageId: pageId,
        afterBlockId: firstId,
        blocks: [
          FolioBlock(id: '${pageId}_b1', type: 'paragraph', text: 'Uno'),
          FolioBlock(id: '${pageId}_b2', type: 'paragraph', text: 'Dos'),
          FolioBlock(id: '${pageId}_b3', type: 'paragraph', text: 'Tres'),
        ],
      );
      expect(session.selectedPage!.blocks.length, 4);

      session.removeBlocksIfMultiple(pageId, [
        '${pageId}_b1',
        '${pageId}_b2',
      ]);
      expect(
        session.selectedPage!.blocks.map((b) => b.id).toList(),
        [firstId, '${pageId}_b3'],
      );

      session.undoPageEdits(pageId: pageId);
      expect(
        session.selectedPage!.blocks.map((b) => b.id).toList(),
        [firstId, '${pageId}_b1', '${pageId}_b2', '${pageId}_b3'],
      );

      session.redoPageEdits(pageId: pageId);
      expect(
        session.selectedPage!.blocks.map((b) => b.id).toList(),
        [firstId, '${pageId}_b3'],
      );
    });

    test('borrado multiple nunca elimina el ultimo bloque', () {
      final session = VaultSession();
      session.addPage();

      final page = session.selectedPage!;
      final pageId = page.id;
      final firstId = page.blocks.first.id;

      session.removeBlocksIfMultiple(pageId, [firstId]);
      expect(session.selectedPage!.blocks.length, 1);
      expect(session.selectedPage!.blocks.first.id, firstId);
    });
  });
}
