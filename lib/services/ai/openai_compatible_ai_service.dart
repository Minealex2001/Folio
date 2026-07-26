import 'dart:convert';
import 'dart:io';

import 'ai_service.dart';
import 'ai_types.dart';

class OpenAiCompatibleAiService implements AiService {
  OpenAiCompatibleAiService({
    required this.baseUrl,
    required this.timeout,
    required this.defaultModel,
    required this.apiKey,
    required this.provider,
  });

  final Uri baseUrl;
  final Duration timeout;
  final String defaultModel;
  final String apiKey;
  final String provider; // 'openAi' or 'gemini' or 'custom'

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => provider;

  Uri _buildEndpoint(String path) {
    var base = baseUrl.toString();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.contains('/v1') || base.contains('/v1beta') || base.contains('/openai')) {
      return Uri.parse('$base/$path');
    } else {
      return Uri.parse('$base/v1/$path');
    }
  }

  void _setAuthHeaders(HttpClientRequest req) {
    if (apiKey.trim().isNotEmpty) {
      req.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
      req.headers.set('api-key', apiKey.trim());
      req.headers.set('x-goog-api-key', apiKey.trim());
    }
  }

  /// gpt-5 / o-series rechazan `max_tokens`; usan `max_completion_tokens`.
  static void _applyMaxOutputTokens(
    Map<String, dynamic> payload,
    String model,
    int maxTokens,
  ) {
    final m = model.trim().toLowerCase();
    final usesCompletionTokens = m.startsWith('gpt-5') ||
        m.startsWith('o1') ||
        m.startsWith('o3') ||
        m.startsWith('o4');
    if (usesCompletionTokens) {
      payload['max_completion_tokens'] = maxTokens;
    } else {
      payload['max_tokens'] = maxTokens;
    }
  }

  Map<String, dynamic> _buildPayload(AiCompletionRequest request) {
    final textAttachments = request.attachments
        .where((a) => !a.mimeType.startsWith('image/'))
        .toList();
    final imageAttachments = request.attachments
        .where((a) => a.mimeType.startsWith('image/'))
        .toList();

    final userMessageContent = imageAttachments.isEmpty
        ? _buildPrompt(request)
        : <Map<String, dynamic>>[
            {
              'type': 'text',
              'text': _buildPromptWithTextAttachments(request.prompt, textAttachments),
            },
            ...imageAttachments.map(
              (a) => {
                'type': 'image_url',
                'image_url': {'url': 'data:${a.mimeType};base64,${a.content.trim()}'},
              },
            ),
          ];

    final model = request.model == 'auto' ? defaultModel : request.model;
    final payload = <String, dynamic>{
      'model': model,
      'messages': [
        if ((request.systemPrompt ?? '').trim().isNotEmpty)
          {'role': 'system', 'content': request.systemPrompt!.trim()},
        ...request.messages.map(_encodeHistoryMessage),
        {'role': 'user', 'content': userMessageContent},
      ],
    };

    if (request.maxTokens != null) {
      _applyMaxOutputTokens(payload, model, request.maxTokens!);
    }
    if (request.temperature != null) payload['temperature'] = request.temperature;
    if (request.topP != null) payload['top_p'] = request.topP;
    if (request.stop != null && request.stop!.isNotEmpty) payload['stop'] = request.stop;
    if (request.tools.isNotEmpty) {
      payload['tools'] = request.tools.map((t) => t.toJsonSchema()).toList();
      payload['tool_choice'] = request.toolChoice ?? 'auto';
    }
    if (request.responseSchema != null) {
      payload['response_format'] = <String, dynamic>{
        'type': 'json_schema',
        'json_schema': <String, dynamic>{
          'name': 'quill_response',
          'strict': true,
          'schema': request.responseSchema,
        },
      };
    }
    return payload;
  }

  List<AiToolCall>? _parseToolCallsFromMessage(Map<String, dynamic> msg) {
    final rawToolCalls = msg['tool_calls'];
    if (rawToolCalls is! List || rawToolCalls.isEmpty) return null;
    return rawToolCalls.whereType<Map>().map((raw) {
      final fn = (raw['function'] as Map?) ?? const {};
      Map<String, dynamic> args = const {};
      final rawArgs = fn['arguments'];
      if (rawArgs is String && rawArgs.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawArgs);
          if (decoded is Map) args = Map<String, dynamic>.from(decoded);
        } catch (_) {
          // El modelo devolvió argumentos no-JSON; se deja vacío y el
          // ejecutor del tool decide cómo reaccionar.
        }
      }
      return AiToolCall(id: raw['id'] as String? ?? '', name: fn['name'] as String? ?? '', arguments: args);
    }).toList();
  }

  AiTokenUsage? _parseUsageMap(Map<String, dynamic> u) {
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return null;
    }

    return AiTokenUsage(
      promptTokens: asInt(u['prompt_tokens']),
      completionTokens: asInt(u['completion_tokens']),
      totalTokens: asInt(u['total_tokens']),
    );
  }

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final client = HttpClient();
    try {
      final endpoint = _buildEndpoint('chat/completions');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
      _setAuthHeaders(httpReq);

      httpReq.write(jsonEncode(_buildPayload(request)));
      final response = await httpReq.close().timeout(timeout);
      final body = await utf8.decodeStream(response).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Error del servicio de IA (${response.statusCode}): $body');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        throw StateError('El servicio de IA devolvió una respuesta vacía');
      }
      final first = choices.first as Map<String, dynamic>;
      final msg = (first['message'] as Map<String, dynamic>?) ?? const {};
      final content = (msg['content'] as String? ?? '').trim();
      final toolCalls = _parseToolCallsFromMessage(msg);

      if (content.isEmpty && (toolCalls == null || toolCalls.isEmpty)) {
        throw StateError('El servicio de IA devolvió una respuesta vacía');
      }

      final usageRaw = json['usage'];
      final usage = usageRaw is Map ? _parseUsageMap(Map<String, dynamic>.from(usageRaw)) : null;

      return AiCompletionResult(
        text: content,
        provider: providerName,
        model: request.model == 'auto' ? defaultModel : request.model,
        usage: usage,
        toolCalls: toolCalls,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Streaming real vía SSE (`data: {...}\n\n`, terminado en `data: [DONE]`).
  /// Los deltas de tool-calls llegan troceados por índice (`delta.tool_calls[].index`)
  /// — se acumulan por índice y se reensamblan al recibir `[DONE]`.
  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final client = HttpClient();
    try {
      final endpoint = _buildEndpoint('chat/completions');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
      _setAuthHeaders(httpReq);

      final payload = _buildPayload(request);
      payload['stream'] = true;
      payload['stream_options'] = {'include_usage': true};
      httpReq.write(jsonEncode(payload));

      final response = await httpReq.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response).timeout(timeout);
        throw StateError('Error del servicio de IA (${response.statusCode}): $body');
      }

      final toolCallIdByIndex = <int, String>{};
      final toolCallNameByIndex = <int, String>{};
      final toolCallArgsByIndex = <int, StringBuffer>{};
      AiTokenUsage? finalUsage;

      final lines = response.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') {
          final toolCalls = toolCallArgsByIndex.isEmpty && toolCallNameByIndex.isEmpty
              ? null
              : [
                  for (final index in {...toolCallIdByIndex.keys, ...toolCallNameByIndex.keys})
                    AiToolCall(
                      id: toolCallIdByIndex[index] ?? 'stream_$index',
                      name: toolCallNameByIndex[index] ?? '',
                      arguments: _tryDecodeArgs(toolCallArgsByIndex[index]?.toString()),
                    ),
                ];
          yield AiCompletionChunk(isFinal: true, usage: finalUsage, toolCalls: toolCalls);
          break;
        }

        Map<String, dynamic> event;
        try {
          event = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final usageRaw = event['usage'];
        if (usageRaw is Map) finalUsage = _parseUsageMap(Map<String, dynamic>.from(usageRaw));

        final choices = event['choices'] as List<dynamic>? ?? const [];
        if (choices.isEmpty) continue;
        final delta = (choices.first as Map<String, dynamic>)['delta'] as Map<String, dynamic>? ?? const {};

        final textDelta = delta['content'] as String? ?? '';
        if (textDelta.isNotEmpty) yield AiCompletionChunk(textDelta: textDelta);

        final rawToolCallDeltas = delta['tool_calls'];
        if (rawToolCallDeltas is List) {
          for (final rawDelta in rawToolCallDeltas) {
            if (rawDelta is! Map) continue;
            final index = (rawDelta['index'] as num?)?.toInt() ?? 0;
            final id = rawDelta['id'] as String?;
            if (id != null && id.isNotEmpty) toolCallIdByIndex[index] = id;
            final fn = rawDelta['function'] as Map?;
            if (fn != null) {
              final name = fn['name'] as String?;
              if (name != null && name.isNotEmpty) toolCallNameByIndex[index] = name;
              final argsChunk = fn['arguments'] as String?;
              if (argsChunk != null) {
                (toolCallArgsByIndex[index] ??= StringBuffer()).write(argsChunk);
              }
            }
          }
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _tryDecodeArgs(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Argumentos incompletos/no-JSON tras reensamblar los deltas.
    }
    return const {};
  }

  /// Codifica un mensaje del historial, incluyendo tool-calls del asistente
  /// (`role: 'assistant'` + `toolCalls`) y resultados de tool (`role: 'tool'`
  /// + `toolCallId`) en el formato OpenAI-compatible.
  Map<String, dynamic> _encodeHistoryMessage(AiChatMessage m) {
    if (m.role == 'tool') {
      return {
        'role': 'tool',
        'tool_call_id': m.toolCallId ?? '',
        'content': m.content,
      };
    }
    if (m.role == 'assistant' && m.toolCalls != null && m.toolCalls!.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': m.content.isEmpty ? null : m.content,
        'tool_calls': m.toolCalls!
            .map(
              (c) => {
                'id': c.id,
                'type': 'function',
                'function': {
                  'name': c.name,
                  'arguments': jsonEncode(c.arguments),
                },
              },
            )
            .toList(),
      };
    }
    return {'role': m.role, 'content': m.content};
  }

  @override
  Future<void> ping() async {
    final client = HttpClient();
    try {
      final endpoint = _buildEndpoint('models');
      final req = await client.getUrl(endpoint).timeout(timeout);
      if (apiKey.trim().isNotEmpty) {
        req.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
        req.headers.set('api-key', apiKey.trim());
        req.headers.set('x-goog-api-key', apiKey.trim());
      }
      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Servidor de IA no disponible (${res.statusCode})');
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
      final endpoint = _buildEndpoint('models');
      final req = await client.getUrl(endpoint).timeout(timeout);
      if (apiKey.trim().isNotEmpty) {
        req.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
        req.headers.set('api-key', apiKey.trim());
        req.headers.set('x-goog-api-key', apiKey.trim());
      }
      final res = await req.close().timeout(timeout);
      final body = await utf8.decodeStream(res).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('No se pudieron obtener los modelos (${res.statusCode})');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? const [];
      final models = data
          .map((e) => (e as Map<String, dynamic>)['id']?.toString() ?? '')
          .where((id) => id.trim().isNotEmpty)
          .toList();
      return models;
    } finally {
      client.close(force: true);
    }
  }

  String _buildPrompt(AiCompletionRequest request) {
    final textAttachments = request.attachments
        .where((a) => !a.mimeType.startsWith('image/'))
        .toList();
    return _buildPromptWithTextAttachments(request.prompt, textAttachments);
  }

  String _buildPromptWithTextAttachments(
    String prompt,
    List<AiFileAttachment> textAttachments,
  ) {
    final b = StringBuffer(prompt.trim());
    if (textAttachments.isNotEmpty) {
      b.write('\n\nAdjuntos:\n');
      for (final a in textAttachments) {
        b.write('\n--- ${a.name} (${a.mimeType}) ---\n${a.content}\n');
      }
    }
    return b.toString().trim();
  }
}
