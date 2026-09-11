import 'ai_service.dart';
import 'ai_types.dart';

/// Envuelve un [AiService] para inyectar [cancelToken] en cada request.
///
/// Útil en el camino legado de `agentChatWithAi` (sin tool-calling), donde hay
/// muchas construcciones de [AiCompletionRequest] y no conviene tocarlas una
/// a una.
class AiServiceWithCancelToken implements AiService {
  AiServiceWithCancelToken(this._inner, this.cancelToken);

  final AiService _inner;
  final AiCancelToken cancelToken;

  @override
  String get providerName => _inner.providerName;

  @override
  bool get supportsNativeToolCalling => _inner.supportsNativeToolCalling;

  @override
  bool get supportsImageGeneration => _inner.supportsImageGeneration;

  AiCompletionRequest _inject(AiCompletionRequest request) {
    if (identical(request.cancelToken, cancelToken)) return request;
    return AiCompletionRequest(
      prompt: request.prompt,
      model: request.model,
      systemPrompt: request.systemPrompt,
      messages: request.messages,
      attachments: request.attachments,
      maxTokens: request.maxTokens,
      temperature: request.temperature,
      topK: request.topK,
      topP: request.topP,
      stop: request.stop,
      responseSchema: request.responseSchema,
      cloudInkOperation: request.cloudInkOperation,
      tools: request.tools,
      toolChoice: request.toolChoice,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) {
    if (cancelToken.isCancelled) {
      return Future.error(const AiRequestCancelledException());
    }
    return _inner.complete(_inject(request)).catchError((Object e) {
      if (cancelToken.isCancelled) {
        throw const AiRequestCancelledException();
      }
      throw e;
    });
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    if (cancelToken.isCancelled) {
      throw const AiRequestCancelledException();
    }
    try {
      yield* _inner.completeStream(_inject(request));
    } catch (e) {
      if (cancelToken.isCancelled) {
        throw const AiRequestCancelledException();
      }
      rethrow;
    }
  }

  @override
  Future<void> ping() => _inner.ping();

  @override
  Future<List<String>> listModels() => _inner.listModels();

  @override
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  }) {
    return _inner.generateImage(
      prompt: prompt,
      pageContextText: pageContextText,
    );
  }
}
