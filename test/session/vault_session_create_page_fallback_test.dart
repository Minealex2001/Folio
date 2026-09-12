import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/session/vault_session.dart';

/// Reproduce el bug reportado: el modelo devuelve un JSON con `title` pero
/// sin `blocks` (o vacío), y antes de este arreglo el mensaje de Quill
/// siempre decía "he creado la página con contenido inicial" sin importar si
/// realmente se generó contenido.
class _ScriptedAiService implements AiService {
  _ScriptedAiService(this._results);

  final List<AiCompletionResult> _results;
  int callCount = 0;

  @override
  bool get supportsNativeToolCalling => false;

  @override
  String get providerName => 'folio_cloud';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final r = _results[callCount];
    callCount++;
    return r;
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final result = await complete(request);
    yield AiCompletionChunk(textDelta: result.text, isFinal: true);
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

VaultSession _readySession(AiService ai) {
  final session = VaultSession();
  session.debugMarkUnlockedForTests();
  session.setAiService(ai);
  return session;
}

const _prompt = 'Crea una nota nueva sobre la guerra civil española con diagramas';

void main() {
  test(
    'si el reintento produce contenido, el reply refleja el número de bloques generados',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(text: '{"title":"Guerra Civil Española"}'),
        const AiCompletionResult(
          text:
              '{"title":"Guerra Civil Española","blocks":['
              '{"type":"h1","text":"Guerra Civil Española"},'
              '{"type":"paragraph","text":"Introducción."},'
              '{"type":"paragraph","text":"Más contenido."}'
              ']}',
        ),
      ]);
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(messages: const [], prompt: _prompt);

      expect(ai.callCount, 2, reason: 'debe reintentar una vez cuando blocks viene vacío');
      expect(session.pages, hasLength(1));
      expect(session.pages.single.blocks, hasLength(3));
      expect(outcome.reply, contains('3 bloque'));
      expect(outcome.reply.toLowerCase(), isNot(contains('no conseguí generar contenido')));
    },
  );

  test(
    'si el modelo nunca genera contenido, Quill lo admite en vez de fingir éxito',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(text: '{"title":"Guerra Civil Española"}'),
        const AiCompletionResult(text: '{"title":"Guerra Civil Española"}'),
      ]);
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(messages: const [], prompt: _prompt);

      expect(ai.callCount, 2);
      expect(session.pages, hasLength(1));
      // La página materializada siempre trae al menos un párrafo vacío de
      // relleno (comportamiento normal de _materializeAiBlocks), pero no
      // debe contener ningún bloque con contenido real.
      expect(session.pages.single.blocks.every((b) => b.text.trim().isEmpty), isTrue);
      expect(outcome.reply.toLowerCase(), contains('no conseguí generar contenido'));
    },
  );

  test('si el primer intento ya trae bloques, no hace falta reintentar', () async {
    final ai = _ScriptedAiService([
      const AiCompletionResult(
        text: '{"title":"Guerra Civil Española","blocks":[{"type":"paragraph","text":"Ya con contenido."}]}',
      ),
    ]);
    final session = _readySession(ai);

    final outcome = await session.agentChatWithAi(messages: const [], prompt: _prompt);

    expect(ai.callCount, 1);
    expect(session.pages.single.blocks, hasLength(1));
    expect(outcome.reply, contains('1 bloque'));
  });
}
