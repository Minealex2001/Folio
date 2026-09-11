import 'dart:convert';
import 'dart:io';

import 'ai_http_cancel.dart';
import 'ai_service.dart';
import 'ai_types.dart';
import 'openai_compatible_sse.dart';

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

  /// Modelo de imagen por defecto para OpenAI (BYOK o cualquier endpoint
  /// OpenAI-compatible apuntado a un servidor local tipo LocalAI/ComfyUI-shim).
  /// Confirmado por el usuario: mismo modelo que usa Quill Cloud en el backend.
  static const _defaultOpenAiImageModel = 'gpt-image-2-2026-04-21';

  @override
  bool get supportsImageGeneration => true;

  /// Genera una imagen vía `POST {baseUrl}/images/generations`. **Riesgo
  /// conocido**: este mismo servicio atiende tanto `openAi` como `gemini`
  /// (BYOK) — el shim "OpenAI-compatible" de Gemini podría no exponer este
  /// endpoint con el mismo shape. Si falla en la práctica, ramificar por
  /// `provider` aquí mismo sin cambiar la interfaz pública.
  @override
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  }) async {
    final client = HttpClient();
    try {
      final endpoint = _buildEndpoint('images/generations');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
      _setAuthHeaders(httpReq);

      final combinedPrompt = (pageContextText == null || pageContextText.trim().isEmpty)
          ? prompt.trim()
          : '${prompt.trim()}\n\n---\n${pageContextText.trim()}';
      final model = provider == 'openAi' ? _defaultOpenAiImageModel : defaultModel;
      // `response_format` no es válido para modelos de imagen recientes
      // (p. ej. gpt-image-*) — siempre devuelven b64_json por defecto y
      // rechazan el parámetro con 400 "Unknown parameter: 'response_format'".
      final payload = <String, dynamic>{
        'model': model,
        'prompt': combinedPrompt,
      };
      httpReq.write(jsonEncode(payload));

      final response = await httpReq.close().timeout(timeout);
      final body = await utf8.decodeStream(response).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Error al generar la imagen (${response.statusCode}): $body');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? const [];
      if (data.isEmpty) {
        throw StateError('El servicio de IA devolvió una respuesta de imagen vacía');
      }
      final first = data.first as Map<String, dynamic>;
      final b64 = first['b64_json'] as String? ?? '';
      if (b64.isEmpty) {
        throw StateError('El servicio de IA devolvió una respuesta de imagen vacía');
      }
      return AiImageGenerationResult(bytes: base64Decode(b64), mimeType: 'image/png');
    } finally {
      client.close(force: true);
    }
  }

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

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final client = HttpClient();
    final detachCancel = attachHttpClientCancel(request.cancelToken, client);
    try {
      if (request.cancelToken?.isCancelled == true) {
        throw const AiRequestCancelledException();
      }
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
      final usage = usageRaw is Map
          ? parseOpenAiCompatibleUsageMap(Map<String, dynamic>.from(usageRaw))
          : null;

      return AiCompletionResult(
        text: content,
        provider: providerName,
        model: request.model == 'auto' ? defaultModel : request.model,
        usage: usage,
        toolCalls: toolCalls,
      );
    } catch (e) {
      rethrowUnlessCancelled(request.cancelToken, e);
    } finally {
      detachCancel();
      client.close(force: true);
    }
  }

  /// Streaming real vía SSE (`data: {...}\n\n`, terminado en `data: [DONE]`).
  /// El parseo del wire format vive en `openai_compatible_sse.dart`,
  /// compartido con `LmStudioAiService` (mismo formato OpenAI-compatible).
  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final client = HttpClient();
    final detachCancel = attachHttpClientCancel(request.cancelToken, client);
    try {
      if (request.cancelToken?.isCancelled == true) {
        throw const AiRequestCancelledException();
      }
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

      yield* parseOpenAiCompatibleSseStream(response);
    } catch (e) {
      rethrowUnlessCancelled(request.cancelToken, e);
    } finally {
      detachCancel();
      client.close(force: true);
    }
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
