import 'package:uuid/uuid.dart';

import 'ai_service.dart';
import 'ai_types.dart';
import 'json_lenient_decoder.dart';

/// Camino de compatibilidad para proveedores/modelos sin `tools` nativo
/// fiable (modelos locales vía Ollama/LM Studio, y Folio Cloud hasta que su
/// Cloud Function soporte tool-calling). En vez de confiar en el campo
/// `tools` de la API del proveedor, se le pide al modelo — vía system prompt
/// + `responseSchema` de decodificación estricta, que Ollama y LM Studio ya
/// soportan — que devuelva JSON con la forma `{"toolCall": {...}}` o
/// `{"finalReply": "..."}`; el resultado se parsea de forma tolerante
/// (misma utilidad que usa el camino JSON legado de `agentChatWithAi`).
const _uuid = Uuid();

String buildToolEmulationSystemPromptAppendix(
  List<AiToolDefinition> tools, {
  required bool isEs,
}) {
  final b = StringBuffer();
  if (isEs) {
    b.writeln(
      'Tienes disponibles las siguientes acciones (tools). Para invocar una, '
      'responde ÚNICAMENTE con un objeto JSON de la forma '
      '{"toolCall":{"name":"<nombre>","arguments":{...}}}. '
      'Si no necesitas invocar ninguna acción y quieres responder directamente '
      'al usuario, responde ÚNICAMENTE con '
      '{"finalReply":"<tu respuesta en texto>"}. No devuelvas nada fuera de ese JSON.',
    );
  } else {
    b.writeln(
      'You have the following actions (tools) available. To invoke one, '
      'reply with ONLY a JSON object shaped like '
      '{"toolCall":{"name":"<name>","arguments":{...}}}. '
      'If you do not need to invoke any action and want to reply directly to '
      'the user, reply with ONLY {"finalReply":"<your text reply>"}. '
      'Return nothing outside that JSON.',
    );
  }
  b.writeln();
  for (final tool in tools) {
    final paramsDesc = tool.parameters
        .map((p) => '${p.name}${p.required ? '' : '?'}: ${p.type} — ${p.description}')
        .join('; ');
    b.writeln('- ${tool.name}: ${tool.description}${paramsDesc.isEmpty ? '' : ' ($paramsDesc)'}');
  }
  return b.toString();
}

/// JSON Schema para forzar la forma `{toolCall|finalReply}` vía
/// `AiCompletionRequest.responseSchema` en los proveedores que lo soportan
/// (Ollama: `format`; LM Studio/OpenAI-compatible: `response_format`).
Map<String, dynamic> toolEmulationResponseSchema() => {
  'type': 'object',
  'properties': {
    'toolCall': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'arguments': {'type': 'object'},
      },
    },
    'finalReply': {'type': 'string'},
  },
};

/// Ejecuta un turno de [request] emulando tool-calling sobre un [AiService]
/// sin `tools` nativo: añade el apéndice de instrucciones + schema, llama a
/// `ai.complete()`, y parsea el JSON de vuelta a `toolCall` o `finalReply`.
///
/// Si el modelo ignora la instrucción y devuelve texto libre no-JSON, se
/// trata como si fuera la respuesta final (mejor degradar a una respuesta de
/// chat normal que fallar el turno).
Future<AiCompletionResult> completeWithToolEmulation({
  required AiService ai,
  required AiCompletionRequest request,
  required List<AiToolDefinition> tools,
  bool isEs = true,
}) async {
  if (tools.isEmpty) return ai.complete(request);

  final appendix = buildToolEmulationSystemPromptAppendix(tools, isEs: isEs);
  final baseSystemPrompt = (request.systemPrompt ?? '').trim();
  final emulatedRequest = AiCompletionRequest(
    prompt: request.prompt,
    model: request.model,
    systemPrompt: baseSystemPrompt.isEmpty ? appendix : '$baseSystemPrompt\n\n$appendix',
    messages: request.messages,
    attachments: request.attachments,
    maxTokens: request.maxTokens,
    temperature: request.temperature,
    topK: request.topK,
    topP: request.topP,
    stop: request.stop,
    responseSchema: toolEmulationResponseSchema(),
    cloudInkOperation: request.cloudInkOperation,
  );

  final raw = await ai.complete(emulatedRequest);

  try {
    final decoded = decodeJsonObjectLenient(raw.text);

    final toolCallRaw = decoded['toolCall'];
    if (toolCallRaw is Map) {
      final name = (toolCallRaw['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        final rawArgs = toolCallRaw['arguments'];
        final args = rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : <String, dynamic>{};
        return AiCompletionResult(
          text: '',
          provider: raw.provider,
          model: raw.model,
          usage: raw.usage,
          toolCalls: [AiToolCall(id: 'emu_${_uuid.v4()}', name: name, arguments: args)],
        );
      }
    }

    final finalReply = (decoded['finalReply'] as String?)?.trim();
    if (finalReply != null && finalReply.isNotEmpty) {
      return AiCompletionResult(
        text: finalReply,
        provider: raw.provider,
        model: raw.model,
        usage: raw.usage,
      );
    }
  } catch (_) {
    // El modelo no devolvió JSON válido: se degrada a tratar `raw.text` como
    // respuesta final en vez de fallar el turno completo.
  }

  return raw;
}

/// Envuelve un [AiService] sin `tools` nativo para que, desde el punto de
/// vista de [runToolLoop] (`ai_tool_loop.dart`), se comporte como si sí lo
/// soportara — el bucle no necesita saber si una tool call vino de la API
/// nativa del proveedor o de esta emulación.
class ToolEmulatingAiService implements AiService {
  ToolEmulatingAiService(this._inner, {this.isEs = true});

  final AiService _inner;
  final bool isEs;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => _inner.providerName;

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) {
    return completeWithToolEmulation(ai: _inner, request: request, tools: request.tools, isEs: isEs);
  }

  // La emulación depende de decodificar el JSON completo de la respuesta, así
  // que no hay streaming incremental real posible aquí — se emite todo como
  // un único chunk final una vez resuelto `complete()`.
  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final result = await complete(request);
    yield AiCompletionChunk(
      textDelta: result.text,
      isFinal: true,
      usage: result.usage,
      toolCalls: result.toolCalls,
    );
  }

  @override
  Future<void> ping() => _inner.ping();

  @override
  Future<List<String>> listModels() => _inner.listModels();

  @override
  bool get supportsImageGeneration => _inner.supportsImageGeneration;

  @override
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  }) => _inner.generateImage(prompt: prompt, pageContextText: pageContextText);
}

/// Devuelve `ai` tal cual si ya soporta `tools` nativo, o lo envuelve en
/// [ToolEmulatingAiService] si no. Punto único de decisión para quien arme
/// el `AiService` que se le pasa a `runToolLoop`.
AiService withToolCallingSupport(AiService ai, {bool isEs = true}) {
  return ai.supportsNativeToolCalling ? ai : ToolEmulatingAiService(ai, isEs: isEs);
}
