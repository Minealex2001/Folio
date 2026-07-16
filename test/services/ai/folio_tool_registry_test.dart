import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
import 'package:folio/session/vault_session.dart';

AiToolCall _call(String name, Map<String, dynamic> args) =>
    AiToolCall(id: 'call_1', name: name, arguments: args);

void main() {
  group('FolioToolRegistry — Fase 1 (contenido)', () {
    test('create_page crea una página con título y bloques', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('create_page', {
          'title': 'Mi página',
          'blocks': [
            {'type': 'h1', 'text': 'Título'},
            {'type': 'paragraph', 'text': 'Cuerpo'},
          ],
        }),
      );

      expect(result.isError, isFalse);
      expect(session.pages.length, 1);
      final page = session.pages.single;
      expect(page.title, 'Mi página');
      expect(page.blocks.map((b) => b.type), ['h1', 'paragraph']);
    });

    test('append_blocks_to_page añade bloques al final', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session, scopePageId: pageId);

      final result = await registry.execute(
        _call('append_blocks_to_page', {
          'pageId': 'current',
          'blocks': [
            {'type': 'paragraph', 'text': 'Nuevo'},
          ],
        }),
      );

      expect(result.isError, isFalse);
      final page = session.pages.firstWhere((p) => p.id == pageId);
      expect(page.blocks.last.text, 'Nuevo');
    });

    test('replace_page_blocks reemplaza todo el contenido', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('replace_page_blocks', {
          'pageId': pageId,
          'blocks': [
            {'type': 'paragraph', 'text': 'Resumen'},
          ],
        }),
      );

      expect(result.isError, isFalse);
      final page = session.pages.firstWhere((p) => p.id == pageId);
      expect(page.blocks.length, 1);
      expect(page.blocks.single.text, 'Resumen');
    });

    test('edit_page_blocks aplica update_block_text y delete_block', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final blockId = session.pages.first.blocks.first.id;
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('edit_page_blocks', {
          'pageId': pageId,
          'operations': [
            {'kind': 'update_block_text', 'blockId': blockId, 'text': 'Editado'},
          ],
        }),
      );

      expect(result.isError, isFalse);
      final page = session.pages.firstWhere((p) => p.id == pageId);
      expect(page.blocks.single.text, 'Editado');

      final deleteResult = await registry.execute(
        _call('edit_page_blocks', {
          'pageId': pageId,
          'operations': [
            {'kind': 'delete_block', 'blockId': blockId},
          ],
        }),
      );
      expect(deleteResult.isError, isFalse);
      expect(session.pages.firstWhere((p) => p.id == pageId).blocks, isEmpty);
    });

    test('insert_todos e insert_tasks delegan en QuillToolExecutor', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      await registry.execute(
        _call('insert_todos', {
          'pageId': pageId,
          'lines': ['Primero', 'Segundo'],
        }),
      );
      final page = session.pages.firstWhere((p) => p.id == pageId);
      expect(page.blocks.where((b) => b.type == 'todo').length, 2);

      await registry.execute(
        _call('insert_tasks', {
          'pageId': pageId,
          'tasks': ['Tarea A'],
        }),
      );
      expect(
        session.pages.firstWhere((p) => p.id == pageId).blocks.where((b) => b.type == 'task').length,
        1,
      );
    });

    test('translate_page_bilingual inserta traducciones tras el bloque original', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final blockId = session.pages.first.blocks.first.id;
      session.updateBlockText(pageId, blockId, 'Hello');
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('translate_page_bilingual', {
          'pageId': pageId,
          'translations': [
            {'blockId': blockId, 'text': 'Hola'},
          ],
        }),
      );

      expect(result.isError, isFalse);
      final page = session.pages.firstWhere((p) => p.id == pageId);
      expect(page.blocks.length, 2);
      expect(page.blocks[1].text, 'Hola');
    });
  });

  group('FolioToolRegistry — Fase 2 (gestión de libretas/páginas)', () {
    test('create_folder crea una carpeta y list_children la encuentra', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);

      final createResult = await registry.execute(_call('create_folder', {}));
      expect(createResult.isError, isFalse);
      expect(session.pages.single.isFolder, isTrue);

      final listResult = await registry.execute(_call('list_children', {}));
      expect(listResult.isError, isFalse);
      expect(listResult.content, contains(session.pages.single.id));
    });

    test('rename_page y set_page_emoji mutan metadatos', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      await registry.execute(_call('rename_page', {'pageId': pageId, 'title': 'Renombrada'}));
      expect(session.pages.firstWhere((p) => p.id == pageId).title, 'Renombrada');

      await registry.execute(_call('set_page_emoji', {'pageId': pageId, 'emoji': '🚀'}));
      expect(session.pages.firstWhere((p) => p.id == pageId).emoji, '🚀');
    });

    test('add_page_tag y remove_page_tag', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      await registry.execute(_call('add_page_tag', {'pageId': pageId, 'tag': 'trabajo'}));
      expect(session.pages.firstWhere((p) => p.id == pageId).tags, contains('trabajo'));

      await registry.execute(_call('remove_page_tag', {'pageId': pageId, 'tag': 'trabajo'}));
      expect(session.pages.firstWhere((p) => p.id == pageId).tags, isNot(contains('trabajo')));
    });

    test('move_page rechaza mover una página dentro de su propio descendiente', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final parentId = session.selectedPage!.id;
      session.addFolder(parentId: parentId);
      final childId = session.pages.firstWhere((p) => p.id != parentId).id;
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('move_page', {'pageId': parentId, 'newParentId': childId, 'newIndex': 0}),
      );

      expect(result.isError, isTrue);
      expect(session.pages.firstWhere((p) => p.id == parentId).parentId, isNull);
    });

    test('move_page mueve a un nuevo padre válido', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final folderId = session.addFolder(parentId: null);
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('move_page', {'pageId': pageId, 'newParentId': folderId, 'newIndex': 0}),
      );

      expect(result.isError, isFalse);
      expect(session.pages.firstWhere((p) => p.id == pageId).parentId, folderId);
    });

    test('duplicate_page copia título y bloques', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      session.renamePage(pageId, 'Original');
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(_call('duplicate_page', {'pageId': pageId}));

      expect(result.isError, isFalse);
      expect(session.pages.length, 2);
      final copy = session.pages.firstWhere((p) => p.id != pageId);
      expect(copy.blocks.length, session.pages.firstWhere((p) => p.id == pageId).blocks.length);
    });

    test('trash_page seguido de restore_page', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final first = session.selectedPage!.id;
      session.addPage(parentId: null);
      final second = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      final trashResult = await registry.execute(_call('trash_page', {'pageId': second}));
      expect(trashResult.isError, isFalse);
      expect(session.pages.firstWhere((p) => p.id == second).isTrashed, isTrue);

      final restoreResult = await registry.execute(_call('restore_page', {'pageId': second}));
      expect(restoreResult.isError, isFalse);
      expect(session.pages.firstWhere((p) => p.id == second).isTrashed, isFalse);
      expect(first, isNotNull);
    });

    test('trash_page rechaza dejar el vault vacío', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(_call('trash_page', {'pageId': pageId}));

      expect(result.isError, isTrue);
      expect(session.pages.firstWhere((p) => p.id == pageId).isTrashed, isFalse);
    });

    test('delete_folder_flatten_children mueve hijos a la raíz', () async {
      final session = VaultSession();
      final folderId = session.addFolder(parentId: null);
      session.addPage(parentId: folderId);
      final childId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('delete_folder_flatten_children', {'folderId': folderId}),
      );

      expect(result.isError, isFalse);
      expect(session.pages.any((p) => p.id == folderId), isFalse);
      expect(session.pages.firstWhere((p) => p.id == childId).parentId, isNull);
    });

    test('search_pages encuentra por contenido', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final blockId = session.pages.first.blocks.first.id;
      session.updateBlockText(pageId, blockId, 'palabra clave única');
      session.searchIndex.rebuildFromPages(session.pages);
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(_call('search_pages', {'query': 'única'}));

      expect(result.isError, isFalse);
      expect(result.content, contains(pageId));
    });

    test('insert_blocks_at_position inserta al inicio', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('insert_blocks_at_position', {
          'pageId': pageId,
          'position': 'start',
          'blocks': [
            {'type': 'h1', 'text': 'Encabezado'},
          ],
        }),
      );

      expect(result.isError, isFalse);
      expect(session.pages.firstWhere((p) => p.id == pageId).blocks.first.type, 'h1');
    });
  });
}
