import 'dart:convert';

import 'ai_service.dart';
import 'ai_types.dart';

/// Un paso del bucle: una tool invocada por el modelo y el resultado de ejecutarla.
class AiToolLoopStepRecord {
  const AiToolLoopStepRecord({required this.call, required this.result});

  final AiToolCall call;
  final AiToolResult result;
}

enum AiToolLoopEventKind { toolCallStart, toolCallResult }

/// Evento de progreso emitido durante el bucle (vía `onEvent`), pensado para
/// que la UI muestre feedback en vivo ("Quill está creando la página...")
/// sin tener que esperar al `AiToolLoopOutcome` final.
class AiToolLoopEvent {
  AiToolLoopEvent.toolCallStart(this.call)
    : kind = AiToolLoopEventKind.toolCallStart,
      result = null;

  AiToolLoopEvent.toolCallResult(this.call, AiToolResult this.result)
    : kind = AiToolLoopEventKind.toolCallResult;

  final AiToolLoopEventKind kind;
  final AiToolCall call;
  final AiToolResult? result;
}

/// Resultado completo de [runToolLoop]: la respuesta final en texto, el
/// transcript de tools invocadas (para persistir en `AiChatMessage` y para
/// que la UI muestre feedback/errores), y el uso de tokens acumulado de
/// todas las llamadas a `ai.complete()` que hizo el bucle.
class AiToolLoopOutcome {
  const AiToolLoopOutcome({
    required this.finalText,
    required this.steps,
    this.usage,
  });

  final String finalText;
  final List<AiToolLoopStepRecord> steps;
  final AiTokenUsage? usage;

  bool get hasToolCalls => steps.isNotEmpty;

  List<String> get errors => steps
      .where((s) => s.result.isError)
      .map((s) => s.result.content)
      .toList(growable: false);
}

/// Ejecuta un bucle de tool-calling agnóstico de proveedor y de dominio:
///
/// 1. Llama a `ai.complete()` con las `tools` declaradas.
/// 2. Si el modelo pide invocar una o más tools, las ejecuta con
///    [executeTool] y realimenta cada resultado como un mensaje `role: tool`.
/// 3. Repite hasta que el modelo responda solo en texto (sin tool calls) o
///    se alcance [maxSteps].
/// 4. Si se repite la misma tool con los mismos argumentos dos veces
///    seguidas, se fuerza una respuesta final en texto (`toolChoice: none`)
///    en el siguiente turno para cortar el ciclo.
///
/// Sustituye los reintentos manuales que antes vivían hardcodeados dentro de
/// `agentChatWithAi()` (`vault_session_ai.dart`): en vez de re-preguntar al
/// modelo con un prompt de corrección cuando su JSON no cuadra, el modelo
/// simplemente continúa la conversación con el resultado real de cada acción.
Future<AiToolLoopOutcome> runToolLoop({
  required AiService ai,
  required AiCompletionRequest baseRequest,
  required List<AiToolDefinition> tools,
  required Future<AiToolResult> Function(AiToolCall call) executeTool,
  int maxSteps = 6,
  void Function(AiToolLoopEvent event)? onEvent,
  /// Si se pasa, cada turno se pide en streaming (`ai.completeStream`) y se
  /// invoca con el texto acumulado del turno EN CURSO cada vez que llega un
  /// fragmento nuevo, para que la UI pueda mostrarlo en vivo en vez de
  /// esperar al `AiToolLoopOutcome` completo.
  ///
  /// No se puede saber de antemano si un turno terminará pidiendo tool-calls
  /// (esa información solo llega en el chunk final del stream), así que esto
  /// se invoca para TODOS los turnos, no solo el último: en la práctica los
  /// turnos donde el modelo va a invocar tools no suelen traer texto (el
  /// playbook del agente ya le pide usar tools en vez de describirlas), así
  /// que no hay nada que reenviar antes del chunk final. Si un modelo sí
  /// emite un preámbulo de texto antes de invocar una tool, ese texto se verá
  /// brevemente antes de que el turno siguiente lo reemplace — aceptable
  /// frente a duplicar la llamada al modelo solo para evitarlo.
  void Function(String textSoFarThisStep)? onReplyTextDelta,
  AiCancelToken? cancelToken,
}) async {
  final steps = <AiToolLoopStepRecord>[];
  final messages = List<AiChatMessage>.from(baseRequest.messages);
  final effectiveCancel = cancelToken ?? baseRequest.cancelToken;

  void throwIfCancelled() {
    if (effectiveCancel?.isCancelled == true) {
      throw const AiRequestCancelledException();
    }
  }

  int? promptTokens;
  int? completionTokens;
  int? totalTokens;
  var sawUsage = false;
  void accumulateUsage(AiTokenUsage? u) {
    if (u == null) return;
    sawUsage = true;
    promptTokens = (promptTokens ?? 0) + (u.promptTokens ?? 0);
    completionTokens = (completionTokens ?? 0) + (u.completionTokens ?? 0);
    totalTokens = (totalTokens ?? 0) + (u.totalTokens ?? 0);
  }

  AiTokenUsage? finalUsage() => sawUsage
      ? AiTokenUsage(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          totalTokens: totalTokens,
        )
      : null;

  AiCompletionRequest requestFor({
    required bool includeAttachments,
    required bool forceFinalReply,
  }) {
    return AiCompletionRequest(
      prompt: baseRequest.prompt,
      model: baseRequest.model,
      systemPrompt: baseRequest.systemPrompt,
      messages: messages,
      attachments: includeAttachments ? baseRequest.attachments : const [],
      maxTokens: baseRequest.maxTokens,
      temperature: baseRequest.temperature,
      topK: baseRequest.topK,
      topP: baseRequest.topP,
      stop: baseRequest.stop,
      responseSchema: baseRequest.responseSchema,
      cloudInkOperation: baseRequest.cloudInkOperation,
      tools: forceFinalReply ? const [] : tools,
      toolChoice: forceFinalReply ? 'none' : baseRequest.toolChoice,
      cancelToken: effectiveCancel,
    );
  }

  /// Pide un turno y, si hay callback de streaming, lo consume incrementalmente;
  /// si no, cae al `ai.complete()` bloqueante de siempre (comportamiento
  /// idéntico para llamadores que no wireen streaming, p. ej. modo Plan).
  Future<AiCompletionResult> completeStep(AiCompletionRequest request) async {
    throwIfCancelled();
    try {
      if (onReplyTextDelta == null) return await ai.complete(request);
      final buffer = StringBuffer();
      AiTokenUsage? usage;
      List<AiToolCall>? toolCalls;
      await for (final chunk in ai.completeStream(request)) {
        throwIfCancelled();
        if (chunk.textDelta.isNotEmpty) {
          buffer.write(chunk.textDelta);
          onReplyTextDelta(buffer.toString());
        }
        if (chunk.isFinal) {
          usage = chunk.usage;
          toolCalls = chunk.toolCalls;
        }
      }
      throwIfCancelled();
      return AiCompletionResult(
        text: buffer.toString(),
        usage: usage,
        toolCalls: toolCalls,
      );
    } on AiRequestCancelledException {
      rethrow;
    } catch (e) {
      if (effectiveCancel?.isCancelled == true) {
        throw const AiRequestCancelledException();
      }
      rethrow;
    }
  }

  String? lastCallSignature;

  for (var step = 0; step < maxSteps; step++) {
    throwIfCancelled();
    final result = await completeStep(
      requestFor(includeAttachments: step == 0, forceFinalReply: false),
    );
    accumulateUsage(result.usage);

    if (!result.hasToolCalls) {
      return AiToolLoopOutcome(finalText: result.text, steps: steps, usage: finalUsage());
    }

    final calls = result.toolCalls!;
    messages.add(
      AiChatMessage.now(role: 'assistant', content: result.text, toolCalls: calls),
    );

    var repeated = false;
    for (final call in calls) {
      final signature = '${call.name}:${jsonEncode(call.arguments)}';
      if (signature == lastCallSignature) repeated = true;
      lastCallSignature = signature;
    }

    for (final call in calls) {
      throwIfCancelled();
      onEvent?.call(AiToolLoopEvent.toolCallStart(call));
      final toolResult = await executeTool(call);
      throwIfCancelled();
      onEvent?.call(AiToolLoopEvent.toolCallResult(call, toolResult));
      steps.add(AiToolLoopStepRecord(call: call, result: toolResult));
      messages.add(
        AiChatMessage.now(
          role: 'tool',
          content: toolResult.content,
          toolCallId: toolResult.toolCallId,
        ),
      );
    }

    if (repeated) {
      final closing = await completeStep(
        requestFor(includeAttachments: false, forceFinalReply: true),
      );
      accumulateUsage(closing.usage);
      return AiToolLoopOutcome(finalText: closing.text, steps: steps, usage: finalUsage());
    }
  }

  // Se alcanzó maxSteps sin que el modelo cerrara con texto: se le fuerza una
  // última respuesta sin tools disponibles para no dejar al usuario sin reply.
  final closing = await completeStep(
    requestFor(includeAttachments: false, forceFinalReply: true),
  );
  accumulateUsage(closing.usage);
  return AiToolLoopOutcome(finalText: closing.text, steps: steps, usage: finalUsage());
}
