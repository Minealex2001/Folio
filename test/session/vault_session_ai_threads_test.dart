import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/session/vault_session.dart';

/// Fase 4 de Quill 2.0 — conversaciones persistentes ligadas a entidades.
///
/// Cubre dos cosas verificadas en la auditoría previa al diseño:
/// 1. Un bug real ya en producción: `AiChatThreadData` no tenía `copyWith`,
///    así que 8 de los 9 sitios que mutan un hilo reconstruían el objeto a
///    mano y se olvidaban de `autoIncludeSelection` — se perdía en cuanto el
///    usuario mandaba un mensaje. El fix (`copyWith` + reemplazar los 9
///    sitios) debe hacer que CUALQUIER campo, incluidos los nuevos
///    `scopePageId`/`scopeBlockId`, sobreviva a esas mutaciones.
/// 2. `openOrCreateAiChatForBlock`: idempotente, aislado por `(pageId,
///    blockId)`, y compatible con hilos antiguos sin scope.
void main() {
  VaultSession readySession() {
    final session = VaultSession();
    session.debugMarkUnlockedForTests();
    return session;
  }

  group('Regresión: autoIncludeSelection ya no se pierde al mutar un hilo', () {
    test('sobrevive a appendMessageToActiveAiChat', () {
      final session = readySession();
      session.setActiveAiChatAutoIncludeSelection(true);
      session.appendMessageToActiveAiChat(AiChatMessage.now(role: 'user', content: 'hola'));
      expect(session.activeAiChat.autoIncludeSelection, isTrue);
    });

    test('sobrevive a renameAiChatAt', () {
      final session = readySession();
      session.setActiveAiChatAutoIncludeSelection(true);
      session.renameAiChatAt(session.aiActiveChatIndex, 'Nuevo título');
      expect(session.activeAiChat.autoIncludeSelection, isTrue);
    });

    test('sobrevive a syncActiveAiChatAttachmentPaths', () {
      final session = readySession();
      session.setActiveAiChatAutoIncludeSelection(true);
      session.syncActiveAiChatAttachmentPaths(['/tmp/foo.png']);
      expect(session.activeAiChat.autoIncludeSelection, isTrue);
    });

    test('sobrevive a setActiveAiChatContextPageIds', () {
      final session = readySession();
      session.setActiveAiChatAutoIncludeSelection(true);
      session.setActiveAiChatContextPageIds(['page-1']);
      expect(session.activeAiChat.autoIncludeSelection, isTrue);
    });

    test('sobrevive a setActiveAiChatIncludePageContext', () {
      final session = readySession();
      session.setActiveAiChatAutoIncludeSelection(true);
      session.setActiveAiChatIncludePageContext(false);
      expect(session.activeAiChat.autoIncludeSelection, isTrue);
    });
  });

  group('openOrCreateAiChatForBlock', () {
    test('crea un hilo nuevo con scope y contextPageIds, y lo activa', () {
      final session = readySession();
      final before = session.aiChatThreads.length;

      final index = session.openOrCreateAiChatForBlock(
        'page-1',
        'block-1',
        titleHint: 'Mi tarea',
      );

      expect(session.aiChatThreads.length, before + 1);
      expect(session.aiActiveChatIndex, index);
      final thread = session.aiChatThreads[index];
      expect(thread.scopePageId, 'page-1');
      expect(thread.scopeBlockId, 'block-1');
      expect(thread.contextPageIds, ['page-1']);
      expect(thread.title, 'Mi tarea');
    });

    test('idempotente: segunda llamada con el mismo (pageId, blockId) reanuda el mismo hilo', () {
      final session = readySession();
      final first = session.openOrCreateAiChatForBlock('page-1', 'block-1');
      final firstId = session.aiChatThreads[first].id;

      // Activa otro hilo general en medio para probar que sí se reanuda.
      session.createNewAiChat();
      expect(session.aiActiveChatIndex, isNot(first));

      final second = session.openOrCreateAiChatForBlock('page-1', 'block-1');

      expect(second, first);
      expect(session.aiActiveChatIndex, first);
      expect(session.aiChatThreads[second].id, firstId);
      expect(
        session.aiChatThreads.where((t) => t.scopePageId == 'page-1' && t.scopeBlockId == 'block-1'),
        hasLength(1),
        reason: 'no debe crearse un segundo hilo para la misma entidad',
      );
    });

    test('idempotente incluso tras enviar mensajes al hilo entre medias', () {
      final session = readySession();
      final first = session.openOrCreateAiChatForBlock('page-1', 'block-1');
      session.appendMessageToActiveAiChat(AiChatMessage.now(role: 'user', content: 'hola'));
      session.appendMessageToActiveAiChat(AiChatMessage.now(role: 'assistant', content: 'hola de vuelta'));

      final second = session.openOrCreateAiChatForBlock('page-1', 'block-1');

      expect(second, first);
      expect(session.aiChatThreads[second].messages, hasLength(2));
    });

    test('aislamiento: mismo blockId, distinto pageId, produce hilos distintos', () {
      final session = readySession();
      final a = session.openOrCreateAiChatForBlock('page-A', 'block-X');
      final b = session.openOrCreateAiChatForBlock('page-B', 'block-X');

      expect(a, isNot(b));
      expect(session.aiChatThreads[a].scopePageId, 'page-A');
      expect(session.aiChatThreads[b].scopePageId, 'page-B');

      // Reabrir el primero sigue devolviendo el primero, no se cruza con el segundo.
      final aAgain = session.openOrCreateAiChatForBlock('page-A', 'block-X');
      expect(aAgain, a);
    });

    test('aislamiento: mismo pageId, distinto blockId, produce hilos distintos', () {
      final session = readySession();
      final a = session.openOrCreateAiChatForBlock('page-1', 'block-A');
      final b = session.openOrCreateAiChatForBlock('page-1', 'block-B');

      expect(a, isNot(b));
    });

    test('el scope persiste intacto tras varias mutaciones del hilo (mensajes, rename, contextPageIds)', () {
      final session = readySession();
      final index = session.openOrCreateAiChatForBlock('page-1', 'block-1');

      session.appendMessageToActiveAiChat(AiChatMessage.now(role: 'user', content: '1'));
      expect(session.aiChatThreads[index].scopePageId, 'page-1');
      expect(session.aiChatThreads[index].scopeBlockId, 'block-1');

      session.renameAiChatAt(index, 'Renombrado');
      expect(session.aiChatThreads[index].scopePageId, 'page-1');
      expect(session.aiChatThreads[index].scopeBlockId, 'block-1');

      session.setActiveAiChatContextPageIds(['page-1', 'page-2']);
      expect(session.aiChatThreads[index].scopePageId, 'page-1');
      expect(session.aiChatThreads[index].scopeBlockId, 'block-1');

      session.appendMessageToActiveAiChat(AiChatMessage.now(role: 'assistant', content: '2'));
      expect(session.aiChatThreads[index].scopePageId, 'page-1');
      expect(session.aiChatThreads[index].scopeBlockId, 'block-1');
    });
  });

  group('Compatibilidad hacia atrás: hilos sin scope', () {
    test('createNewAiChat sigue creando hilos generales sin scope, comportamiento intacto', () {
      final session = readySession();
      final before = session.aiChatThreads.length;

      session.createNewAiChat();

      expect(session.aiChatThreads.length, before + 1);
      final created = session.aiChatThreads[session.aiActiveChatIndex];
      expect(created.scopePageId, isNull);
      expect(created.scopeBlockId, isNull);
      expect(created.messages, isEmpty);
    });

    test('un hilo deserializado sin scopePageId/scopeBlockId (JSON de una versión anterior) funciona con normalidad', () {
      final legacyJson = {
        'id': 'chat_legacy',
        'title': 'Chat antiguo',
        'messages': <Map<String, dynamic>>[],
        'includePageContext': true,
        'contextPageIds': <String>[],
      };

      final thread = AiChatThreadData.fromJson(legacyJson);

      expect(thread.scopePageId, isNull);
      expect(thread.scopeBlockId, isNull);

      // Sigue funcionando: seleccionable, renombrable, recibe mensajes.
      final session = readySession();
      session.aiChatThreads; // sanity: getter accesible
      final withLegacy = thread.copyWith(title: 'Renombrado');
      expect(withLegacy.scopePageId, isNull);
      expect(withLegacy.title, 'Renombrado');
      final withMessage = withLegacy.copyWith(
        messages: [AiChatMessage.now(role: 'user', content: 'hola')],
      );
      expect(withMessage.messages, hasLength(1));
      expect(withMessage.scopePageId, isNull);
    });
  });
}
