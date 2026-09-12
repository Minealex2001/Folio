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

    test('create_page rechaza blocks vacíos', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('create_page', {
          'title': 'Vacía',
          'blocks': <Map<String, dynamic>>[],
        }),
      );

      expect(result.isError, isTrue);
      expect(session.pages, isEmpty);
      expect(result.content, contains('blocks'));
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

      final createResult = await registry.execute(
        _call('create_folder', {'title': 'Apuntes'}),
      );
      expect(createResult.isError, isFalse);
      expect(session.pages.single.isFolder, isTrue);
      expect(session.pages.single.title, 'Apuntes');

      final listResult = await registry.execute(_call('list_children', {}));
      expect(listResult.isError, isFalse);
      expect(listResult.content, contains(session.pages.single.id));
    });

    test('create_folder sin title falla', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);

      final createResult = await registry.execute(_call('create_folder', {}));
      expect(createResult.isError, isTrue);
      expect(session.pages, isEmpty);
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

  group('FolioToolRegistry — confirmación irreversible (modo Plan)', () {
    Future<({VaultSession session, String trashPageId})> _trashedVault() async {
      final session = VaultSession();
      session.addPage(parentId: null);
      session.addPage(parentId: null);
      final keepId = session.pages.first.id;
      final trashId = session.pages.last.id;
      expect(keepId, isNot(trashId));
      session.movePageToTrash(trashId);
      return (session: session, trashPageId: trashId);
    }

    test('sin onConfirmIrreversibleTool borra de inmediato (regresión)', () async {
      final setup = await _trashedVault();
      final registry = FolioToolRegistry(setup.session);

      final result = await registry.execute(
        _call('permanently_delete_page', {'pageId': setup.trashPageId}),
      );

      expect(result.isError, isFalse);
      expect(
        setup.session.pages.any((p) => p.id == setup.trashPageId),
        isFalse,
      );
    });

    test('onConfirmIrreversibleTool false aborta permanently_delete_page', () async {
      final setup = await _trashedVault();
      var asked = false;
      final registry = FolioToolRegistry(
        setup.session,
        onConfirmIrreversibleTool: (name, args) async {
          asked = true;
          expect(name, 'permanently_delete_page');
          return false;
        },
      );

      final result = await registry.execute(
        _call('permanently_delete_page', {'pageId': setup.trashPageId}),
      );

      expect(asked, isTrue);
      expect(result.isError, isTrue);
      expect(result.content, contains('cancelada'));
      expect(
        setup.session.pages.any((p) => p.id == setup.trashPageId),
        isTrue,
      );
    });

    test('onConfirmIrreversibleTool true procede con permanently_delete_page', () async {
      final setup = await _trashedVault();
      final registry = FolioToolRegistry(
        setup.session,
        onConfirmIrreversibleTool: (_, __) async => true,
      );

      final result = await registry.execute(
        _call('permanently_delete_page', {'pageId': setup.trashPageId}),
      );

      expect(result.isError, isFalse);
      expect(
        setup.session.pages.any((p) => p.id == setup.trashPageId),
        isFalse,
      );
    });

    test('onConfirmIrreversibleTool false aborta empty_trash', () async {
      final setup = await _trashedVault();
      final registry = FolioToolRegistry(
        setup.session,
        onConfirmIrreversibleTool: (name, _) async {
          expect(name, 'empty_trash');
          return false;
        },
      );

      final result = await registry.execute(_call('empty_trash', {}));

      expect(result.isError, isTrue);
      expect(
        setup.session.pages.any((p) => p.id == setup.trashPageId && p.isTrashed),
        isTrue,
      );
    });

    test('onConfirmIrreversibleTool true procede con empty_trash', () async {
      final setup = await _trashedVault();
      final registry = FolioToolRegistry(
        setup.session,
        onConfirmIrreversibleTool: (_, __) async => true,
      );

      final result = await registry.execute(_call('empty_trash', {}));

      expect(result.isError, isFalse);
      expect(
        setup.session.pages.any((p) => p.isTrashed),
        isFalse,
      );
    });
  });

  group('FolioToolRegistry — get_page_content y allowlist MCP', () {
    test('sin gate lee cualquier página e incluye block id', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final page = session.selectedPage!;
      session.renamePage(page.id, 'Nota secreta');
      session.updateBlockText(page.id, page.blocks.first.id, 'contenido privado');
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('get_page_content', {'pageId': page.id}),
      );

      expect(result.isError, isFalse);
      expect(result.content, contains('"title":"Nota secreta"'));
      expect(result.content, contains('"id":"${page.blocks.first.id}"'));
      expect(result.content, contains('contenido privado'));
      expect(result.content, isNot(contains('richTextDeltaJson')));
    });

    test('con gate denegado no filtra contenido ni añade a allowlist', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      session.updateBlockText(pageId, session.pages.first.blocks.first.id, 'no filtrar');
      final registry = FolioToolRegistry(
        session,
        onRequestMcpReadAccess: (_, __) async => McpReadAccessDecision.deny,
      );

      final result = await registry.execute(
        _call('get_page_content', {'pageId': pageId}),
      );

      expect(result.isError, isTrue);
      expect(result.content, isNot(contains('no filtrar')));
      expect(session.mcpReadablePageIds.contains(pageId), isFalse);
    });

    test('con gate allowAndRemember añade a allowlist y devuelve bloques', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      session.updateBlockText(pageId, session.pages.first.blocks.first.id, 'ok');
      final registry = FolioToolRegistry(
        session,
        onRequestMcpReadAccess: (_, __) async =>
            McpReadAccessDecision.allowAndRemember,
      );

      final result = await registry.execute(
        _call('get_page_content', {'pageId': pageId}),
      );

      expect(result.isError, isFalse);
      expect(session.mcpReadablePageIds.contains(pageId), isTrue);
      expect(result.content, contains('"text":"ok"'));
    });

    test('con gate allowOnce lee sin añadir a allowlist', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      session.updateBlockText(pageId, session.pages.first.blocks.first.id, 'una vez');
      final registry = FolioToolRegistry(
        session,
        onRequestMcpReadAccess: (_, __) async => McpReadAccessDecision.allowOnce,
      );

      final result = await registry.execute(
        _call('get_page_content', {'pageId': pageId}),
      );

      expect(result.isError, isFalse);
      expect(result.content, contains('una vez'));
      expect(session.mcpReadablePageIds.contains(pageId), isFalse);
    });

    test('herencia: carpeta allowlisteada hace legible al hijo', () async {
      final session = VaultSession();
      final folderId = session.addFolder(parentId: null);
      session.addPage(parentId: folderId);
      final childId = session.selectedPage!.id;
      session.grantMcpPageReadable(folderId);
      final registry = FolioToolRegistry(
        session,
        onRequestMcpReadAccess: (_, __) async => McpReadAccessDecision.deny,
      );

      final result = await registry.execute(
        _call('get_page_content', {'pageId': childId}),
      );

      expect(result.isError, isFalse);
      expect(session.isMcpPageReadable(childId), isTrue);
    });

    test('create_page auto-grant en allowlist', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(
        session,
        onRequestMcpReadAccess: (_, __) async => McpReadAccessDecision.deny,
      );

      final create = await registry.execute(
        _call('create_page', {
          'title': 'Creada por agente',
          'blocks': [
            {'type': 'paragraph', 'text': 'hola'},
          ],
        }),
      );
      expect(create.isError, isFalse);
      final pageId = RegExp(r'"pageId":"([^"]+)"').firstMatch(create.content)!.group(1)!;
      expect(session.mcpReadablePageIds.contains(pageId), isTrue);

      final read = await registry.execute(
        _call('get_page_content', {'pageId': pageId}),
      );
      expect(read.isError, isFalse);
      expect(read.content, contains('hola'));
    });

    test('search_pages vía MCP omite snippet si no es legible', () async {
      final session = VaultSession();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      final blockId = session.pages.first.blocks.first.id;
      session.updateBlockText(pageId, blockId, 'palabra clave única mcp');
      session.searchIndex.rebuildFromPages(session.pages);
      final registry = FolioToolRegistry(
        session,
        onRequestMcpReadAccess: (_, __) async => McpReadAccessDecision.deny,
      );

      final result = await registry.execute(
        _call('search_pages', {'query': 'única'}),
      );

      expect(result.isError, isFalse);
      expect(result.content, contains(pageId));
      expect(result.content, contains('"contentReadable":false'));
      expect(result.content, contains('"snippet":""'));
      expect(result.content, isNot(contains('palabra clave única mcp')));
    });
  });

  group('generate_image', () {
    test('está presente en las definiciones', () {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);
      expect(
        registry.definitions.map((d) => d.name),
        contains('generate_image'),
      );
    });

    test('devuelve error cuando onGenerateImage es null', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);

      final result = await registry.execute(
        _call('generate_image', {'prompt': 'un faro al atardecer'}),
      );

      expect(result.isError, isTrue);
    });

    test('devuelve error si falta el prompt', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(
        session,
        onGenerateImage: (prompt, useContext) async => '{"status":"generated"}',
      );

      final result = await registry.execute(_call('generate_image', {}));

      expect(result.isError, isTrue);
    });

    test('invoca onGenerateImage con el prompt y el flag de contexto', () async {
      String? capturedPrompt;
      bool? capturedUseContext;
      final session = VaultSession();
      final registry = FolioToolRegistry(
        session,
        onGenerateImage: (prompt, useContext) async {
          capturedPrompt = prompt;
          capturedUseContext = useContext;
          return '{"status":"generated","path":"attachments/x.png"}';
        },
      );

      final result = await registry.execute(
        _call('generate_image', {
          'prompt': 'un faro al atardecer',
          'useCurrentPageContext': true,
        }),
      );

      expect(result.isError, isFalse);
      expect(capturedPrompt, 'un faro al atardecer');
      expect(capturedUseContext, isTrue);
      expect(result.content, contains('attachments/x.png'));
    });

    test('convierte una excepción del callback en un resultado de error', () async {
      final session = VaultSession();
      final registry = FolioToolRegistry(
        session,
        onGenerateImage: (prompt, useContext) async {
          throw StateError('proveedor no disponible');
        },
      );

      final result = await registry.execute(
        _call('generate_image', {'prompt': 'algo'}),
      );

      expect(result.isError, isTrue);
    });
  });

  group('FolioToolRegistry — Fase B1 (metadata + preview)', () {
    test('cada tool tiene category y complexity no nulos', () {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);
      for (final def in registry.definitions) {
        expect(def.category, isNotNull, reason: def.name);
        expect(def.complexity, isNotNull, reason: def.name);
      }
    });

    test(
      'exactamente las tools destructivas conocidas tienen requiresConfirmation '
      'y supportsPreview',
      () {
        final session = VaultSession();
        final registry = FolioToolRegistry(session);
        const expectedConfirmable = {'permanently_delete_page', 'empty_trash'};
        const expectedPreviewable = {
          'trash_page',
          'permanently_delete_page',
          'empty_trash',
          'delete_folder_flatten_children',
        };
        for (final def in registry.definitions) {
          expect(
            def.requiresConfirmation,
            expectedConfirmable.contains(def.name),
            reason: def.name,
          );
          expect(
            def.supportsPreview,
            expectedPreviewable.contains(def.name),
            reason: def.name,
          );
        }
      },
    );

    test('toJsonSchema() no incluye ningún campo de metadata nuevo', () {
      final schema = registryDefinitionForTest('permanently_delete_page').toJsonSchema();
      final schemaKeys = schema.toString();
      expect(schemaKeys, isNot(contains('category')));
      expect(schemaKeys, isNot(contains('isReversible')));
      expect(schemaKeys, isNot(contains('requiresConfirmation')));
      expect(schemaKeys, isNot(contains('supportsPreview')));
    });

    test('preview(trash_page) resume la página y su subárbol sin mutar el vault', () {
      final session = VaultSession();
      session.addPage(parentId: null);
      final parentId = session.pages.last.id;
      session.addPage(parentId: parentId);
      final registry = FolioToolRegistry(session);

      final preview = registry.preview(_call('trash_page', {'pageId': parentId}));

      expect(preview, isNotNull);
      expect(preview!.summary, contains('1 página'));
      expect(session.pages.every((p) => !p.isTrashed), isTrue);
    });

    test('preview(permanently_delete_page) describe la página a borrar', () {
      final session = VaultSession();
      session.addPage(parentId: null);
      session.addPage(parentId: null);
      final pageId = session.pages.last.id;
      session.movePageToTrash(pageId);
      final registry = FolioToolRegistry(session);

      final preview = registry.preview(
        _call('permanently_delete_page', {'pageId': pageId}),
      );

      expect(preview, isNotNull);
      expect(preview!.summary, contains('permanentemente'));
      expect(session.pages.any((p) => p.id == pageId), isTrue);
    });

    test('preview(empty_trash) cuenta las páginas en papelera sin vaciarla', () {
      final session = VaultSession();
      session.addPage(parentId: null);
      session.addPage(parentId: null);
      final pageId = session.pages.last.id;
      session.movePageToTrash(pageId);
      final registry = FolioToolRegistry(session);

      final preview = registry.preview(_call('empty_trash', {}));

      expect(preview, isNotNull);
      expect(preview!.affectedItems.length, 1);
      expect(session.pages.any((p) => p.id == pageId), isTrue);
    });

    test('preview() de una tool sin supportsPreview devuelve null', () {
      final session = VaultSession();
      final registry = FolioToolRegistry(session);
      final preview = registry.preview(_call('rename_page', {'pageId': 'x', 'title': 'y'}));
      expect(preview, isNull);
    });
  });
}

AiToolDefinition registryDefinitionForTest(String name) {
  final registry = FolioToolRegistry(VaultSession());
  return registry.definitionByName(name)!;
}
