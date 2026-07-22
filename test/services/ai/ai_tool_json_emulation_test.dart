import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/ai_tool_json_emulation.dart';
import 'package:folio/services/ai/ai_types.dart';

class _FixedAiService implements AiService {
  _FixedAiService(this.responseText, {this.nativeToolCalling = false});

  final String responseText;
  final bool nativeToolCalling;
  AiCompletionRequest? lastRequest;

  @override
  bool get supportsNativeToolCalling => nativeToolCalling;

  @override
  String get providerName => 'fixed';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    lastRequest = request;
    return AiCompletionResult(text: responseText, provider: providerName);
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    yield AiCompletionChunk(textDelta: responseText, isFinal: true);
  }

  @override
  Future<void> ping() async {}

  @override
  Future<List<String>> listModels() async => const [];
}

const _tools = [
  AiToolDefinition(
    name: 'create_page',
    description: 'crea una página',
    parameters: [AiToolParam(name: 'title', type: 'string', description: 'título', required: true)],
  ),
];

AiCompletionRequest _req() => const AiCompletionRequest(prompt: 'hola', model: 'auto');

void main() {
  test('buildToolEmulationSystemPromptAppendix menciona el nombre de cada tool', () {
    final appendix = buildToolEmulationSystemPromptAppendix(_tools, isEs: true);
    expect(appendix, contains('create_page'));
    expect(appendix, contains('toolCall'));
  });

  test('completeWithToolEmulation parsea un toolCall válido', () async {
    final ai = _FixedAiService('{"toolCall":{"name":"create_page","arguments":{"title":"X"}}}');

    final result = await completeWithToolEmulation(ai: ai, request: _req(), tools: _tools);

    expect(result.hasToolCalls, isTrue);
    expect(result.toolCalls!.single.name, 'create_page');
    expect(result.toolCalls!.single.arguments['title'], 'X');
    // El schema de emulación debe haberse pasado como responseSchema.
    expect(ai.lastRequest!.responseSchema, isNotNull);
  });

  test('completeWithToolEmulation parsea un finalReply válido', () async {
    final ai = _FixedAiService('{"finalReply":"Hola, ¿en qué ayudo?"}');

    final result = await completeWithToolEmulation(ai: ai, request: _req(), tools: _tools);

    expect(result.hasToolCalls, isFalse);
    expect(result.text, 'Hola, ¿en qué ayudo?');
  });

  test('completeWithToolEmulation recupera JSON envuelto en prosa', () async {
    final ai = _FixedAiService(
      'Claro, aquí tienes:\n{"toolCall":{"name":"create_page","arguments":{"title":"Y"}}}\nGracias.',
    );

    final result = await completeWithToolEmulation(ai: ai, request: _req(), tools: _tools);

    expect(result.hasToolCalls, isTrue);
    expect(result.toolCalls!.single.arguments['title'], 'Y');
  });

  test('completeWithToolEmulation degrada a texto plano si el modelo no devuelve JSON', () async {
    final ai = _FixedAiService('Esto no es JSON en absoluto.');

    final result = await completeWithToolEmulation(ai: ai, request: _req(), tools: _tools);

    expect(result.hasToolCalls, isFalse);
    expect(result.text, 'Esto no es JSON en absoluto.');
  });

  test('completeWithToolEmulation no toca la petición si no hay tools', () async {
    final ai = _FixedAiService('respuesta normal');

    final result = await completeWithToolEmulation(ai: ai, request: _req(), tools: const []);

    expect(result.text, 'respuesta normal');
    expect(ai.lastRequest!.responseSchema, isNull);
  });

  group('withToolCallingSupport / ToolEmulatingAiService', () {
    test('deja pasar un servicio con soporte nativo sin envolver', () {
      final ai = _FixedAiService('x', nativeToolCalling: true);
      expect(withToolCallingSupport(ai), same(ai));
    });

    test('envuelve un servicio sin soporte nativo y expone supportsNativeToolCalling=true', () async {
      final inner = _FixedAiService('{"toolCall":{"name":"create_page","arguments":{}}}');
      final wrapped = withToolCallingSupport(inner);

      expect(wrapped.supportsNativeToolCalling, isTrue);
      expect(wrapped, isNot(same(inner)));

      final result = await wrapped.complete(
        AiCompletionRequest(prompt: 'hola', model: 'auto', tools: _tools),
      );
      expect(result.hasToolCalls, isTrue);
    });
  });
}
