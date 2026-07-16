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

/// Declaración de una acción que el modelo puede invocar.
class AiToolDefinition {
  const AiToolDefinition({
    required this.name,
    required this.description,
    this.parameters = const [],
  });

  final String name;
  final String description;
  final List<AiToolParam> parameters;

  /// Formato estándar `{type: function, function: {...}}` (OpenAI-compatible;
  /// también válido para Ollama y para el apéndice de emulación JSON).
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
