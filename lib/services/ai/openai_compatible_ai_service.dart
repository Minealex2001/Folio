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

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final client = HttpClient();
    try {
      final endpoint = _buildEndpoint('chat/completions');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
      
      if (apiKey.trim().isNotEmpty) {
        httpReq.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
        httpReq.headers.set('api-key', apiKey.trim());
        httpReq.headers.set('x-goog-api-key', apiKey.trim());
      }

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
                'text': _buildPromptWithTextAttachments(
                  request.prompt,
                  textAttachments,
                ),
              },
              ...imageAttachments.map(
                (a) => {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:${a.mimeType};base64,${a.content.trim()}',
                  },
                },
              ),
            ];

      final payload = <String, dynamic>{
        'model': request.model == 'auto' ? defaultModel : request.model,
        'messages': [
          if ((request.systemPrompt ?? '').trim().isNotEmpty)
            {'role': 'system', 'content': request.systemPrompt!.trim()},
          ...request.messages.map(
            (m) => {'role': m.role, 'content': m.content},
          ),
          {'role': 'user', 'content': userMessageContent},
        ],
      };

      if (request.maxTokens != null) payload['max_tokens'] = request.maxTokens;
      if (request.temperature != null) payload['temperature'] = request.temperature;
      if (request.topP != null) payload['top_p'] = request.topP;
      if (request.stop != null && request.stop!.isNotEmpty) {
        payload['stop'] = request.stop;
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

      httpReq.write(jsonEncode(payload));
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
      if (content.isEmpty) {
        throw StateError('El servicio de IA devolvió una respuesta vacía');
      }

      final usageRaw = json['usage'];
      AiTokenUsage? usage;
      if (usageRaw is Map) {
        final u = Map<String, dynamic>.from(usageRaw);
        int? asInt(dynamic v) {
          if (v is int) return v;
          if (v is num) return v.round();
          return null;
        }
        usage = AiTokenUsage(
          promptTokens: asInt(u['prompt_tokens']),
          completionTokens: asInt(u['completion_tokens']),
          totalTokens: asInt(u['total_tokens']),
        );
      }

      return AiCompletionResult(
        text: content,
        provider: providerName,
        model: request.model == 'auto' ? defaultModel : request.model,
        usage: usage,
      );
    } finally {
      client.close(force: true);
    }
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
