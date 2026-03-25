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
  });
}
