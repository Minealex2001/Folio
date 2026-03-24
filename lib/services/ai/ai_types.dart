class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
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

/// Uso de tokens devuelto por el backend (Ollama / OpenAI-compatible).
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
  });

  final String prompt;
  final String model;
  final String? systemPrompt;
  final List<AiChatMessage> messages;
  final List<AiFileAttachment> attachments;
  final int? maxTokens;
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
  });

  final String id;
  final String title;
  final List<AiChatMessage> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory AiChatThreadData.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? const [];
    return AiChatThreadData(
      id: json['id'] as String? ?? 'chat_0',
      title: json['title'] as String? ?? 'Chat',
      messages: rawMessages
          .whereType<Map>()
          .map((m) => AiChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}
