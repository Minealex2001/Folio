package com.folio.backend.integrations.spotify;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.config.IntegrationsProperties;
import com.folio.backend.user.FolioUserPrincipal;
import java.net.URI;
import java.net.URL;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/integrations/spotify")
public class SpotifyController {

  private static final String TOKEN_URL = "https://accounts.spotify.com/api/token";
  private static final String API_BASE = "https://api.spotify.com";

  private final IntegrationsProperties props;
  private final ObjectMapper mapper;
  private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).build();

  volatile String tokenUrlOverride;
  volatile String apiBaseOverride;

  public SpotifyController(IntegrationsProperties props, ObjectMapper mapper) {
    this.props = props;
    this.mapper = mapper;
  }

  @PostMapping("/oauth-exchange")
  public ResponseEntity<Map<String, Object>> oauthExchange(@RequestBody Map<String, Object> body)
      throws Exception {
    FolioUserPrincipal.requireUid();
    String grantType = str(body.get("grantType"));
    if (grantType.isEmpty()) {
      grantType = "authorization_code";
    }
    String configuredClientId = props.spotifyOauthClientId();
    String requestedClientId = str(body.get("clientId"));
    String clientId = requestedClientId.isEmpty() ? configuredClientId : requestedClientId;
    if (clientId.isEmpty()) {
      return ResponseEntity.badRequest().body(Map.of("error", "missing_client_id"));
    }
    if (!configuredClientId.isEmpty() && !clientId.equals(configuredClientId)) {
      return ResponseEntity.status(403).body(Map.of("error", "client_id_not_allowed"));
    }

    StringBuilder params = new StringBuilder();
    if ("refresh_token".equals(grantType)) {
      String refreshToken = str(body.get("refreshToken"));
      if (refreshToken.isEmpty()) {
        return ResponseEntity.badRequest().body(Map.of("error", "missing_fields"));
      }
      append(params, "grant_type", "refresh_token");
      append(params, "refresh_token", refreshToken);
      append(params, "client_id", clientId);
    } else {
      String code = str(body.get("code"));
      String redirectUri = str(body.get("redirectUri"));
      String codeVerifier = str(body.get("codeVerifier"));
      if (code.isEmpty() || redirectUri.isEmpty() || codeVerifier.isEmpty()) {
        return ResponseEntity.badRequest().body(Map.of("error", "missing_fields"));
      }
      if (!isValidRedirect(redirectUri)) {
        return ResponseEntity.badRequest().body(Map.of("error", "invalid_redirect_uri"));
      }
      append(params, "grant_type", "authorization_code");
      append(params, "code", code);
      append(params, "redirect_uri", redirectUri);
      append(params, "client_id", clientId);
      append(params, "code_verifier", codeVerifier);
    }

    String url = tokenUrlOverride != null ? tokenUrlOverride : TOKEN_URL;
    HttpRequest req =
        HttpRequest.newBuilder()
            .uri(URI.create(url))
            .timeout(Duration.ofSeconds(30))
            .header("content-type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(params.toString()))
            .build();
    HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
    String text = resp.body();
    if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
      String bodySlice = text.length() > 800 ? text.substring(0, 800) + "…" : text;
      Map<String, Object> err = new LinkedHashMap<>();
      err.put("error", "spotify_token_failed");
      err.put("status", resp.statusCode());
      err.put("body", bodySlice);
      return ResponseEntity.status(502).body(err);
    }
    try {
      @SuppressWarnings("unchecked")
      Map<String, Object> json = mapper.readValue(text, Map.class);
      return ResponseEntity.ok(json);
    } catch (Exception e) {
      return ResponseEntity.status(502).body(Map.of("error", "invalid_token_response"));
    }
  }

  @GetMapping(value = "/oauth-callback", produces = MediaType.TEXT_HTML_VALUE)
  public String oauthCallback(
      @RequestParam(value = "error", required = false) String err,
      @RequestParam(value = "code", required = false) String code,
      @RequestParam(value = "state", required = false) String state,
      @RequestParam(value = "origin", required = false) String origin) {
    String safeErr = err == null ? "" : err.trim();
    String safeCode = code == null ? "" : code.trim();
    String safeState = state == null ? "" : state.trim();
    String targetOrigin = resolveTargetOrigin(origin == null ? "" : origin.trim());
    String payload =
        jsonEscape(
            Map.of(
                "type", "folio-spotify-oauth",
                "code", safeCode,
                "state", safeState,
                "error", safeErr));
    String title = safeErr.isEmpty() ? "Conectado" : "OAuth cancelado";
    String message =
        safeErr.isEmpty()
            ? "Ya puedes volver a Folio. Puedes cerrar esta pestaña."
            : "Error: " + htmlEscape(safeErr);
    return "<!DOCTYPE html>\n"
        + "<html><head><meta charset=\"utf-8\"><title>"
        + title
        + "</title></head>\n<body>\n  <h2>"
        + title
        + "</h2>\n  <p>"
        + message
        + "</p>\n  <script>\n    (function () {\n      var payload = "
        + payload
        + ";\n      try {\n        localStorage.setItem(\"folio_spotify_oauth\", JSON.stringify(payload));\n      } catch (e) {}\n      var targetOrigin = "
        + mapper.valueToTree(targetOrigin)
        + ";\n      try {\n        if (window.opener && !window.opener.closed) {\n          window.opener.postMessage(payload, targetOrigin);\n        }\n      } catch (e) {}\n      try {\n        if (window.parent && window.parent !== window) {\n          window.parent.postMessage(payload, targetOrigin);\n        }\n      } catch (e) {}\n      setTimeout(function () {\n        try { window.close(); } catch (e) {}\n      }, 400);\n    })();\n  </script>\n</body></html>";
  }

  @PostMapping("/api-proxy")
  public ResponseEntity<Map<String, Object>> apiProxy(@RequestBody Map<String, Object> body)
      throws Exception {
    FolioUserPrincipal.requireUid();
    String method = str(body.get("method")).toUpperCase(Locale.ROOT);
    if (method.isEmpty()) {
      method = "GET";
    }
    String path = str(body.get("path"));
    String accessToken = str(body.get("accessToken"));
    if (!path.startsWith("/v1/") || accessToken.isEmpty()) {
      return ResponseEntity.badRequest().body(Map.of("error", "invalid_request"));
    }
    if (!List.of("GET", "PUT", "POST", "DELETE").contains(method)) {
      return ResponseEntity.badRequest().body(Map.of("error", "invalid_method"));
    }
    Map<String, String> headers = new LinkedHashMap<>();
    headers.put("authorization", "Bearer " + accessToken);
    Object extraHeaders = body.get("headers");
    if (extraHeaders instanceof Map<?, ?> eh) {
      for (Map.Entry<?, ?> e : eh.entrySet()) {
        if (e.getValue() instanceof String s) {
          headers.put(String.valueOf(e.getKey()).toLowerCase(Locale.ROOT), s);
        }
      }
    }
    String fetchBody = null;
    if (body.get("body") != null) {
      Object b = body.get("body");
      fetchBody = b instanceof String s ? s : mapper.writeValueAsString(b);
      headers.putIfAbsent("content-type", "application/json");
    }
    String base = apiBaseOverride != null ? apiBaseOverride : API_BASE;
    HttpRequest.Builder builder =
        HttpRequest.newBuilder().uri(URI.create(base + path)).timeout(Duration.ofSeconds(30));
    headers.forEach(builder::header);
    if (fetchBody == null) {
      builder.method(method, HttpRequest.BodyPublishers.noBody());
    } else {
      builder.method(method, HttpRequest.BodyPublishers.ofString(fetchBody));
    }
    HttpResponse<String> apiResp = http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    String text = apiResp.body();
    Object parsed;
    if (text == null || text.trim().isEmpty()) {
      parsed = null;
    } else {
      String trimmed = text.trim();
      if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
        try {
          parsed = mapper.readValue(text, Object.class);
        } catch (Exception e) {
          parsed = text;
        }
      } else {
        parsed = text;
      }
    }
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("status", apiResp.statusCode());
    out.put("body", parsed);
    return ResponseEntity.ok(out);
  }

  private String jsonEscape(Map<String, String> map) {
    try {
      return mapper.writeValueAsString(map);
    } catch (Exception e) {
      return "{}";
    }
  }

  private static String htmlEscape(String s) {
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
  }

  private static boolean isValidRedirect(String redirectUri) {
    return isValidLoopback(redirectUri)
        || isValidCloudCallback(redirectUri)
        || isValidFolioWebCallback(redirectUri);
  }

  private static boolean isValidLoopback(String redirectUri) {
    try {
      URL u = URI.create(redirectUri).toURL();
      return "http".equals(u.getProtocol())
          && "127.0.0.1".equals(u.getHost())
          && u.getPort() == 45748
          && u.getPath().endsWith("/callback");
    } catch (Exception e) {
      return false;
    }
  }

  private static boolean isValidCloudCallback(String redirectUri) {
    try {
      URL u = URI.create(redirectUri).toURL();
      return "https".equals(u.getProtocol())
          && u.getHost().endsWith(".cloudfunctions.net")
          && (u.getPath().equals("/folioSpotifyOAuthCallback")
              || u.getPath().endsWith("/folioSpotifyOAuthCallback"));
    } catch (Exception e) {
      return false;
    }
  }

  private static boolean isValidFolioWebCallback(String redirectUri) {
    try {
      URL u = URI.create(redirectUri).toURL();
      boolean pathOk =
          u.getPath().equals("/spotify_oauth_callback.html")
              || u.getPath().endsWith("/spotify_oauth_callback.html");
      if (!pathOk) {
        return false;
      }
      String host = u.getHost().toLowerCase(Locale.ROOT);
      if (host.equals("foliobeta.minealexgames.com") || host.equals("folio.minealexgames.com")) {
        return "https".equals(u.getProtocol());
      }
      return "http".equals(u.getProtocol()) && (host.equals("localhost") || host.equals("127.0.0.1"));
    } catch (Exception e) {
      return false;
    }
  }

  private static String resolveTargetOrigin(String origin) {
    try {
      URL u = URI.create(origin).toURL();
      String host = u.getHost().toLowerCase(Locale.ROOT);
      if ((host.equals("foliobeta.minealexgames.com") || host.equals("folio.minealexgames.com"))
          && "https".equals(u.getProtocol())) {
        return u.getProtocol() + "://" + u.getHost() + (u.getPort() > 0 ? ":" + u.getPort() : "");
      }
      if ("http".equals(u.getProtocol())
          && (host.equals("localhost") || host.equals("127.0.0.1"))) {
        return u.getProtocol() + "://" + u.getHost() + (u.getPort() > 0 ? ":" + u.getPort() : "");
      }
    } catch (Exception ignored) {
      // fall through
    }
    return "*";
  }

  private static void append(StringBuilder sb, String key, String value) {
    if (!sb.isEmpty()) {
      sb.append('&');
    }
    sb.append(URLEncoder.encode(key, StandardCharsets.UTF_8));
    sb.append('=');
    sb.append(URLEncoder.encode(value, StandardCharsets.UTF_8));
  }

  private static String str(Object v) {
    return v == null ? "" : String.valueOf(v).trim();
  }
}
