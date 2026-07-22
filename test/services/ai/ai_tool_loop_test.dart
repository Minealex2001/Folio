import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/ai_tool_loop.dart';
import 'package:folio/services/ai/ai_types.dart';

/// [AiService] falso que devuelve una secuencia de resultados fijada de
/// antemano, uno por cada llamada a [complete]. Permite scriptar un turno de
/// tool-calling multi-paso sin depender de un proveedor real.
class _ScriptedAiService implements AiService {
  _ScriptedAiService(this._results);

  final List<AiCompletionResult> _results;
  int callCount = 0;
  final List<AiCompletionRequest> requests = [];

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    requests.add(request);
    final result = _results[callCount];
    callCount++;
    return result;
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

AiCompletionRequest _baseRequest() => const AiCompletionRequest(prompt: 'hola', model: 'auto');

void main() {
  test('runToolLoop devuelve texto directo cuando el modelo no pide tools', () async {
    final ai = _ScriptedAiService([
      const AiCompletionResult(text: 'Respuesta directa'),
    ]);

    final outcome = await runToolLoop(
      ai: ai,
      baseRequest: _baseRequest(),
      tools: const [],
      executeTool: (call) async => fail('no debería ejecutarse ninguna tool'),
    );

    expect(outcome.finalText, 'Respuesta directa');
    expect(outcome.steps, isEmpty);
    expect(ai.callCount, 1);
  });

  test('runToolLoop ejecuta una tool y realimenta el resultado antes de responder', () async {
    final ai = _ScriptedAiService([
      const AiCompletionResult(
        text: '',
        toolCalls: [AiToolCall(id: 'c1', name: 'create_page', arguments: {'title': 'X'})],
      ),
      const AiCompletionResult(text: 'Página creada.'),
    ]);
    final executed = <String>[];

    final outcome = await runToolLoop(
      ai: ai,
      baseRequest: _baseRequest(),
      tools: const [AiToolDefinition(name: 'create_page', description: 'crea página')],
      executeTool: (call) async {
        executed.add(call.name);
        return AiToolResult.ok(call.id, '{"pageId":"p1"}');
      },
    );

    expect(outcome.finalText, 'Página creada.');
    expect(executed, ['create_page']);
    expect(outcome.steps, hasLength(1));
    expect(outcome.steps.single.result.content, '{"pageId":"p1"}');
    expect(ai.callCount, 2);
    // El segundo request debe incluir el mensaje de rol 'tool' con el resultado.
    final secondRequestMessages = ai.requests[1].messages;
    expect(secondRequestMessages.any((m) => m.role == 'tool' && m.content == '{"pageId":"p1"}'), isTrue);
  });

  test('runToolLoop encadena varios pasos de tools antes del texto final', () async {
    final ai = _ScriptedAiService([
      const AiCompletionResult(
        text: '',
        toolCalls: [AiToolCall(id: 'c1', name: 'search_pages', arguments: {'query': 'a'})],
      ),
      const AiCompletionResult(
        text: '',
        toolCalls: [AiToolCall(id: 'c2', name: 'create_page', arguments: {'title': 'Y'})],
      ),
      const AiCompletionResult(text: 'Listo.'),
    ]);
    final executed = <String>[];

    final outcome = await runToolLoop(
      ai: ai,
      baseRequest: _baseRequest(),
      tools: const [],
      executeTool: (call) async {
        executed.add(call.name);
        return AiToolResult.ok(call.id, '{}');
      },
    );

    expect(executed, ['search_pages', 'create_page']);
    expect(outcome.finalText, 'Listo.');
    expect(outcome.steps, hasLength(2));
  });

  test('runToolLoop corta el ciclo si la misma tool se repite con los mismos argumentos', () async {
    final repeatedCall = () => const AiCompletionResult(
      text: '',
      toolCalls: [AiToolCall(id: 'c1', name: 'noop', arguments: {'x': 1})],
    );
    final ai = _ScriptedAiService([
      repeatedCall(),
      repeatedCall(),
      const AiCompletionResult(text: 'Me rindo, esto es lo que sé.'),
    ]);

    final outcome = await runToolLoop(
      ai: ai,
      baseRequest: _baseRequest(),
      tools: const [],
      executeTool: (call) async => AiToolResult.ok(call.id, '{}'),
      maxSteps: 6,
    );

    // Debe detectar la repetición en el 2º paso y forzar un cierre en texto,
    // sin llegar a agotar maxSteps.
    expect(outcome.finalText, 'Me rindo, esto es lo que sé.');
    expect(ai.callCount, 3);
  });

  test('runToolLoop respeta maxSteps y fuerza un cierre en texto', () async {
    AiCompletionResult loopingCall(int i) => AiCompletionResult(
      text: '',
      toolCalls: [AiToolCall(id: 'c$i', name: 'noop', arguments: {'i': i})],
    );
    final ai = _ScriptedAiService([
      loopingCall(1),
      loopingCall(2),
      const AiCompletionResult(text: 'Cierre forzado.'),
    ]);

    final outcome = await runToolLoop(
      ai: ai,
      baseRequest: _baseRequest(),
      tools: const [],
      executeTool: (call) async => AiToolResult.ok(call.id, '{}'),
      maxSteps: 2,
    );

    expect(outcome.finalText, 'Cierre forzado.');
    expect(outcome.steps, hasLength(2));
    expect(ai.callCount, 3);
  });

  test('AiToolLoopOutcome.errors expone los resultados de tools fallidas', () async {
    final ai = _ScriptedAiService([
      const AiCompletionResult(
        text: '',
        toolCalls: [AiToolCall(id: 'c1', name: 'trash_page', arguments: {'pageId': 'x'})],
      ),
      const AiCompletionResult(text: 'No se pudo completar la acción.'),
    ]);

    final outcome = await runToolLoop(
      ai: ai,
      baseRequest: _baseRequest(),
      tools: const [],
      executeTool: (call) async => AiToolResult.error(call.id, 'Página no encontrada'),
    );

    expect(outcome.errors, ['Página no encontrada']);
  });

  test('runToolLoop emite eventos de inicio y resultado por cada tool call vía onEvent', () async {
    final ai = _ScriptedAiService([
      const AiCompletionResult(
        text: '',
        toolCalls: [AiToolCall(id: 'c1', name: 'create_page', arguments: {'title': 'X'})],
      ),
      const AiCompletionResult(text: 'Listo.'),
    ]);
    final events = <AiToolLoopEvent>[];

    await runToolLoop(
      ai: ai,
      baseRequest: _baseRequest(),
      tools: const [],
      executeTool: (call) async => AiToolResult.ok(call.id, '{"pageId":"p1"}'),
      onEvent: events.add,
    );

    expect(events, hasLength(2));
    expect(events[0].kind, AiToolLoopEventKind.toolCallStart);
    expect(events[0].call.name, 'create_page');
    expect(events[0].result, isNull);
    expect(events[1].kind, AiToolLoopEventKind.toolCallResult);
    expect(events[1].result?.content, '{"pageId":"p1"}');
  });
}
