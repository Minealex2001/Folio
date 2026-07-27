package com.folio.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.openai")
public record OpenAiProperties(
    String apiKey,
    String baseUrl,
    String model,
    String transcribeModel,
    int maxOutputTokens,
    double temperature) {

  public OpenAiProperties {
    if (baseUrl == null || baseUrl.isBlank()) {
      baseUrl = "https://api.openai.com/v1";
    }
    baseUrl = baseUrl.replaceAll("/+$", "");
    if (model == null || model.isBlank()) {
      model = "gpt-5.4-mini-2026-03-17";
    }
    if (transcribeModel == null || transcribeModel.isBlank()) {
      transcribeModel = "gpt-4o-transcribe";
    }
    if (maxOutputTokens < 1) {
      maxOutputTokens = 8192;
    }
    maxOutputTokens = Math.min(16384, maxOutputTokens);
    if (Double.isNaN(temperature)) {
      temperature = 0.7;
    }
    temperature = Math.min(2.0, Math.max(0.0, temperature));
  }

  public boolean isConfigured() {
    return apiKey != null && !apiKey.isBlank();
  }
}
