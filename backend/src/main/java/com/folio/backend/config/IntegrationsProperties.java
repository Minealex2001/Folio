package com.folio.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.integrations")
public record IntegrationsProperties(
    String slackSigningSecret,
    String slackOauthClientId,
    String slackOauthClientSecret,
    String teamsOauthClientId,
    String teamsOauthClientSecret,
    String spotifyOauthClientId,
    String youtrackBaseUrl,
    String youtrackToken,
    String youtrackProjectId) {

  public IntegrationsProperties {
    slackSigningSecret = blankToEmpty(slackSigningSecret);
    slackOauthClientId = blankToEmpty(slackOauthClientId);
    slackOauthClientSecret = blankToEmpty(slackOauthClientSecret);
    teamsOauthClientId = blankToEmpty(teamsOauthClientId);
    teamsOauthClientSecret = blankToEmpty(teamsOauthClientSecret);
    spotifyOauthClientId = blankToEmpty(spotifyOauthClientId);
    youtrackBaseUrl = blankToEmpty(youtrackBaseUrl);
    youtrackToken = blankToEmpty(youtrackToken);
    youtrackProjectId = blankToEmpty(youtrackProjectId);
  }

  public boolean youtrackConfigured() {
    return !youtrackBaseUrl.isBlank() && !youtrackToken.isBlank() && !youtrackProjectId.isBlank();
  }

  private static String blankToEmpty(String v) {
    return v == null ? "" : v.trim();
  }
}
