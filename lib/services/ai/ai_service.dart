import 'ai_types.dart';

abstract class AiService {
  String get providerName;

  /// Si `false`, este proveedor/modelo no soporta de forma fiable el `tools`
  /// nativo de [AiCompletionRequest]; el llamador debe usar la emulación JSON
  /// (`ai_tool_json_emulation.dart`) en vez de confiar en `AiCompletionResult.toolCalls`.
  bool get supportsNativeToolCalling => false;

  /// Si `request.tools` no está vacío y [supportsNativeToolCalling] es `true`,
  /// el resultado puede traer `toolCalls` en vez de (o además de) `text`.
  Future<AiCompletionResult> complete(AiCompletionRequest request);

  /// Variante en streaming de [complete]. Implementaciones sin streaming
  /// real deben devolver un único chunk final equivalente a `complete()` —
  /// no hay una implementación por defecto heredable porque los servicios
  /// usan `implements AiService`, no `extends` (ver cada `*_ai_service.dart`).
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request);

  Future<void> ping();

  Future<List<String>> listModels();

  /// Si `false`, [generateImage] no está soportado por este proveedor/modelo
  /// y no debe llamarse (la UI debe deshabilitar/ocultar la acción en su lugar).
  bool get supportsImageGeneration;

  /// Genera una imagen a partir de [prompt] (y opcionalmente [pageContextText],
  /// ya truncado por el llamador). Lanza [AiImageGenerationUnsupportedException]
  /// si [supportsImageGeneration] es `false`.
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  });
}
