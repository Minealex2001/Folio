import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/session/vault_session.dart';

/// [AiService] falso que devuelve resultados scriptados en orden, para
/// probar `agentChatWithAi(useToolCalling: true)` end-to-end sin un backend
/// de IA real.
class _ScriptedAiService implements AiService {
  _ScriptedAiService(this._results, {String providerName = 'scripted'})
    : _providerName = providerName;

  final List<AiCompletionResult> _results;
  final String _providerName;
  int callCount = 0;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => _providerName;

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
}

VaultSession _readySession(AiService ai) {
  final session = VaultSession();
  session.debugMarkUnlockedForTests();
  session.setAiService(ai);
  return session;
}

void main() {
  test(
    'agentChatWithAi(useToolCalling: true) ejecuta una tool declarada y responde con el texto final',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(
          text: '',
          toolCalls: [
            AiToolCall(id: 'c1', name: 'create_page', arguments: {
              'title': 'Notas del viaje',
              'blocks': [
                {'type': 'paragraph', 'text': 'Primer día'},
              ],
            }),
          ],
        ),
        const AiCompletionResult(text: 'He creado la página "Notas del viaje".'),
      ]);
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Crea una página de notas del viaje',
        useToolCalling: true,
      );

      expect(outcome.reply, 'He creado la página "Notas del viaje".');
      expect(session.pages, hasLength(1));
      expect(session.pages.single.title, 'Notas del viaje');
      expect(ai.callCount, 2);
    },
  );

  test(
    'agentChatWithAi(useToolCalling: true) responde en texto directo sin tools',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(text: 'Hola, ¿en qué puedo ayudarte?'),
      ]);
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Hola',
        useToolCalling: true,
      );

      expect(outcome.reply, 'Hola, ¿en qué puedo ayudarte?');
      expect(session.pages, isEmpty);
    },
  );

  test(
    'agentChatWithAi(useToolCalling: true) expone el error de una tool fallida por separado del reply',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(
          text: '',
          toolCalls: [
            AiToolCall(id: 'c1', name: 'rename_page', arguments: {'pageId': 'inexistente', 'title': 'X'}),
          ],
        ),
        const AiCompletionResult(text: 'No pude completar la acción.'),
      ]);
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Renombra la página inexistente',
        useToolCalling: true,
      );

      expect(outcome.reply, 'No pude completar la acción.');
      expect(outcome.toolErrors, isNotNull);
      expect(outcome.toolErrors!.single.toLowerCase(), contains('página no encontrada'));
      expect(outcome.toolCalls, hasLength(1));
      expect(outcome.toolCalls!.single.name, 'rename_page');
    },
  );

  test(
    'agentChatWithAi sin useToolCalling (default) sigue usando el camino legado',
    () async {
      final ai = _ScriptedAiService([
        const AiCompletionResult(text: '{"mode":"chat","reply":"Respuesta legada"}'),
      ]);
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'Hola',
      );

      expect(outcome.reply, contains('Respuesta legada'));
      // El camino legado solo debería haber hecho una llamada (sin tool loop).
      expect(ai.callCount, 1);
    },
  );

  test(
    'agentChatWithAi(useToolCalling: true) permite hasta 8 pasos de tool loop (paridad MCP)',
    () async {
      AiCompletionResult loopingCall(int i) => AiCompletionResult(
        text: '',
        toolCalls: [AiToolCall(id: 'c$i', name: 'noop', arguments: {'i': i})],
      );
      final ai = _ScriptedAiService([
        for (var i = 1; i <= 8; i++) loopingCall(i),
        const AiCompletionResult(text: 'Cierre forzado por maxSteps.'),
      ], providerName: 'folio_cloud');
      final session = _readySession(ai);

      final outcome = await session.agentChatWithAi(
        messages: const [],
        prompt: 'haz varias cosas seguidas',
        useToolCalling: true,
      );

      // maxSteps=8: 8 llamadas con tool call + 1 de cierre = 9.
      expect(ai.callCount, 9);
      expect(outcome.reply, 'Cierre forzado por maxSteps.');
    },
  );
}
