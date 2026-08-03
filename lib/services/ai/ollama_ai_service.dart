import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'ai_service.dart';
import 'ai_types.dart';

class OllamaAiService implements AiService {
  OllamaAiService({
    required this.baseUrl,
    required this.timeout,
    required this.defaultModel,
  });

  final Uri baseUrl;
  final Duration timeout;
  final String defaultModel;

  static const _uuid = Uuid();

  /// Familias de modelo conocidas por soportar `tools` en `/api/chat` de
  /// forma razonable. Es una heurística por substring del nombre configurado,
  /// no una garantía — el llamador siempre debe estar preparado para que el
  /// modelo ignore `tools` y responda solo en texto (de ahí la emulación
  /// JSON en `ai_tool_json_emulation.dart` como red de seguridad real).
  static const _toolCapableModelSubstrings = [
    'llama3.1',
    'llama-3.1',
    'llama3.2',
    'llama-3.2',
    'llama3.3',
    'qwen2.5',
    'qwen3',
    'mistral-nemo',
    'mixtral',
    'firefunction',
    'command-r',
  ];

  @override
  String get providerName => 'ollama';

  @override
  bool get supportsNativeToolCalling {
    final model = defaultModel.toLowerCase();
    return _toolCapableModelSubstrings.any(model.contains);
  }

  @override
  bool get supportsImageGeneration => false;

  @override
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  }) {
    throw AiImageGenerationUnsupportedException(providerName);
  }

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final client = HttpClient();
    try {
      final endpoint = baseUrl.resolve('/api/chat');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
      httpReq.write(jsonEncode(_buildPayload(request, stream: false)));
      final response = await httpReq.close().timeout(timeout);
      final body = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Ollama respondió ${response.statusCode}: $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg = (json['message'] as Map<String, dynamic>?) ?? const {};
      final content = (msg['content'] as String? ?? '').trim();
      final toolCalls = _parseToolCalls(msg);

      if (content.isEmpty && (toolCalls == null || toolCalls.isEmpty)) {
        throw StateError('Ollama devolvió respuesta vacía');
      }
      return AiCompletionResult(
        text: content,
        provider: providerName,
        model: request.model == 'auto' ? defaultModel : request.model,
        usage: _parseUsage(json),
        toolCalls: toolCalls,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Streaming real vía NDJSON de `/api/chat` (`stream: true`): cada línea es
  /// un objeto JSON con un fragmento nuevo en `message.content`; la última
  /// línea trae `done: true` junto con las stats y, si el modelo pidió una
  /// tool, `message.tool_calls` ya completas (Ollama no las trocea en
  /// deltas incrementales como OpenAI).
  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final client = HttpClient();
    try {
      final endpoint = baseUrl.resolve('/api/chat');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
      httpReq.write(jsonEncode(_buildPayload(request, stream: true)));
      final response = await httpReq.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response).timeout(timeout);
        throw StateError('Ollama respondió ${response.statusCode}: $body');
      }
      final lines = response.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final json = jsonDecode(line) as Map<String, dynamic>;
        final msg = (json['message'] as Map<String, dynamic>?) ?? const {};
        final delta = msg['content'] as String? ?? '';
        final done = json['done'] as bool? ?? false;
        if (!done) {
          if (delta.isNotEmpty) yield AiCompletionChunk(textDelta: delta);
          continue;
        }
        yield AiCompletionChunk(
          textDelta: delta,
          isFinal: true,
          usage: _parseUsage(json),
          toolCalls: _parseToolCalls(msg),
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _buildPayload(AiCompletionRequest request, {required bool stream}) {
    final mergedPrompt = _buildPrompt(request);
    final imageAttachments = request.attachments
        .where((a) => a.mimeType.startsWith('image/'))
        .toList();
    final payload = <String, dynamic>{
      'model': request.model == 'auto' ? defaultModel : request.model,
      'stream': stream,
      'messages': [
        if ((request.systemPrompt ?? '').trim().isNotEmpty)
          {'role': 'system', 'content': request.systemPrompt!.trim()},
        ...request.messages.map(_encodeHistoryMessage),
        {
          'role': 'user',
          'content': mergedPrompt,
          if (imageAttachments.isNotEmpty)
            'images': imageAttachments.map((a) => a.content.trim()).toList(),
        },
      ],
    };
    if (request.tools.isNotEmpty && supportsNativeToolCalling) {
      payload['tools'] = request.tools.map((t) => t.toJsonSchema()).toList();
    }
    final options = <String, dynamic>{};
    if (request.temperature != null) options['temperature'] = request.temperature;
    if (request.topK != null) options['top_k'] = request.topK;
    if (request.topP != null) options['top_p'] = request.topP;
    if (request.stop != null && request.stop!.isNotEmpty) options['stop'] = request.stop;
    if (request.maxTokens != null) options['num_predict'] = request.maxTokens;
    if (options.isNotEmpty) payload['options'] = options;
    if (request.responseSchema != null) payload['format'] = request.responseSchema;
    return payload;
  }

  List<AiToolCall>? _parseToolCalls(Map<String, dynamic> msg) {
    final rawToolCalls = msg['tool_calls'];
    if (rawToolCalls is! List || rawToolCalls.isEmpty) return null;
    return rawToolCalls.whereType<Map>().map((raw) {
      final fn = (raw['function'] as Map?) ?? const {};
      final rawArgs = fn['arguments'];
      final args = rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : <String, dynamic>{};
      return AiToolCall(id: 'ollama_${_uuid.v4()}', name: fn['name'] as String? ?? '', arguments: args);
    }).toList();
  }

  AiTokenUsage? _parseUsage(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return null;
    }

    final promptEval = asInt(json['prompt_eval_count']);
    final evalCount = asInt(json['eval_count']);
    if (promptEval == null && evalCount == null) return null;
    return AiTokenUsage(
      promptTokens: promptEval,
      completionTokens: evalCount,
      totalTokens: (promptEval != null && evalCount != null) ? promptEval + evalCount : null,
    );
  }

  /// Codifica un mensaje del historial para `/api/chat`, incluyendo
  /// tool-calls del asistente y resultados de tool. Ollama no usa un
  /// `tool_call_id` para emparejar resultados (a diferencia de OpenAI), así
  /// que los mensajes `role: tool` solo llevan `content`.
  Map<String, dynamic> _encodeHistoryMessage(AiChatMessage m) {
    if (m.role == 'tool') {
      return {'role': 'tool', 'content': m.content};
    }
    if (m.role == 'assistant' && m.toolCalls != null && m.toolCalls!.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': m.content,
        'tool_calls': m.toolCalls!
            .map((c) => {'function': {'name': c.name, 'arguments': c.arguments}})
            .toList(),
      };
    }
    return {'role': m.role, 'content': m.content};
  }

  @override
  Future<void> ping() async {
    final client = HttpClient();
    try {
      final req = await client
          .getUrl(baseUrl.resolve('/api/tags'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Ollama no disponible (${res.statusCode})');
      }
      await res.drain();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<String>> listModels() async {
    final client = HttpClient();
    try {
      final req = await client
          .getUrl(baseUrl.resolve('/api/tags'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      final body = await utf8.decodeStream(res).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Ollama no disponible (${res.statusCode})');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final models = (json['models'] as List<dynamic>? ?? const [])
          .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((name) => name.trim().isNotEmpty)
          .toList();
      return models;
    } finally {
      client.close(force: true);
    }
  }

  String _buildPrompt(AiCompletionRequest request) {
    final b = StringBuffer(request.prompt.trim());
    final textAttachments = request.attachments
        .where((a) => !a.mimeType.startsWith('image/'))
        .toList();
    final imageAttachments = request.attachments
        .where((a) => a.mimeType.startsWith('image/'))
        .toList();
    if (textAttachments.isNotEmpty) {
      b.write('\n\nAdjuntos:\n');
      for (final a in textAttachments) {
        b.write('\n--- ${a.name} (${a.mimeType}) ---\n${a.content}\n');
      }
    }
    if (imageAttachments.isNotEmpty) {
      b.write(
        '\n\nSe adjuntaron ${imageAttachments.length} imagen(es). Analízalas junto al mensaje.\n',
      );
    }
    return b.toString().trim();
  }
}
