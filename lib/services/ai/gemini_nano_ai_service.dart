import 'ai_service.dart';
import 'ai_types.dart';
import 'on_device_ai_bridge.dart';

/// Quill on-device vía Gemini Nano (AICore / ML Kit GenAI Prompt).
///
/// Sin tool-calling nativo: el llamador debe usar la emulación JSON.
class GeminiNanoAiService implements AiService {
  GeminiNanoAiService({
    this.timeout = const Duration(seconds: 60),
    this.maxPromptChars = 12000,
    this.maxHistoryMessages = 12,
  });

  final Duration timeout;
  final int maxPromptChars;
  final int maxHistoryMessages;

  static const modelId = 'gemini-nano';

  @override
  String get providerName => 'geminiNano';

  @override
  bool get supportsNativeToolCalling => false;

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    final prompt = _buildPrompt(request);
    final text = await OnDeviceAiBridge.generateContent(prompt).timeout(timeout);
    return AiCompletionResult(
      text: text,
      provider: providerName,
      model: modelId,
    );
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final result = await complete(request);
    yield AiCompletionChunk(
      textDelta: result.text,
      isFinal: true,
      usage: result.usage,
      toolCalls: result.toolCalls,
    );
  }

  @override
  Future<void> ping() => OnDeviceAiBridge.ping().timeout(timeout);

  @override
  Future<List<String>> listModels() async => const [modelId];

  String _buildPrompt(AiCompletionRequest request) {
    // El system prompt y la pregunta actual del usuario van en `head` y se
    // preservan siempre que quepan solos en el presupuesto; los adjuntos son
    // lo único que se recorta cuando no hay espacio. Si se recortara el
    // resultado final completo (system+historial+pregunta+adjuntos) por el
    // principio como antes, un adjunto largo podía desplazar fuera del
    // presupuesto tanto el system prompt como la propia pregunta, dejando a
    // Gemini Nano respondiendo solo al texto sobrante de un adjunto.
    final headBuf = StringBuffer();
    final system = request.systemPrompt?.trim();
    if (system != null && system.isNotEmpty) {
      headBuf.writeln('System:');
      headBuf.writeln(system);
      headBuf.writeln();
    }

    final messages = request.messages;
    final start = messages.length > maxHistoryMessages
        ? messages.length - maxHistoryMessages
        : 0;
    for (var i = start; i < messages.length; i++) {
      final m = messages[i];
      final role = switch (m.role) {
        'system' => 'System',
        'user' => 'User',
        'assistant' => 'Assistant',
        'tool' => 'Tool',
        _ => m.role,
      };
      final content = m.content.trim();
      if (content.isEmpty) continue;
      headBuf.writeln('$role:');
      headBuf.writeln(content);
      headBuf.writeln();
    }

    final prompt = request.prompt.trim();
    if (prompt.isNotEmpty) {
      // Evita duplicar el último mensaje de usuario si ya está en messages.
      final lastUser = messages.isNotEmpty && messages.last.role == 'user'
          ? messages.last.content.trim()
          : '';
      if (prompt != lastUser) {
        headBuf.writeln('User:');
        headBuf.writeln(prompt);
        headBuf.writeln();
      }
    }

    final head = headBuf.toString();
    if (head.length >= maxPromptChars) {
      // Ni siquiera system+historial+pregunta caben: último recurso, igual
      // que antes, conservar el final (la pregunta más reciente).
      return head.substring(head.length - maxPromptChars).trim();
    }

    final attachmentsBuf = StringBuffer();
    if (request.attachments.isNotEmpty) {
      attachmentsBuf.writeln('Attachments:');
      for (final a in request.attachments) {
        final mime = a.mimeType.toLowerCase();
        if (mime.startsWith('text/') ||
            mime.contains('json') ||
            mime.contains('markdown')) {
          attachmentsBuf.writeln('--- ${a.name} (${a.mimeType}) ---');
          attachmentsBuf.writeln(a.content);
          attachmentsBuf.writeln();
        } else {
          attachmentsBuf.writeln('[${a.name} (${a.mimeType}) omitted on-device]');
        }
      }
    }

    final attachments = attachmentsBuf.toString();
    final attachmentsBudget = maxPromptChars - head.length;
    final out = attachmentsBudget > 0
        ? head + attachments.substring(0, attachments.length.clamp(0, attachmentsBudget))
        : head;
    return out.trim();
  }
}
