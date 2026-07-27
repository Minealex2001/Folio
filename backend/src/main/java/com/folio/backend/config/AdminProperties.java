package com.folio.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.admin")
public class AdminProperties {

  /** Shared secret for X-Folio-Admin-Key (local / self-host QA). Empty = key auth disabled. */
  private String apiKey = "";

  public String getApiKey() {
    return apiKey;
  }

  public void setApiKey(String apiKey) {
    this.apiKey = apiKey;
  }

  public boolean isApiKeyConfigured() {
    return apiKey != null && !apiKey.isBlank();
  }
}
