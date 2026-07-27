package com.folio.backend.ai;

import java.util.List;
import java.util.Map;

public interface OpenAiClient {

  ChatResult chatCompletion(ChatRequest request);

  TranscribeResult transcribe(byte[] audioWav, String languageOrEmpty);

  record ChatMessage(String role, String content, List<ToolCall> toolCalls, String toolCallId) {}

  record ToolCall(String id, String name, String arguments) {}

  record ChatRequest(
      String systemPrompt,
      String prompt,
      List<ChatMessage> messages,
      Map<String, Object> responseSchema,
      Integer maxTokens,
      Double temperature,
      List<Map<String, Object>> tools,
      String toolChoice) {}

  record ChatResult(String text, Integer totalTokenCount, List<ToolCall> toolCalls) {}

  record TranscribeResult(String transcript) {}
}
