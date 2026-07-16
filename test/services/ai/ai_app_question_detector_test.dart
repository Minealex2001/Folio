import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_app_question_detector.dart';

void main() {
  group('AiAppQuestionDetector — casos positivos', () {
    test('detecta pregunta en español sobre la app', () {
      expect(
        AiAppQuestionDetector.looksLikeAppQuestion(
          '¿Cómo hago para mover una página a otra carpeta?',
          languageCode: 'es',
        ),
        isTrue,
      );
    });

    test('detecta pregunta en inglés sobre la app', () {
      expect(
        AiAppQuestionDetector.looksLikeAppQuestion(
          'How do I move a page into a folder?',
          languageCode: 'en',
        ),
        isTrue,
      );
    });

    test('detecta pregunta con signo de interrogación aunque no haya marcador explícito', () {
      expect(
        AiAppQuestionDetector.looksLikeAppQuestion('Se puede cifrar la libreta?', languageCode: 'es'),
        isTrue,
      );
    });

    test('detecta pregunta sobre atajos de teclado', () {
      expect(
        AiAppQuestionDetector.looksLikeAppQuestion(
          'What is the shortcut to duplicate a block?',
          languageCode: 'en',
        ),
        isTrue,
      );
    });
  });

  group('AiAppQuestionDetector — casos negativos', () {
    test('no marca una petición de contenido normal', () {
      expect(
        AiAppQuestionDetector.looksLikeAppQuestion(
          'Escribe un resumen sobre historia de Roma',
          languageCode: 'es',
        ),
        isFalse,
      );
    });

    test('no marca un mensaje sin sustantivo de dominio de Folio aunque tenga "?"', () {
      expect(
        AiAppQuestionDetector.looksLikeAppQuestion('Qué día es hoy?', languageCode: 'es'),
        isFalse,
      );
    });

    test('no marca un mensaje vacío', () {
      expect(AiAppQuestionDetector.looksLikeAppQuestion('', languageCode: 'es'), isFalse);
    });
  });
}
