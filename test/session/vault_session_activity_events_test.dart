import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/session/vault_session.dart';

/// Fase 4 del roadmap de producto — feed de "Cambios recientes". Cubre el
/// gancho `recordAiTurnActivity` (llamado desde `agentChatWithAi` cuando el
/// turno tuvo cambios de contenido reversibles) que alimenta
/// `VaultSession.recentActivityEvents`, y el conteo de
/// `aiTurnChangeCount` de la Fase 0 (banner "Quill hizo N cambios").
class _ScriptedAiService implements AiService {
  _ScriptedAiService(this._results);

  final List<AiCompletionResult> _results;
  int callCount = 0;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final r = _results[callCount];
    callCount++;
    return r;
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final result = await complete(request);
    yield AiCompletionChunk(textDelta: result.text, isFinal: true, toolCalls: result.toolCalls);
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

void main() {
  test(
    'un turno con cambios de contenido registra un evento de actividad por página tocada',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(
          text: '',
          toolCalls: [
            AiToolCall(
              id: 'c1',
              name: 'append_blocks_to_page',
              arguments: {
                'pageId': 'page_a',
                'blocks': [
                  {'type': 'paragraph', 'text': 'Añadido por IA'},
                ],
              },
            ),
          ],
        ),
        const AiCompletionResult(text: 'Hecho.'),
      ]);
      final session = _readySession(ai);
      session.createPageWithId(id: 'page_a', title: 'Arquitectura', blocks: const []);

      expect(session.recentActivityEvents, isEmpty);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Añade una nota',
        useToolCalling: true,
      );

      expect(outcome.aiTurnId, isNotNull);
      expect(outcome.aiTurnChangeCount, 1);
      expect(session.recentActivityEvents, hasLength(1));
      final event = session.recentActivityEvents.single;
      expect(event.pageId, 'page_a');
      expect(event.pageTitle, 'Arquitectura');
      expect(event.kind, VaultActivityEventKind.aiEdit);
    },
  );

  test(
    'un turno con tool no reversible (create_page) NO registra evento de actividad',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(
          text: '',
          toolCalls: [
            AiToolCall(
              id: 'c1',
              name: 'create_page',
              arguments: {
                'title': 'Nueva página',
                'blocks': [
                  {'type': 'paragraph', 'text': 'x'},
                ],
              },
            ),
          ],
        ),
        const AiCompletionResult(text: 'Hecho.'),
      ]);
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Crea una página nueva',
        useToolCalling: true,
      );

      expect(outcome.aiTurnId, isNull);
      expect(session.recentActivityEvents, isEmpty);
    },
  );

  test(
    'un turno de solo lectura (sin cambios) NO registra evento de actividad',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(
          text: '',
          toolCalls: [
            AiToolCall(id: 'c1', name: 'search_pages', arguments: {'query': 'x'}),
          ],
        ),
        const AiCompletionResult(text: 'No encontré nada.'),
      ]);
      final session = _readySession(ai);

      await session.agentChatWithAi(
        messages: const [],
        prompt: 'Busca x',
        useToolCalling: true,
      );

      expect(session.recentActivityEvents, isEmpty);
    },
  );

  test('recentActivityEvents devuelve los más recientes primero', () {
    final session = VaultSession();
    session.debugMarkUnlockedForTests();
    session.createPageWithId(id: 'p1', title: 'Uno', blocks: const []);
    session.createPageWithId(id: 'p2', title: 'Dos', blocks: const []);

    final t1 = session.beginAiTurnUndoGroup();
    session.renamePage('p1', 'Uno editado');
    session.endAiTurnUndoGroup(t1);
    session.recordAiTurnActivity(t1);

    final t2 = session.beginAiTurnUndoGroup();
    session.renamePage('p2', 'Dos editado');
    session.endAiTurnUndoGroup(t2);
    session.recordAiTurnActivity(t2);

    expect(session.recentActivityEvents.map((e) => e.pageId).toList(), ['p2', 'p1']);
  });
}
