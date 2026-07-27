package com.folio.backend.integrations.jira;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.config.JiraOAuthProperties;
import java.net.URI;
import java.net.URL;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

@Service
public class JiraOAuthService {

  private static final Logger log = LoggerFactory.getLogger(JiraOAuthService.class);

  private final JiraOAuthProperties props;
  private final ObjectMapper mapper;
  private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).build();

  /** Optional override for tests. */
  private volatile String tokenUrl = "https://auth.atlassian.com/oauth/token";

  public JiraOAuthService(JiraOAuthProperties props, ObjectMapper mapper) {
    this.props = props;
    this.mapper = mapper;
  }

  void setTokenUrlForTests(String url) {
    this.tokenUrl = url;
  }

  public ResponseEntity<Map<String, Object>> exchange(Map<String, Object> body) {
    if (!props.isConfigured()) {
      return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
          .body(Map.of("error", "jira_oauth_not_configured"));
    }
    String code = str(body.get("code"));
    String redirectUri = str(body.get("redirectUri"));
    String clientIdRaw = str(body.get("clientId"));
    String clientId = clientIdRaw.isEmpty() ? props.oauthClientId() : clientIdRaw;
    String codeVerifier = str(body.get("codeVerifier"));
    if (code.isEmpty() || redirectUri.isEmpty()) {
      return ResponseEntity.badRequest().body(Map.of("error", "missing_code_or_redirect"));
    }
    String validatedRedirect;
    try {
      URL u = URI.create(redirectUri).toURL();
      if (!"http".equals(u.getProtocol()) || !"127.0.0.1".equals(u.getHost())) {
        return ResponseEntity.badRequest().body(Map.of("error", "invalid_redirect_uri"));
      }
      if (u.getPort() != 45747) {
        return ResponseEntity.badRequest().body(Map.of("error", "invalid_redirect_uri"));
      }
      if (!u.getPath().endsWith("/callback")) {
        return ResponseEntity.badRequest().body(Map.of("error", "invalid_redirect_uri"));
      }
      validatedRedirect = u.toString();
    } catch (Exception e) {
      return ResponseEntity.badRequest().body(Map.of("error", "invalid_redirect_uri"));
    }

    try {
      Map<String, Object> payload = new LinkedHashMap<>();
      payload.put("grant_type", "authorization_code");
      payload.put("client_id", clientId);
      payload.put("client_secret", props.oauthClientSecret());
      payload.put("code", code);
      payload.put("redirect_uri", validatedRedirect);
      if (!codeVerifier.isEmpty()) {
        payload.put("code_verifier", codeVerifier);
      }
      String basic =
          Base64.getEncoder()
              .encodeToString((clientId + ":" + props.oauthClientSecret()).getBytes(StandardCharsets.UTF_8));
      HttpRequest req =
          HttpRequest.newBuilder()
              .uri(URI.create(tokenUrl))
              .timeout(Duration.ofSeconds(30))
              .header("content-type", "application/json")
              .header("authorization", "Basic " + basic)
              .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload)))
              .build();
      HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
      String text = resp.body();
      if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
        log.warn("folioJiraExchangeOAuth: Atlassian error {} {}", resp.statusCode(), text);
        String bodySlice = text.length() > 800 ? text.substring(0, 800) + "…" : text;
        Map<String, Object> err = new LinkedHashMap<>();
        err.put("error", "atlassian_token_failed");
        err.put("status", resp.statusCode());
        err.put("body", bodySlice);
        return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(err);
      }
      JsonNode json = mapper.readTree(text);
      @SuppressWarnings("unchecked")
      Map<String, Object> map = mapper.convertValue(json, Map.class);
      return ResponseEntity.ok(map);
    } catch (Exception e) {
      log.error("jira oauth exchange failed", e);
      return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(Map.of("error", "invalid_atlassian_json"));
    }
  }

  private static String str(Object v) {
    return v == null ? "" : String.valueOf(v).trim();
  }
}
