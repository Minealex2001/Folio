package com.folio.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.jira")
public record JiraOAuthProperties(String oauthClientId, String oauthClientSecret) {

  public static final String DEFAULT_CLOUD_CLIENT_ID = "7HEIa3N2dGmMWWscFmYnjGRLNSjzg8hI";

  public JiraOAuthProperties {
    if (oauthClientId == null || oauthClientId.isBlank()) {
      oauthClientId = DEFAULT_CLOUD_CLIENT_ID;
    }
    if (oauthClientSecret == null) {
      oauthClientSecret = "";
    }
  }

  public boolean isConfigured() {
    return oauthClientSecret != null && !oauthClientSecret.isBlank();
  }
}
