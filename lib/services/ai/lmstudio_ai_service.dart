import 'dart:convert';
import 'dart:io';

import 'ai_service.dart';
import 'ai_types.dart';

class LmStudioAiService implements AiService {
  LmStudioAiService({
    required this.baseUrl,
    required this.timeout,
    required this.defaultModel,
  });

  final Uri baseUrl;
  final Duration timeout;
  final String defaultModel;

  @override
  String get providerName => 'lmstudio';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final client = HttpClient();
    try {
      final endpoint = baseUrl.resolve('/v1/chat/completions');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
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
      if (request.maxTokens != null) {
        payload['max_tokens'] = request.maxTokens;
      }
      if (request.temperature != null) {
        payload['temperature'] = request.temperature;
      }
      if (request.topK != null) {
        payload['top_k'] = request.topK;
      }
      if (request.topP != null) {
        payload['top_p'] = request.topP;
      }
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
        throw StateError('LM Studio respondió ${response.statusCode}: $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        throw StateError('LM Studio devolvió respuesta vacía');
      }
      final first = choices.first as Map<String, dynamic>;
      final msg = (first['message'] as Map<String, dynamic>?) ?? const {};
      final content = (msg['content'] as String? ?? '').trim();
      if (content.isEmpty) {
        throw StateError('LM Studio devolvió respuesta vacía');
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
      final req = await client
          .getUrl(baseUrl.resolve('/v1/models'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('LM Studio no disponible (${res.statusCode})');
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
          .getUrl(baseUrl.resolve('/v1/models'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      final body = await utf8.decodeStream(res).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('LM Studio no disponible (${res.statusCode})');
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
