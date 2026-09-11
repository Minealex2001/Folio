import 'package:flutter_test/flutter_test.dart';

import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/session/vault_session.dart';

/// Fase A1 del plan Quill/MCP — `autoIncludeSelection` es un toggle
/// explícito y persistente por hilo de chat (no inferencia silenciosa): si
/// está activo, la selección del editor se adjunta en cada envío sin que el
/// usuario tenga que elegir "@" → "Selección del editor" cada vez.
void main() {
  group('AiChatThreadData.autoIncludeSelection', () {
    test('default es false y no aparece en el JSON serializado', () {
      const thread = AiChatThreadData(id: 'c', title: 't', messages: []);
      expect(thread.autoIncludeSelection, isFalse);
      expect(thread.toJson().containsKey('autoIncludeSelection'), isFalse);
    });

    test('round-trip de serialización preserva el valor cuando es true', () {
      const thread = AiChatThreadData(
        id: 'c',
        title: 't',
        messages: [],
        autoIncludeSelection: true,
      );
      final json = thread.toJson();
      expect(json['autoIncludeSelection'], isTrue);
      final restored = AiChatThreadData.fromJson(json);
      expect(restored.autoIncludeSelection, isTrue);
    });

    test('fromJson sin el campo (hilos antiguos ya guardados) cae a false', () {
      final restored = AiChatThreadData.fromJson({
        'id': 'c',
        'title': 't',
        'messages': [],
      });
      expect(restored.autoIncludeSelection, isFalse);
    });
  });

  group('VaultSession.setActiveAiChatAutoIncludeSelection', () {
    test('activa el toggle en el hilo activo', () {
      final session = VaultSession();
      session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
      expect(session.aiChatThreads.single.autoIncludeSelection, isFalse);

      session.setActiveAiChatAutoIncludeSelection(true);

      expect(session.aiChatThreads.single.autoIncludeSelection, isTrue);
    });

    test('desactivarlo lo vuelve a false', () {
      final session = VaultSession();
      session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
      session.setActiveAiChatAutoIncludeSelection(true);

      session.setActiveAiChatAutoIncludeSelection(false);

      expect(session.aiChatThreads.single.autoIncludeSelection, isFalse);
    });

    test('no muta ni notifica cuando el valor ya es el mismo', () {
      final session = VaultSession();
      session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
      var notifications = 0;
      session.addListener(() => notifications++);

      session.setActiveAiChatAutoIncludeSelection(false);

      expect(notifications, 0);
      expect(session.aiChatThreads.single.autoIncludeSelection, isFalse);
    });

    test('preserva el resto de campos del hilo (title, includePageContext, contextPageIds)', () {
      final session = VaultSession();
      session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
      session.setActiveAiChatIncludePageContext(false);
      session.setActiveAiChatContextPageIds(['page_1']);

      session.setActiveAiChatAutoIncludeSelection(true);

      final thread = session.aiChatThreads.single;
      expect(thread.includePageContext, isFalse);
      expect(thread.contextPageIds, ['page_1']);
      expect(thread.autoIncludeSelection, isTrue);
    });
  });
}
