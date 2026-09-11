import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/session/vault_session.dart';

/// Fase B3 del plan Quill/MCP — undo agrupado por turno de IA. Alcance
/// verificado: solo agrupa tools de CONTENIDO (`append_blocks_to_page` y
/// similares, que ya usan `_rememberUndoBeforePageMutation`); un turno que
/// usó alguna tool estructural/destructiva (`isReversible == false`, Fase
/// B1) no ofrece deshacer en absoluto — `aiTurnId` viene `null`.
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
    'un turno con tool-calls de contenido en 2 páginas se deshace por completo con undoAiTurn',
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
                  {'type': 'paragraph', 'text': 'Añadido por IA en A'},
                ],
              },
            ),
            AiToolCall(
              id: 'c2',
              name: 'append_blocks_to_page',
              arguments: {
                'pageId': 'page_b',
                'blocks': [
                  {'type': 'paragraph', 'text': 'Añadido por IA en B'},
                ],
              },
            ),
          ],
        ),
        const AiCompletionResult(text: 'Hecho.'),
      ]);
      final session = _readySession(ai);
      session.createPageWithId(id: 'page_a', title: 'A', blocks: const []);
      session.createPageWithId(id: 'page_b', title: 'B', blocks: const []);
      final beforeA = List.of(session.pages.firstWhere((p) => p.id == 'page_a').blocks);
      final beforeB = List.of(session.pages.firstWhere((p) => p.id == 'page_b').blocks);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Añade una nota a A y otra a B',
        useToolCalling: true,
      );

      expect(outcome.aiTurnId, isNotNull);
      expect(
        session.pages.firstWhere((p) => p.id == 'page_a').blocks.map((b) => b.text),
        contains('Añadido por IA en A'),
      );
      expect(
        session.pages.firstWhere((p) => p.id == 'page_b').blocks.map((b) => b.text),
        contains('Añadido por IA en B'),
      );

      session.undoAiTurn(outcome.aiTurnId!);

      expect(
        session.pages.firstWhere((p) => p.id == 'page_a').blocks.map((b) => b.text).toList(),
        beforeA.map((b) => b.text).toList(),
      );
      expect(
        session.pages.firstWhere((p) => p.id == 'page_b').blocks.map((b) => b.text).toList(),
        beforeB.map((b) => b.text).toList(),
      );
    },
  );

  test(
    'un turno que usó una tool estructural (create_page) no ofrece deshacer (aiTurnId null)',
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
      expect(session.pages, hasLength(1));
    },
  );

  test(
    'un turno sin ningún cambio de contenido (solo lectura) no ofrece deshacer',
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

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Busca x',
        useToolCalling: true,
      );

      expect(outcome.aiTurnId, isNull);
    },
  );

  group('VaultSession undo-turn primitives (aisladas de la IA)', () {
    test('beginAiTurnUndoGroup + undoAiTurn deshace solo lo tocado durante el turno', () {
      final session = VaultSession();
      session.debugMarkUnlockedForTests();
      session.addPage(parentId: null);
      final pageId = session.pages.first.id;
      // Mutación previa al turno (rename, sin coalescing de tecleo — a
      // diferencia de `updateBlockText`): no debe deshacerse por `undoAiTurn`.
      session.renamePage(pageId, 'Antes del turno');

      final turnId = session.beginAiTurnUndoGroup();
      session.renamePage(pageId, 'Durante el turno');
      session.endAiTurnUndoGroup(turnId);

      expect(session.aiTurnHasUndoableChanges(turnId), isTrue);
      session.undoAiTurn(turnId);

      expect(session.pages.first.title, 'Antes del turno');
    });

    test('discardAiTurnUndoGroup descarta el grupo sin deshacer nada', () {
      final session = VaultSession();
      session.debugMarkUnlockedForTests();
      session.addPage(parentId: null);
      final pageId = session.pages.first.id;

      final turnId = session.beginAiTurnUndoGroup();
      session.renamePage(pageId, 'Cambiado');
      session.endAiTurnUndoGroup(turnId);
      session.discardAiTurnUndoGroup(turnId);

      expect(session.aiTurnHasUndoableChanges(turnId), isFalse);
      expect(session.pages.first.title, 'Cambiado');
    });
  });
}
