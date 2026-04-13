import 'dart:convert';
import 'dart:io';

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

  @override
  String get providerName => 'ollama';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final client = HttpClient();
    try {
      final endpoint = baseUrl.resolve('/api/chat');
      final httpReq = await client.postUrl(endpoint).timeout(timeout);
      httpReq.headers.contentType = ContentType.json;
      final mergedPrompt = _buildPrompt(request);
      final imageAttachments = request.attachments
          .where((a) => a.mimeType.startsWith('image/'))
          .toList();
      final payload = <String, dynamic>{
        'model': request.model == 'auto' ? defaultModel : request.model,
        'stream': false,
        'messages': [
          if ((request.systemPrompt ?? '').trim().isNotEmpty)
            {'role': 'system', 'content': request.systemPrompt!.trim()},
          ...request.messages.map(
            (m) => {'role': m.role, 'content': m.content},
          ),
          {
            'role': 'user',
            'content': mergedPrompt,
            if (imageAttachments.isNotEmpty)
              'images': imageAttachments.map((a) => a.content.trim()).toList(),
          },
        ],
      };
      final options = <String, dynamic>{};
      if (request.temperature != null) {
        options['temperature'] = request.temperature;
      }
      if (request.topK != null) {
        options['top_k'] = request.topK;
      }
      if (request.topP != null) {
        options['top_p'] = request.topP;
      }
      if (request.stop != null && request.stop!.isNotEmpty) {
        options['stop'] = request.stop;
      }
      if (request.maxTokens != null) {
        options['num_predict'] = request.maxTokens;
      }
      if (options.isNotEmpty) {
        payload['options'] = options;
      }
      if (request.responseSchema != null) {
        payload['format'] = request.responseSchema;
      }
      httpReq.write(jsonEncode(payload));
      final response = await httpReq.close().timeout(timeout);
      final body = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Ollama respondió ${response.statusCode}: $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg = (json['message'] as Map<String, dynamic>?) ?? const {};
      final content = (msg['content'] as String? ?? '').trim();
      if (content.isEmpty) throw StateError('Ollama devolvió respuesta vacía');
      int? asInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.round();
        return null;
      }

      final promptEval = asInt(json['prompt_eval_count']);
      final evalCount = asInt(json['eval_count']);
      AiTokenUsage? usage;
      if (promptEval != null || evalCount != null) {
        usage = AiTokenUsage(
          promptTokens: promptEval,
          completionTokens: evalCount,
          totalTokens: (promptEval != null && evalCount != null)
              ? promptEval + evalCount
              : null,
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
