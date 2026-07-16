import 'ai_tool.dart';

export 'ai_tool.dart';

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.feedback,
    this.agentApplySnapshot,
    this.toolCalls,
    this.toolCallId,
    this.toolErrors,
  });

  factory AiChatMessage.now({
    required String role,
    required String content,
    String? feedback,
    Map<String, dynamic>? agentApplySnapshot,
    List<AiToolCall>? toolCalls,
    String? toolCallId,
    List<String>? toolErrors,
  }) {
    return AiChatMessage(
      role: role,
      content: content,
      timestamp: DateTime.now(),
      feedback: feedback,
      agentApplySnapshot: agentApplySnapshot,
      toolCalls: toolCalls,
      toolCallId: toolCallId,
      toolErrors: toolErrors,
    );
  }

  final String role;
  final String content;
  final DateTime timestamp;
  final String? feedback; // null, 'helpful', or 'not_helpful'

  /// Si el agente respondió en modo `chat` pero incluyó `blocks` u `operations` en JSON,
  /// la UI puede ofrecer aplicarlos manualmente a la página abierta.
  final Map<String, dynamic>? agentApplySnapshot;

  /// Tool calls emitidas por el modelo en este mensaje (role 'assistant').
  /// Nulo en mensajes que no invocan ningún tool, y en todos los hilos
  /// guardados antes de la introducción del bucle de tool-calling.
  final List<AiToolCall>? toolCalls;

  /// Si `role == 'tool'`, el id de la [AiToolCall] cuyo resultado transporta este mensaje.
  final String? toolCallId;

  /// Mensajes de error de tool-calls fallidas durante este turno, para mostrar
  /// como chips distintos de la respuesta en texto. Nulo si no hubo errores.
  final List<String>? toolErrors;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    if (feedback != null) 'feedback': feedback,
    if (agentApplySnapshot != null) 'agentApplySnapshot': agentApplySnapshot,
    if (toolCalls != null)
      'toolCalls': toolCalls!
          .map((c) => {'id': c.id, 'name': c.name, 'arguments': c.arguments})
          .toList(),
    if (toolCallId != null) 'toolCallId': toolCallId,
    if (toolErrors != null) 'toolErrors': toolErrors,
  };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    final snap = json['agentApplySnapshot'];
    Map<String, dynamic>? snapMap;
    if (snap is Map) {
      snapMap = Map<String, dynamic>.from(
        snap.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    final rawToolCalls = json['toolCalls'];
    List<AiToolCall>? toolCalls;
    if (rawToolCalls is List) {
      toolCalls = rawToolCalls
          .whereType<Map>()
          .map(
            (m) => AiToolCall(
              id: m['id'] as String? ?? '',
              name: m['name'] as String? ?? '',
              arguments: m['arguments'] is Map
                  ? Map<String, dynamic>.from(m['arguments'] as Map)
                  : const {},
            ),
          )
          .toList();
    }
    final rawToolErrors = json['toolErrors'];
    List<String>? toolErrors;
    if (rawToolErrors is List) {
      toolErrors = rawToolErrors.map((e) => '$e').toList();
    }
    return AiChatMessage(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      feedback: json['feedback'] as String?,
      agentApplySnapshot: snapMap,
      toolCalls: toolCalls,
      toolCallId: json['toolCallId'] as String?,
      toolErrors: toolErrors,
    );
  }
}

class AiFileAttachment {
  const AiFileAttachment({
    required this.name,
    required this.mimeType,
    required this.content,
  });

  final String name;
  final String mimeType;
  final String content;
}

/// Uso de tokens devuelto por el backend (Ollama local o inferencia Quill Cloud).
class AiTokenUsage {
  const AiTokenUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
}

/// El servicio IA no respondió en el endpoint configurado (red, apagado, etc.).
class AiServiceUnreachableException implements Exception {
  AiServiceUnreachableException([this.cause]);

  final Object? cause;

  @override
  String toString() =>
      'AiServiceUnreachableException${cause != null ? ': $cause' : ''}';
}

/// Resultado del chat con agente para la UI (texto mostrado + métricas del último `complete`).
class AgentChatOutcome {
  const AgentChatOutcome({
    required this.reply,
    this.usage,
    this.agentApplySnapshot,
    this.toolCalls,
    this.toolErrors,
  });

  final String reply;
  final AiTokenUsage? usage;

  /// Solo en modo `chat` con `blocks` u `operations` no auto-aplicadas.
  final Map<String, dynamic>? agentApplySnapshot;

  /// Solo con el bucle de tool-calling (Fase 1): tools que el modelo invocó
  /// en este turno, para persistir en el `AiChatMessage` resultante.
  final List<AiToolCall>? toolCalls;

  /// Mensajes de error de tool-calls fallidas en este turno, para que la UI
  /// los muestre como chip distinto de `reply` en vez de mezclados en el texto.
  final List<String>? toolErrors;
}

/// Acción manual sobre un [AgentChatOutcome.agentApplySnapshot] guardado en el mensaje.
enum AiAgentApplyKind {
  insertBlocksAtEnd,
  replaceAllBlocks,
  applyEditOperations,
}

class AiCompletionRequest {
  const AiCompletionRequest({
    required this.prompt,
    required this.model,
    this.systemPrompt,
    this.messages = const [],
    this.attachments = const [],
    this.maxTokens,
    this.temperature,
    this.topK,
    this.topP,
    this.stop,
    this.responseSchema,
    /// Solo [FolioCloudAiService]: tipo de operación para cobrar tinta en servidor (`operationKind`).
    this.cloudInkOperation,
    this.tools = const [],
    this.toolChoice,
  });

  final String prompt;
  final String model;
  final String? systemPrompt;
  final List<AiChatMessage> messages;
  final List<AiFileAttachment> attachments;
  final int? maxTokens;

  /// Tools disponibles para que el modelo invoque en este turno. Vacío = sin tool-calling.
  final List<AiToolDefinition> tools;

  /// 'auto' (por defecto si hay tools), 'none', o 'required'.
  final String? toolChoice;

  /// Temperatura de sampling [0,1]. 0 = determinista.
  final double? temperature;

  /// Top-K tokens candidatos.
  final int? topK;

  /// Probabilidad acumulada mínima para top-p sampling.
  final double? topP;

  /// Secuencias de parada.
  final List<String>? stop;

  /// JSON Schema para forzar salida estructurada (LM Studio: response_format; Ollama: format).
  final Map<String, dynamic>? responseSchema;

  /// Valores alineados con `INK_COST_BY_OPERATION` en Cloud Functions.
  final String? cloudInkOperation;
}

class AiCompletionResult {
  const AiCompletionResult({
    required this.text,
    this.provider,
    this.model,
    this.usage,
    this.toolCalls,
  });

  final String text;
  final String? provider;
  final String? model;
  final AiTokenUsage? usage;

  /// No nulo/no vacío cuando el modelo pidió invocar uno o más tools en vez de
  /// (o además de) responder en texto. [text] puede estar vacío en ese caso.
  final List<AiToolCall>? toolCalls;

  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
}

/// Un fragmento incremental de [AiService.completeStream]. `textDelta` es el
/// texto nuevo desde el último chunk (no acumulado). El último chunk del
/// turno lleva `isFinal: true` junto con `usage` y `toolCalls` ya
/// reensambladas (mismo formato que [AiCompletionResult.toolCalls]) — los
/// chunks intermedios solo traen `textDelta`.
class AiCompletionChunk {
  const AiCompletionChunk({
    this.textDelta = '',
    this.isFinal = false,
    this.usage,
    this.toolCalls,
  });

  final String textDelta;
  final bool isFinal;
  final AiTokenUsage? usage;
  final List<AiToolCall>? toolCalls;

  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
}

class AiChatThreadData {
  const AiChatThreadData({
    required this.id,
    required this.title,
    required this.messages,
    this.attachmentPaths = const [],
    this.includePageContext = true,
    this.contextPageIds = const [],
  });

  final String id;
  final String title;
  final List<AiChatMessage> messages;

  /// Rutas locales de archivos adjuntos al contexto de este hilo (persisten con la libreta).
  final List<String> attachmentPaths;

  /// Si es false, no se envía texto ni bloques de páginas al modelo (solo chat general).
  final bool includePageContext;

  /// Páginas cuyo texto entra en el contexto. Vacío = al enviar se usa la página abierta.
  final List<String> contextPageIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    if (attachmentPaths.isNotEmpty) 'attachmentPaths': attachmentPaths,
    'includePageContext': includePageContext,
    'contextPageIds': contextPageIds,
  };

  factory AiChatThreadData.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? const [];
    final rawAtt = json['attachmentPaths'] as List<dynamic>? ?? const [];
    final rawCtx = json['contextPageIds'] as List<dynamic>? ?? const [];
    return AiChatThreadData(
      id: json['id'] as String? ?? 'chat_0',
      title: json['title'] as String? ?? 'Chat',
      messages: rawMessages
          .whereType<Map>()
          .map((m) => AiChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      attachmentPaths: rawAtt.map((e) => '$e').toList(),
      includePageContext: json['includePageContext'] as bool? ?? true,
      contextPageIds: rawCtx.map((e) => '$e').toList(),
    );
  }
}
