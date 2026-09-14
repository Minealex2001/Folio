import 'ai_types.dart';

/// Fase 7 de Quill 2.0 — substrings de nombres de modelo conocidos por
/// soportar entradas de visión (imágenes), usados por los providers cuyo
/// modelo el usuario configura libremente (Ollama, LM Studio,
/// OpenAI-compatible) para derivar [AiService.supportsVision] sin una
/// bandera de capacidad real del proveedor — mismo patrón y misma
/// limitación ya aceptada para `supportsNativeToolCalling` en
/// `ollama_ai_service.dart`: es una heurística estática sobre el modelo
/// configurado por defecto, no una comprobación en vivo. Un falso negativo
/// solo evita mandar imágenes a un modelo que quizá sí las soportaría
/// (degradación segura); un falso positivo manda una imagen que el modelo
/// puede ignorar o rechazar (sin peor riesgo que el ya asumido por la
/// heurística de tool-calling).
const List<String> kVisionCapableModelSubstrings = [
  'gpt-4o',
  'gpt-4-vision',
  'gpt-4-turbo',
  'gpt-5',
  'o1',
  'o3',
  'o4',
  'gemini',
  'llava',
  'bakllava',
  'moondream',
  'llama3.2-vision',
  'qwen2-vl',
  'qwen2.5-vl',
  'minicpm-v',
  'pixtral',
  'phi-3.5-vision',
  'phi-4',
];

bool modelNameLooksVisionCapable(String model) {
  final m = model.toLowerCase();
  return kVisionCapableModelSubstrings.any(m.contains);
}

/// Fase 7.5 de Quill 2.0 — la familia `gpt-image-*` rechaza el parámetro
/// `response_format` en `/images/generations` (siempre devuelve `b64_json`);
/// cualquier otro modelo de imagen (p. ej. `dall-e-2`/`dall-e-3`) sí lo
/// admite y por defecto devuelve `url` si no se pide explícitamente. Se usa
/// para decidir si mandar `response_format: 'b64_json'` en el request —
/// mismo criterio en el cliente Flutter y en FolioBackend.
bool isGptImageModel(String model) => model.trim().toLowerCase().startsWith('gpt-image');

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

  /// Si `false`, este proveedor/modelo no debe recibir adjuntos de imagen
  /// (`AiFileAttachment` con `mimeType` `image/*`) en [AiCompletionRequest]
  /// — el llamador debe omitirlos en vez de mandarlos para que se pierdan o
  /// causen un error del proveedor. Ver `kVisionCapableModelSubstrings` para
  /// la limitación de esta bandera en providers de modelo configurable.
  bool get supportsVision;

  /// Genera una imagen a partir de [prompt] (y opcionalmente [pageContextText],
  /// ya truncado por el llamador). Lanza [AiImageGenerationUnsupportedException]
  /// si [supportsImageGeneration] es `false`.
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  });
}
