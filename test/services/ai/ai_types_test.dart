import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_types.dart';

void main() {
  group('AiChatMessage JSON round-trip', () {
    test('preserva generatedImagePath y generatedImagePrompt', () {
      final message = AiChatMessage.now(
        role: 'assistant',
        content: '',
        generatedImagePath: 'attachments/abc.png',
        generatedImagePrompt: 'un faro al atardecer',
      );

      final json = message.toJson();
      expect(json['generatedImagePath'], 'attachments/abc.png');
      expect(json['generatedImagePrompt'], 'un faro al atardecer');

      final decoded = AiChatMessage.fromJson(json);
      expect(decoded.generatedImagePath, 'attachments/abc.png');
      expect(decoded.generatedImagePrompt, 'un faro al atardecer');
    });

    test('omite los campos de imagen cuando son nulos', () {
      final message = AiChatMessage.now(role: 'assistant', content: 'hola');

      final json = message.toJson();
      expect(json.containsKey('generatedImagePath'), isFalse);
      expect(json.containsKey('generatedImagePrompt'), isFalse);

      final decoded = AiChatMessage.fromJson(json);
      expect(decoded.generatedImagePath, isNull);
      expect(decoded.generatedImagePrompt, isNull);
    });

    test('copyWith puede limpiar los campos de imagen', () {
      final message = AiChatMessage.now(
        role: 'assistant',
        content: '',
        generatedImagePath: 'attachments/abc.png',
        generatedImagePrompt: 'prompt',
      );

      final cleared = message.copyWith(
        clearGeneratedImagePath: true,
        clearGeneratedImagePrompt: true,
      );

      expect(cleared.generatedImagePath, isNull);
      expect(cleared.generatedImagePrompt, isNull);
    });
  });

  group('AiChatThreadData.copyWith (Fase 4 de Quill 2.0)', () {
    AiChatThreadData sampleThread() => AiChatThreadData(
      id: 'chat_1',
      title: 'Título',
      messages: [AiChatMessage.now(role: 'user', content: 'hola')],
      attachmentPaths: const ['/tmp/a.png'],
      includePageContext: false,
      contextPageIds: const ['page-1'],
      autoIncludeSelection: true,
      scopePageId: 'page-1',
      scopeBlockId: 'block-1',
    );

    test('sin argumentos, preserva todos los campos tal cual', () {
      final original = sampleThread();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.messages, original.messages);
      expect(copy.attachmentPaths, original.attachmentPaths);
      expect(copy.includePageContext, original.includePageContext);
      expect(copy.contextPageIds, original.contextPageIds);
      expect(copy.autoIncludeSelection, original.autoIncludeSelection);
      expect(copy.scopePageId, original.scopePageId);
      expect(copy.scopeBlockId, original.scopeBlockId);
    });

    test('cambiar un solo campo (p. ej. messages) no toca scopePageId/scopeBlockId ni autoIncludeSelection', () {
      final original = sampleThread();
      final copy = original.copyWith(
        messages: [AiChatMessage.now(role: 'assistant', content: 'respuesta')],
      );

      expect(copy.messages, hasLength(1));
      expect(copy.scopePageId, 'page-1');
      expect(copy.scopeBlockId, 'block-1');
      expect(copy.autoIncludeSelection, isTrue);
    });

    test('un hilo sin scope (null) sigue sin scope tras copyWith de otro campo', () {
      final original = AiChatThreadData(id: 'chat_0', title: 'General', messages: const []);
      final copy = original.copyWith(title: 'Renombrado');

      expect(copy.scopePageId, isNull);
      expect(copy.scopeBlockId, isNull);
    });
  });

  group('AiChatThreadData JSON round-trip de scopePageId/scopeBlockId (Fase 4)', () {
    test('los campos de scope sobreviven a toJson/fromJson', () {
      final thread = AiChatThreadData(
        id: 'chat_1',
        title: 'Tarea X',
        messages: const [],
        scopePageId: 'page-1',
        scopeBlockId: 'block-1',
      );

      final json = thread.toJson();
      expect(json['scopePageId'], 'page-1');
      expect(json['scopeBlockId'], 'block-1');

      final decoded = AiChatThreadData.fromJson(json);
      expect(decoded.scopePageId, 'page-1');
      expect(decoded.scopeBlockId, 'block-1');
    });

    test('sin scope, no se emiten las claves en el JSON', () {
      final thread = AiChatThreadData(id: 'chat_0', title: 'General', messages: const []);
      final json = thread.toJson();

      expect(json.containsKey('scopePageId'), isFalse);
      expect(json.containsKey('scopeBlockId'), isFalse);
    });

    test('un JSON de una versión anterior (sin scopePageId/scopeBlockId) se deserializa con ambos en null', () {
      final legacyJson = {
        'id': 'chat_legacy',
        'title': 'Chat antiguo',
        'messages': <Map<String, dynamic>>[],
        'includePageContext': true,
        'contextPageIds': <String>[],
      };

      final decoded = AiChatThreadData.fromJson(legacyJson);

      expect(decoded.scopePageId, isNull);
      expect(decoded.scopeBlockId, isNull);
      expect(decoded.id, 'chat_legacy');
      expect(decoded.title, 'Chat antiguo');
    });
  });
}
