package com.folio.backend.ai.dto;

import java.util.List;
import java.util.Map;

public record AiCompleteRequest(
    String prompt,
    String systemPrompt,
    List<Map<String, Object>> messages,
    Map<String, Object> responseSchema,
    Integer maxTokens,
    Double temperature,
    List<Map<String, Object>> tools,
    String toolChoice,
    String operationKind) {}
