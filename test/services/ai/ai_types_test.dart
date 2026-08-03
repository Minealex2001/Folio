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
}
