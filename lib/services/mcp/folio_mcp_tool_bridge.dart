import '../ai/ai_tool.dart';

/// Traduce entre el formato de tool OpenAI-style que ya usa
/// `FolioToolRegistry`/`AiToolDefinition` (`{type: function, function: {...}}`)
/// y el formato de tool que espera el protocolo MCP
/// (`{name, description, inputSchema}`, sin el envoltorio `function`).
///
/// Es una capa de adaptación fina: no reimplementa el catálogo de acciones,
/// solo cambia la forma del JSON.
Map<String, dynamic> aiToolDefinitionToMcpTool(AiToolDefinition tool) {
  final schema = tool.toJsonSchema();
  final fn = schema['function'] as Map<String, dynamic>;
  return {
    'name': fn['name'],
    'description': fn['description'],
    'inputSchema': fn['parameters'],
  };
}

/// Codifica el resultado de una tool ([AiToolResult]) en el formato de
/// contenido de MCP (`content: [{type: "text", text: "..."}]`, `isError`).
Map<String, dynamic> aiToolResultToMcpContent(AiToolResult result) {
  return {
    'content': [
      {'type': 'text', 'text': result.content},
    ],
    'isError': result.isError,
  };
}
