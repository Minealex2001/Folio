import '../services/ai/ai_tool.dart';

/// Fase C1 del plan Quill/MCP — enrutamiento por tipo de tarea, ampliado de
/// "solo modelo" a un perfil completo (modelo, temperatura, alcance de
/// contexto, categorías de tools disponibles, timeout).
///
/// **Hallazgo verificado antes de construir esto** (leyendo
/// `FolioBackend/src/main/java/com/folio/backend/ai/HttpOpenAiClient.java`,
/// método `resolvedModel()`): el backend ignora por completo el campo
/// `model` que envía el cliente (hoy siempre `'auto'`, ver
/// `_classifyBestPromptId` en `workspace_page_ai_chat.dart`) — usa un único
/// modelo fijo configurado por el admin (`AppSettingKey.OPENAI_MODEL`) para
/// TODAS las peticiones, sin importar `operationKind` ni nada más. Enrutar
/// modelo desde el cliente no tendría ningún efecto real hoy sin cambios en
/// el backend (fuera de alcance de este plan) — por eso [model] existe en
/// el perfil (para cuando el backend sí lo respete) pero es un campo inerte
/// en la práctica actual. Lo que SÍ es enteramente decisión de cliente y sí
/// tiene efecto real: [temperature], [allowedToolCategories] (qué tools se
/// ofrecen al modelo) y [timeoutMs].
class ExecutionProfile {
  const ExecutionProfile({
    required this.id,
    required this.name,
    this.model = 'auto',
    required this.temperature,
    this.allowedToolCategories,
    required this.timeoutMs,
    required this.contextScopeMaxPages,
  });

  final String id;
  final String name;

  /// Inerte hoy (ver doc de la clase) — se conserva para cuando el backend
  /// respete un modelo por-request.
  final String model;

  final double temperature;

  /// `null` = todas las categorías disponibles (comportamiento actual, sin
  /// filtrar). Si no es null, solo las tools de esas categorías se ofrecen
  /// al modelo — un perfil de "resumen rápido" no necesita el catálogo
  /// completo de ~27 tools.
  final List<AiToolCategory>? allowedToolCategories;

  final int timeoutMs;

  /// Máximo de páginas de referencia a incluir como contexto.
  final int contextScopeMaxPages;

  /// Filtra [definitions] a las permitidas por este perfil — `null` en
  /// [allowedToolCategories] es un no-op (devuelve la lista tal cual).
  List<AiToolDefinition> filterTools(List<AiToolDefinition> definitions) {
    final allowed = allowedToolCategories;
    if (allowed == null) return definitions;
    return definitions.where((d) => allowed.contains(d.category)).toList();
  }
}

/// Perfil para respuestas cortas y directas (resumir, explicar, traducir un
/// fragmento) — sin tools (no necesita crear/mover páginas), temperatura
/// baja, contexto mínimo, timeout corto.
const kExecutionProfileQuickAnswer = ExecutionProfile(
  id: 'quick_answer',
  name: 'Respuesta rápida',
  temperature: 0.3,
  allowedToolCategories: [],
  timeoutMs: 15000,
  contextScopeMaxPages: 1,
);

/// Perfil para investigación/creación de contenido sustancial (crear
/// páginas, generar documentación) — todas las tools, contexto amplio,
/// timeout largo.
const kExecutionProfileDeepResearch = ExecutionProfile(
  id: 'deep_research',
  name: 'Investigación profunda',
  temperature: 0.7,
  allowedToolCategories: null,
  timeoutMs: 60000,
  contextScopeMaxPages: 5,
);

/// Perfil para tareas de código — temperatura baja (determinismo), tools de
/// contenido/tarea (no necesita explorar/organizar la libreta entera).
const kExecutionProfileCodeTask = ExecutionProfile(
  id: 'code_task',
  name: 'Tarea de código',
  temperature: 0.2,
  allowedToolCategories: [AiToolCategory.content, AiToolCategory.task],
  timeoutMs: 30000,
  contextScopeMaxPages: 2,
);

const List<ExecutionProfile> kBuiltinExecutionProfiles = [
  kExecutionProfileQuickAnswer,
  kExecutionProfileDeepResearch,
  kExecutionProfileCodeTask,
];

/// Heurística determinista y barata (sin llamada a IA) para elegir un
/// perfil a partir del texto del prompt del usuario — deliberadamente
/// simple (palabras clave), no un clasificador. Devuelve `deepResearch`
/// como default razonable cuando nada más específico coincide, en vez de
/// forzar el perfil más restrictivo por defecto.
///
/// **Nota de alcance**: esta función es un bloque de construcción puro y
/// testeado; conectarla al envío real del chat (`_runAiFromChat`) queda
/// deliberadamente fuera de esta fase — cambiar automáticamente qué tools
/// ve el modelo o el timeout a mitad de una conversación merece su propio
/// diseño de transparencia (que el usuario vea qué perfil se está usando y
/// por qué, coherente con la disciplina de "nunca invasivo" del resto de la
/// app), no una activación silenciosa añadida al final de este plan.
ExecutionProfile resolveExecutionProfileForPrompt(String prompt) {
  final normalized = prompt.trim().toLowerCase();
  if (normalized.isEmpty) return kExecutionProfileDeepResearch;

  const codeKeywords = [
    'código', 'code', 'función', 'function', 'bug', 'error de compil',
    'refactor', 'clase ', 'class ', 'método', 'method', 'script',
  ];
  if (codeKeywords.any(normalized.contains)) {
    return kExecutionProfileCodeTask;
  }

  const quickKeywords = [
    'resume', 'summarize', 'explica brevemente', 'traduce', 'translate',
    'en una frase', 'en pocas palabras', 'corrige', 'mejora la redacción',
  ];
  final isShort = normalized.length < 80;
  if (isShort && quickKeywords.any(normalized.contains)) {
    return kExecutionProfileQuickAnswer;
  }

  return kExecutionProfileDeepResearch;
}
