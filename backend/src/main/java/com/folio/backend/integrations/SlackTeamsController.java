package com.folio.backend.integrations;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.config.IntegrationsProperties;
import com.folio.backend.user.FolioUserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StreamUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/integrations")
public class SlackTeamsController {

  private final SlackTeamsIntegrationService service;
  private final IntegrationsProperties props;
  private final ObjectMapper mapper;

  public SlackTeamsController(
      SlackTeamsIntegrationService service, IntegrationsProperties props, ObjectMapper mapper) {
    this.service = service;
    this.props = props;
    this.mapper = mapper;
  }

  @PostMapping("/webhook-connection")
  public Map<String, Object> upsertWebhook(@RequestBody Map<String, Object> body) {
    return service.upsertWebhookConnection(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/webhook-proxy")
  public Map<String, Object> webhookProxy(@RequestBody Map<String, Object> body) {
    return service.webhookProxy(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/link-code")
  public Map<String, Object> registerLinkCode(@RequestBody Map<String, Object> body) {
    return service.registerLinkCode(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/pending-commands")
  public Map<String, Object> listPending(@RequestBody Map<String, Object> body) {
    return service.listPending(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/ack-command")
  public Map<String, Object> ack(@RequestBody Map<String, Object> body) {
    return service.ackCommand(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping(value = "/slack/command", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
  public ResponseEntity<?> slackCommand(HttpServletRequest request) throws Exception {
    String secret = props.slackSigningSecret();
    if (secret.isBlank()) {
      return ResponseEntity.status(503).body("Slack signing secret not configured");
    }
    byte[] rawBody = StreamUtils.copyToByteArray(request.getInputStream());
    String timestamp = header(request, "x-slack-request-timestamp");
    String signature = header(request, "x-slack-signature");
    if (!PlatformSignatureVerifier.verifySlack(secret, rawBody, timestamp, signature)) {
      return ResponseEntity.status(401).body("Invalid signature");
    }
    Map<String, String> form = parseForm(new String(rawBody, StandardCharsets.UTF_8));
    String userId = form.getOrDefault("user_id", "").trim();
    String commandText = form.getOrDefault("text", "").trim();
    String fullText = commandText.isEmpty() ? "/folio" : "/folio " + commandText;
    try {
      String message =
          service.dispatchCommand("slack", userId, IntegrationCommandParser.parse(fullText));
      return ResponseEntity.ok(Map.of("response_type", "ephemeral", "text", message));
    } catch (Exception e) {
      return ResponseEntity.status(500)
          .body(Map.of("response_type", "ephemeral", "text", "Internal error."));
    }
  }

  @PostMapping(value = "/slack/command", consumes = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<?> slackCommandJson(HttpServletRequest request) throws Exception {
    String secret = props.slackSigningSecret();
    if (secret.isBlank()) {
      return ResponseEntity.status(503).body("Slack signing secret not configured");
    }
    byte[] rawBody = StreamUtils.copyToByteArray(request.getInputStream());
    String timestamp = header(request, "x-slack-request-timestamp");
    String signature = header(request, "x-slack-signature");
    if (!PlatformSignatureVerifier.verifySlack(secret, rawBody, timestamp, signature)) {
      return ResponseEntity.status(401).body("Invalid signature");
    }
    @SuppressWarnings("unchecked")
    Map<String, Object> body = mapper.readValue(rawBody, Map.class);
    String userId = String.valueOf(body.getOrDefault("user_id", "")).trim();
    String commandText = String.valueOf(body.getOrDefault("text", "")).trim();
    if ("null".equals(commandText)) {
      commandText = "";
    }
    String fullText = commandText.isEmpty() ? "/folio" : "/folio " + commandText;
    String message =
        service.dispatchCommand("slack", userId, IntegrationCommandParser.parse(fullText));
    return ResponseEntity.ok(Map.of("response_type", "ephemeral", "text", message));
  }

  @PostMapping("/teams/command")
  public ResponseEntity<?> teamsCommand(
      @RequestParam(value = "connectionId", required = false) String connectionId,
      HttpServletRequest request)
      throws Exception {
    if (connectionId == null || connectionId.isBlank()) {
      return ResponseEntity.badRequest().body("Missing connectionId query parameter");
    }
    byte[] rawBody = StreamUtils.copyToByteArray(request.getInputStream());
    String token = service.teamsSecurityToken(connectionId.trim());
    if (token.isBlank()) {
      return ResponseEntity.status(401).body("Unknown Teams webhook endpoint");
    }
    String authorization = header(request, "authorization");
    if (!PlatformSignatureVerifier.verifyTeamsOutgoingHmac(token, rawBody, authorization)) {
      return ResponseEntity.status(401).body("Invalid HMAC");
    }
    @SuppressWarnings("unchecked")
    Map<String, Object> body = mapper.readValue(rawBody, Map.class);
    Object fromObj = body.get("from");
    String userId = "";
    if (fromObj instanceof Map<?, ?> from) {
      Object id = from.get("id");
      userId = id == null ? "" : String.valueOf(id).trim();
    }
    String text = String.valueOf(body.getOrDefault("text", "")).trim();
    if ("null".equals(text)) {
      text = "";
    }
    try {
      String message =
          service.dispatchCommand("teams", userId, IntegrationCommandParser.parse(text));
      return ResponseEntity.ok(Map.of("type", "message", "text", message));
    } catch (Exception e) {
      return ResponseEntity.status(500).body(Map.of("type", "message", "text", "Internal error."));
    }
  }

  @PostMapping("/slack/oauth-exchange")
  public ResponseEntity<Map<String, Object>> slackOauth(@RequestBody Map<String, Object> body)
      throws Exception {
    FolioUserPrincipal.requireUid();
    Map<String, Object> result = service.slackOauthExchange(body);
    int status = ((Number) result.getOrDefault("_httpStatus", 200)).intValue();
    result = new LinkedHashMap<>(result);
    result.remove("_httpStatus");
    return ResponseEntity.status(status).body(result);
  }

  @PostMapping("/teams/oauth-exchange")
  public ResponseEntity<Map<String, Object>> teamsOauth(@RequestBody Map<String, Object> body)
      throws Exception {
    FolioUserPrincipal.requireUid();
    Map<String, Object> result = service.teamsOauthExchange(body);
    int status = ((Number) result.getOrDefault("_httpStatus", 200)).intValue();
    result = new LinkedHashMap<>(result);
    result.remove("_httpStatus");
    return ResponseEntity.status(status).body(result);
  }

  private static String header(HttpServletRequest request, String name) {
    String v = request.getHeader(name);
    return v == null ? "" : v;
  }

  private static Map<String, String> parseForm(String raw) {
    Map<String, String> out = new LinkedHashMap<>();
    if (raw == null || raw.isBlank()) {
      return out;
    }
    for (String part : raw.split("&")) {
      int eq = part.indexOf('=');
      if (eq < 0) {
        out.put(java.net.URLDecoder.decode(part, StandardCharsets.UTF_8), "");
      } else {
        out.put(
            java.net.URLDecoder.decode(part.substring(0, eq), StandardCharsets.UTF_8),
            java.net.URLDecoder.decode(part.substring(eq + 1), StandardCharsets.UTF_8));
      }
    }
    return out;
  }
}
