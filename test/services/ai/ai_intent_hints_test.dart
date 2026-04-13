import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_intent_hints.dart';

void main() {
  group('AiIntentHints', () {
    test('retorna hints en espanol para edit', () {
      final hints = AiIntentHints.hintsFor(
        intent: AiIntentHints.edit,
        languageCode: 'es',
      );

      expect(hints, isNotEmpty);
      expect(hints, contains('editar'));
    });

    test('retorna hints en ingles para create_page', () {
      final hints = AiIntentHints.hintsFor(
        intent: AiIntentHints.createPage,
        languageCode: 'en',
      );

      expect(hints, isNotEmpty);
      expect(hints, contains('new page'));
    });

    test('normaliza locale con region', () {
      final hints = AiIntentHints.hintsFor(
        intent: AiIntentHints.subpage,
        languageCode: 'es-MX',
      );

      expect(hints, contains('subpagina'));
    });

    test('fallback en idioma desconocido combina en y es', () {
      final hints = AiIntentHints.hintsFor(
        intent: AiIntentHints.edit,
        languageCode: 'fr',
      );

      expect(hints, contains('edit'));
      expect(hints, contains('editar'));
    });

    test('intent desconocido retorna lista vacia', () {
      final hints = AiIntentHints.hintsFor(
        intent: 'unknown_intent',
        languageCode: 'en',
      );

      expect(hints, isEmpty);
    });
  });
}
