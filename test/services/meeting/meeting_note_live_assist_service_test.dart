/// Fase 9 de la evolución de `meeting_note` — Live Assist.
///
/// `MeetingNoteLiveAssistService` no implementa su propio proveedor de IA
/// ni su propio polling: usa el `AiService` activo de la sesión (mismo
/// seam que `meeting_note_preparation_service_test.dart`) y el llamador
/// decide cuándo pedir sugerencias (sin timers internos aquí).
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/meeting_note_live_assist_service.dart';
import 'package:folio/session/vault_session.dart';

class _ScriptedAiService implements AiService {
  _ScriptedAiService(this.text);

  final String text;
  AiCompletionRequest? lastRequest;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    lastRequest = request;
    return AiCompletionResult(text: text);
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final r = await complete(request);
    yield AiCompletionChunk(textDelta: r.text, isFinal: true);
  }

  @override
  Future<void> ping() async {}

  @override
  Future<List<String>> listModels() async => const [];

  @override
  bool get supportsImageGeneration => false;

  @override
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  }) {
    throw AiImageGenerationUnsupportedException(providerName);
  }
}

void main() {
  group('MeetingNoteLiveAssistService.suggest', () {
    test('sin AiService activo devuelve lista vacía', () async {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;

      final result = await MeetingNoteLiveAssistService.instance.suggest(
        session: session,
        pageId: pageId,
        recentTranscript: 'Speaker 1: hola',
      );

      expect(result, isEmpty);
    });

    test('transcript reciente vacío devuelve lista vacía sin llamar a la IA', () async {
      final ai = _ScriptedAiService('no debería usarse');
      final session = VaultSession();
      session.setAiService(ai);
      session.addPage();
      final pageId = session.selectedPageId!;

      final result = await MeetingNoteLiveAssistService.instance.suggest(
        session: session,
        pageId: pageId,
        recentTranscript: '   ',
      );

      expect(result, isEmpty);
      expect(ai.lastRequest, isNull);
    });

    test('parsea hasta 3 líneas no vacías de la respuesta', () async {
      final ai = _ScriptedAiService(
        '¿Cuál es el plazo?\nFalta el propietario de la tarea\n\n'
        'Aclarar el alcance\nUna cuarta que no debería aparecer',
      );
      final session = VaultSession();
      session.setAiService(ai);
      session.addPage();
      final pageId = session.selectedPageId!;
      session.renamePage(pageId, 'Weekly sync');

      final result = await MeetingNoteLiveAssistService.instance.suggest(
        session: session,
        pageId: pageId,
        recentTranscript: 'Speaker 1: no sabemos el plazo final',
      );

      expect(result, hasLength(3));
      expect(result[0], '¿Cuál es el plazo?');
      expect(ai.lastRequest?.prompt, contains('Weekly sync'));
      expect(ai.lastRequest?.prompt, contains('no sabemos el plazo final'));
      expect(ai.lastRequest?.cloudInkOperation, 'meeting_note_live_assist');
    });
  });
}
