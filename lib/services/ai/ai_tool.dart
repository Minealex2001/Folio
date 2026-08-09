/// Definición y ejecución de "tools" (function-calling) para el bucle de agente de Quill.
///
/// Estos tipos son agnósticos de proveedor: no saben nada de `VaultSession`
/// ni de la API concreta de Ollama/OpenAI/etc. `FolioToolRegistry` es quien
/// traduce entre este formato genérico y las mutaciones reales sobre el vault.
library;

/// Un parámetro dentro del schema de argumentos de un [AiToolDefinition].
class AiToolParam {
  const AiToolParam({
    required this.name,
    required this.type,
    required this.description,
    this.required = false,
    this.enumValues,
    this.itemsType,
  });

  final String name;

  /// Tipo JSON Schema: 'string', 'number', 'integer', 'boolean', 'array', 'object'.
  final String type;
  final String description;
  final bool required;

  /// Valores permitidos si el parámetro es un enum de strings.
  final List<String>? enumValues;

  /// Tipo de los elementos si [type] es 'array' (p. ej. 'string').
  final String? itemsType;

  Map<String, dynamic> toJsonSchema() {
    final schema = <String, dynamic>{
      'type': type,
      'description': description,
    };
    if (enumValues != null) schema['enum'] = enumValues;
    if (type == 'array' && itemsType != null) {
      schema['items'] = {'type': itemsType};
    }
    return schema;
  }
}

/// Categoría de una tool — usada solo por UI/metadata interna (Capability
/// Explorer, Tool Inspector), nunca enviada al modelo.
enum AiToolCategory { content, organization, task, media, destructive, experimental }

/// Complejidad relativa de una tool — señal para que la propia IA (o un
/// futuro Tool Inspector) entienda de un vistazo qué tan trivial o delicada
/// es una tool antes de invocarla. No es coste ni tiempo, es "qué tan fácil
/// es de razonar/deshacer".
enum AiToolComplexity { simple, moderate, advanced }

/// Resumen de lo que haría una tool si se ejecutara, sin ejecutarla — el
/// mecanismo de "dry run" de Folio: no un sistema de transacciones aparte,
/// sino una capacidad opcional por-tool (ver [AiToolDefinition.supportsPreview]).
class AiToolPreview {
  const AiToolPreview({required this.summary, this.affectedItems = const []});

  /// Resumen humano, p. ej. "Se eliminarán 3 páginas".
  final String summary;

  /// Elementos concretos afectados, p. ej. títulos de las páginas.
  final List<String> affectedItems;
}

/// Declaración de una acción que el modelo puede invocar.
class AiToolDefinition {
  const AiToolDefinition({
    required this.name,
    required this.description,
    this.parameters = const [],
    this.category = AiToolCategory.content,
    this.complexity = AiToolComplexity.simple,
    this.estimatedDuration,
    this.isReversible = true,
    this.requiresConfirmation = false,
    this.supportsPreview = false,
    this.examples = const [],
  });

  final String name;
  final String description;
  final List<AiToolParam> parameters;

  /// Agrupación temática — usada por el Capability Explorer (B4) y el Tool
  /// Inspector (A6) para iconografía/organización, nunca enviada al modelo.
  final AiToolCategory category;

  /// Qué tan delicada/no-trivial es esta tool.
  final AiToolComplexity complexity;

  /// Estimación aproximada de cuánto tarda en ejecutar — para feedback de
  /// progreso razonable en UI, no una garantía.
  final Duration? estimatedDuration;

  /// Si `false`, esta tool no se puede deshacer una vez ejecutada (p. ej.
  /// borrar permanentemente). Tools estructurales (crear/mover página) hoy
  /// tampoco tienen undo real — ver B3 en el plan — así que también se
  /// marcan `false` aunque técnicamente no sean "destructivas".
  final bool isReversible;

  /// Si `true`, cualquier llamador (chat en-app, MCP externo) debe pedir
  /// confirmación explícita antes de ejecutar — ver
  /// `FolioToolRegistry.onConfirmIrreversibleTool`.
  final bool requiresConfirmation;

  /// Si `true`, `FolioToolRegistry.preview(call)` puede devolver un
  /// [AiToolPreview] no-nulo para esta tool sin mutar el vault.
  final bool supportsPreview;

  /// Ejemplos de uso — para el Capability Explorer y como few-shot opcional
  /// en el futuro. No se envía al modelo por defecto.
  final List<String> examples;

  /// Formato estándar `{type: function, function: {...}}` (OpenAI-compatible;
  /// también válido para Ollama y para el apéndice de emulación JSON).
  /// Deliberadamente NO incluye ningún campo de metadata (categoría,
  /// complejidad, etc.) — eso rompería el schema que ya reciben los modelos.
  Map<String, dynamic> toJsonSchema() {
    final properties = <String, dynamic>{
      for (final p in parameters) p.name: p.toJsonSchema(),
    };
    final required = [
      for (final p in parameters)
        if (p.required) p.name,
    ];
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      },
    };
  }

  /// Metadata interna (Capability Explorer, Tool Inspector) — nunca se envía
  /// al modelo, a diferencia de [toJsonSchema].
  Map<String, dynamic> toMetadataJson() => {
        'name': name,
        'description': description,
        'category': category.name,
        'complexity': complexity.name,
        if (estimatedDuration != null)
          'estimatedDurationMs': estimatedDuration!.inMilliseconds,
        'isReversible': isReversible,
        'requiresConfirmation': requiresConfirmation,
        'supportsPreview': supportsPreview,
        if (examples.isNotEmpty) 'examples': examples,
        'parameters': [
          for (final p in parameters)
            {
              'name': p.name,
              'type': p.type,
              'description': p.description,
              'required': p.required,
              if (p.enumValues != null) 'enum': p.enumValues,
              if (p.itemsType != null) 'itemsType': p.itemsType,
            },
        ],
      };
}

/// Una invocación de tool solicitada por el modelo, ya parseada.
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

/// Resultado de ejecutar un [AiToolCall], listo para realimentar al modelo.
class AiToolResult {
  const AiToolResult({
    required this.toolCallId,
    required this.content,
    this.isError = false,
  });

  factory AiToolResult.ok(String toolCallId, String content) =>
      AiToolResult(toolCallId: toolCallId, content: content);

  factory AiToolResult.error(String toolCallId, String message) =>
      AiToolResult(toolCallId: toolCallId, content: message, isError: true);

  final String toolCallId;

  /// JSON-encoded o texto plano describiendo el resultado (o el error).
  final String content;
  final bool isError;
}
