package com.folio.backend.ai.dto;

import java.util.List;
import java.util.Map;

public record AiCompleteResponse(
    String text,
    List<Map<String, Object>> toolCalls,
    AiInkDto ink,
    int inkCharged,
    int inkBaseCharged,
    int inkTokenSurcharge) {}
