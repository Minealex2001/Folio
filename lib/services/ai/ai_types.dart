class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.feedback,
  });

  factory AiChatMessage.now({
    required String role,
    required String content,
    String? feedback,
  }) {
    return AiChatMessage(
      role: role,
      content: content,
      timestamp: DateTime.now(),
      feedback: feedback,
    );
  }

  final String role;
  final String content;
  final DateTime timestamp;
  final String? feedback; // null, 'helpful', or 'not_helpful'

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    if (feedback != null) 'feedback': feedback,
  };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      feedback: json['feedback'] as String?,
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
  const AgentChatOutcome({required this.reply, this.usage});

  final String reply;
  final AiTokenUsage? usage;
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
  });

  final String prompt;
  final String model;
  final String? systemPrompt;
  final List<AiChatMessage> messages;
  final List<AiFileAttachment> attachments;
  final int? maxTokens;

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
  });

  final String text;
  final String? provider;
  final String? model;
  final AiTokenUsage? usage;
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
