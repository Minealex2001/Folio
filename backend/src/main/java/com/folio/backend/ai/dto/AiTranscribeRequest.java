package com.folio.backend.ai.dto;

public record AiTranscribeRequest(
    String audioBase64, String language, Boolean chargeInk, Double inkAmount) {}
