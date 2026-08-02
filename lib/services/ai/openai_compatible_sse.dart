import 'dart:convert';
import 'dart:io';

import 'ai_types.dart';

/// Parsea un stream SSE de Chat Completions estilo OpenAI
/// (`data: {...}\n\n`, terminado en `data: [DONE]`) en [AiCompletionChunk]s.
/// Compartido por los proveedores que hablan el mismo formato de wire
/// (OpenAI-compatible BYOK y LM Studio) para no duplicar el parseo. Los
/// deltas de tool-calls llegan troceados por índice
/// (`delta.tool_calls[].index`) y se reensamblan al recibir `[DONE]`.
Stream<AiCompletionChunk> parseOpenAiCompatibleSseStream(
  HttpClientResponse response,
) async* {
  final toolCallIdByIndex = <int, String>{};
  final toolCallNameByIndex = <int, String>{};
  final toolCallArgsByIndex = <int, StringBuffer>{};
  AiTokenUsage? finalUsage;

  final lines = response.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
    final data = trimmed.substring(5).trim();
    if (data == '[DONE]') {
      final toolCalls = toolCallArgsByIndex.isEmpty && toolCallNameByIndex.isEmpty
          ? null
          : [
              for (final index in {...toolCallIdByIndex.keys, ...toolCallNameByIndex.keys})
                AiToolCall(
                  id: toolCallIdByIndex[index] ?? 'stream_$index',
                  name: toolCallNameByIndex[index] ?? '',
                  arguments: _tryDecodeSseToolArgs(toolCallArgsByIndex[index]?.toString()),
                ),
            ];
      yield AiCompletionChunk(isFinal: true, usage: finalUsage, toolCalls: toolCalls);
      return;
    }

    Map<String, dynamic> event;
    try {
      event = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }

    final usageRaw = event['usage'];
    if (usageRaw is Map) {
      finalUsage = parseOpenAiCompatibleUsageMap(Map<String, dynamic>.from(usageRaw));
    }

    final choices = event['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) continue;
    final delta = (choices.first as Map<String, dynamic>)['delta'] as Map<String, dynamic>? ?? const {};

    final textDelta = delta['content'] as String? ?? '';
    if (textDelta.isNotEmpty) yield AiCompletionChunk(textDelta: textDelta);

    final rawToolCallDeltas = delta['tool_calls'];
    if (rawToolCallDeltas is List) {
      for (final rawDelta in rawToolCallDeltas) {
        if (rawDelta is! Map) continue;
        final index = (rawDelta['index'] as num?)?.toInt() ?? 0;
        final id = rawDelta['id'] as String?;
        if (id != null && id.isNotEmpty) toolCallIdByIndex[index] = id;
        final fn = rawDelta['function'] as Map?;
        if (fn != null) {
          final name = fn['name'] as String?;
          if (name != null && name.isNotEmpty) toolCallNameByIndex[index] = name;
          final argsChunk = fn['arguments'] as String?;
          if (argsChunk != null) {
            (toolCallArgsByIndex[index] ??= StringBuffer()).write(argsChunk);
          }
        }
      }
    }
  }
}

Map<String, dynamic> _tryDecodeSseToolArgs(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Argumentos incompletos/no-JSON tras reensamblar los deltas.
  }
  return const {};
}

/// Parsea el objeto `usage` estilo OpenAI (`prompt_tokens`/`completion_tokens`/
/// `total_tokens`), compartido por las respuestas en streaming y no-streaming.
AiTokenUsage? parseOpenAiCompatibleUsageMap(Map<String, dynamic> u) {
  int? asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return null;
  }

  return AiTokenUsage(
    promptTokens: asInt(u['prompt_tokens']),
    completionTokens: asInt(u['completion_tokens']),
    totalTokens: asInt(u['total_tokens']),
  );
}
