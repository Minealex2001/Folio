import 'ai_types.dart';

abstract class AiService {
  String get providerName;

  Future<AiCompletionResult> complete(AiCompletionRequest request);

  Future<void> ping();

  Future<List<String>> listModels();
}

