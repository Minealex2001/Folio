package com.folio.backend.integrations;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.common.ApiException;
import com.folio.backend.config.IntegrationsProperties;
import java.net.URI;
import java.net.URL;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SlackTeamsIntegrationService {

  private static final Logger log = LoggerFactory.getLogger(SlackTeamsIntegrationService.class);
  private static final long LINK_CODE_TTL_MS = 15 * 60 * 1000L;

  private final IntegrationsProperties props;
  private final ObjectMapper mapper;
  private final IntegrationWebhookConnectionRepository webhookConnections;
  private final IntegrationLinkCodeRepository linkCodes;
  private final IntegrationUserIndexRepository userIndex;
  private final PendingIntegrationCommandRepository pendingCommands;
  private final TeamsWebhookEndpointRepository teamsEndpoints;
  private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15)).build();

  volatile String slackTokenUrl = "https://slack.com/api/oauth.v2.access";
  volatile String teamsTokenUrl = "https://login.microsoftonline.com/common/oauth2/v2.0/token";

  public SlackTeamsIntegrationService(
      IntegrationsProperties props,
      ObjectMapper mapper,
      IntegrationWebhookConnectionRepository webhookConnections,
      IntegrationLinkCodeRepository linkCodes,
      IntegrationUserIndexRepository userIndex,
      PendingIntegrationCommandRepository pendingCommands,
      TeamsWebhookEndpointRepository teamsEndpoints) {
    this.props = props;
    this.mapper = mapper;
    this.webhookConnections = webhookConnections;
    this.linkCodes = linkCodes;
    this.userIndex = userIndex;
    this.pendingCommands = pendingCommands;
    this.teamsEndpoints = teamsEndpoints;
  }

  @Transactional
  public Map<String, Object> upsertWebhookConnection(String uid, Map<String, Object> data) {
    String connectionId = str(data.get("connectionId"));
    String provider = str(data.get("provider"));
    String webhookUrl = str(data.get("webhookUrl"));
    if (connectionId.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "missing_connection_id");
    }
    requireProvider(provider);
    if (webhookUrl.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "missing_webhook_url");
    }
    requireAllowedHost(webhookUrl);
    webhookConnections
        .findById(connectionId)
        .ifPresent(
            existing -> {
              if (!uid.equals(existing.getUserId())) {
                throw new ApiException(HttpStatus.CONFLICT, "already_exists", "connection_id_taken");
              }
            });
    IntegrationWebhookConnectionEntity e =
        webhookConnections.findById(connectionId).orElseGet(IntegrationWebhookConnectionEntity::new);
    e.setConnectionId(connectionId);
    e.setUserId(uid);
    e.setProvider(provider);
    e.setWebhookUrl(webhookUrl);
    webhookConnections.save(e);
    return Map.of("ok", true);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> webhookProxy(String uid, Map<String, Object> data) {
    String provider = str(data.get("provider"));
    String connectionId = str(data.get("connectionId"));
    Object payload = data.get("payload");
    requireProvider(provider);
    if (connectionId.isEmpty() || !(payload instanceof Map<?, ?>)) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "missing_connection_or_payload");
    }
    IntegrationWebhookConnectionEntity conn =
        webhookConnections
            .findById(connectionId)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "connection_not_found"));
    if (!uid.equals(conn.getUserId()) || !provider.equals(conn.getProvider())) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "not_your_connection");
    }
    requireAllowedHost(conn.getWebhookUrl());
    postWebhookJson(conn.getWebhookUrl(), payload);
    return Map.of("ok", true);
  }

  @Transactional
  public Map<String, Object> registerLinkCode(String uid, Map<String, Object> data) {
    String code = str(data.get("code")).toUpperCase(Locale.ROOT);
    String vaultId = str(data.get("vaultId"));
    String connectionId = str(data.get("connectionId"));
    String provider = str(data.get("provider"));
    String webhookUrl = str(data.get("webhookUrl"));
    String teamsSecurityToken = str(data.get("teamsSecurityToken"));
    if (!code.matches("^[A-Z0-9]{8}$")) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "invalid_code");
    }
    if (vaultId.isEmpty() || connectionId.isEmpty() || webhookUrl.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "missing_fields");
    }
    requireProvider(provider);
    requireAllowedHost(webhookUrl);
    Instant expiresAt = Instant.now().plusMillis(LINK_CODE_TTL_MS);
    IntegrationLinkCodeEntity e = new IntegrationLinkCodeEntity();
    e.setCode(code);
    e.setUserId(uid);
    e.setVaultId(vaultId);
    e.setConnectionId(connectionId);
    e.setProvider(provider);
    e.setWebhookUrl(webhookUrl);
    e.setTeamsSecurityToken(teamsSecurityToken.isEmpty() ? null : teamsSecurityToken);
    e.setExpiresAt(expiresAt);
    linkCodes.save(e);
    if ("teams".equals(provider) && !teamsSecurityToken.isEmpty()) {
      TeamsWebhookEndpointEntity ep = new TeamsWebhookEndpointEntity();
      ep.setConnectionId(connectionId);
      ep.setUserId(uid);
      ep.setTeamsSecurityToken(teamsSecurityToken);
      teamsEndpoints.save(ep);
    }
    return Map.of("ok", true, "expiresAtMs", expiresAt.toEpochMilli());
  }

  @Transactional(readOnly = true)
  public Map<String, Object> listPending(String uid, Map<String, Object> data) {
    String vaultId = str(data.get("vaultId"));
    if (vaultId.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "missing_vault_id");
    }
    int limit = 20;
    Object limitRaw = data.get("limit");
    if (limitRaw instanceof Number n) {
      limit = Math.min(Math.max(n.intValue(), 1), 50);
    }
    List<PendingIntegrationCommandEntity> rows =
        pendingCommands.findByUserIdAndStatusAndVaultId(uid, "pending", vaultId);
    List<Map<String, Object>> commands = new ArrayList<>();
    for (PendingIntegrationCommandEntity row : rows) {
      if (commands.size() >= limit) {
        break;
      }
      try {
        @SuppressWarnings("unchecked")
        Map<String, Object> payload = mapper.readValue(row.getPayload(), Map.class);
        Map<String, Object> cmd = new LinkedHashMap<>();
        cmd.put("id", row.getId().toString());
        cmd.put("provider", str(payload.get("provider")));
        cmd.put("externalUserId", str(payload.get("externalUserId")));
        cmd.put("vaultId", row.getVaultId());
        cmd.put("connectionId", str(payload.get("connectionId")));
        cmd.put("webhookUrl", str(payload.get("webhookUrl")));
        cmd.put("command", str(payload.get("command")));
        cmd.put("title", str(payload.get("title")));
        cmd.put("status", row.getStatus());
        commands.add(cmd);
      } catch (Exception e) {
        log.warn("skip bad pending command {}", row.getId(), e);
      }
    }
    return Map.of("commands", commands);
  }

  @Transactional
  public Map<String, Object> ackCommand(String uid, Map<String, Object> data) {
    String commandId = str(data.get("commandId"));
    boolean success = Boolean.TRUE.equals(data.get("success"));
    String taskTitle = str(data.get("taskTitle"));
    String errorMessage = str(data.get("errorMessage"));
    String responseMessage = str(data.get("responseMessage"));
    if (commandId.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "missing_command_id");
    }
    UUID id;
    try {
      id = UUID.fromString(commandId);
    } catch (IllegalArgumentException e) {
      throw new ApiException(HttpStatus.NOT_FOUND, "not_found", "command_not_found");
    }
    PendingIntegrationCommandEntity cmd =
        pendingCommands
            .findByIdAndUserId(id, uid)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "command_not_found"));
    if (!"pending".equals(cmd.getStatus())) {
      return Map.of("ok", true, "duplicate", true);
    }
    @SuppressWarnings("unchecked")
    Map<String, Object> payload;
    try {
      payload = mapper.readValue(cmd.getPayload(), Map.class);
    } catch (Exception e) {
      payload = Map.of();
    }
    String webhookUrl = str(payload.get("webhookUrl"));
    String provider = str(payload.get("provider"));
    String command = str(payload.get("command"));
    cmd.setStatus(success ? "applied" : "failed");
    cmd.setProcessedAt(Instant.now());
    cmd.setErrorMessage(success ? null : (errorMessage.isEmpty() ? "unknown_error" : errorMessage));
    pendingCommands.save(cmd);
    if (!webhookUrl.isEmpty()) {
      String text = responseMessage;
      if (text.isEmpty()) {
        if (success) {
          text =
              "create_task".equals(command)
                  ? "✅ Folio created task \"" + (taskTitle.isEmpty() ? "untitled" : taskTitle) + "\"."
                  : "✅ Folio applied command \"" + (command.isEmpty() ? "unknown" : command) + "\".";
        } else {
          text =
              "❌ Folio could not apply the command: "
                  + (errorMessage.isEmpty() ? "unknown error" : errorMessage)
                  + ".";
        }
      }
      try {
        if ("teams".equals(provider)) {
          postWebhookJson(
              webhookUrl,
              Map.of(
                  "type",
                  "message",
                  "attachments",
                  List.of(
                      Map.of(
                          "contentType",
                          "application/vnd.microsoft.card.adaptive",
                          "content",
                          Map.of(
                              "$schema",
                              "http://adaptivecards.io/schemas/adaptive-card.json",
                              "type",
                              "AdaptiveCard",
                              "version",
                              "1.4",
                              "body",
                              List.of(Map.of("type", "TextBlock", "text", text, "wrap", true)))))));
        } else {
          postWebhookJson(webhookUrl, Map.of("text", text));
        }
      } catch (Exception err) {
        log.warn("folioAckIntegrationCommand: confirmation webhook failed", err);
      }
    }
    return Map.of("ok", true);
  }

  @Transactional
  public String dispatchCommand(String provider, String externalUserId, IntegrationCommandParser.Parsed parsed) {
    return switch (parsed) {
      case IntegrationCommandParser.Parsed.Link link -> handleLink(provider, externalUserId, link.code());
      case IntegrationCommandParser.Parsed.CreateTask create ->
          enqueue(provider, externalUserId, Map.of("command", "create_task", "title", create.title()));
      case IntegrationCommandParser.Parsed.ListTasks ignored ->
          enqueue(provider, externalUserId, Map.of("command", "list_tasks"));
      case IntegrationCommandParser.Parsed.CompleteTask complete ->
          enqueue(
              provider, externalUserId, Map.of("command", "complete_task", "title", complete.title()));
      case IntegrationCommandParser.Parsed.Unknown ignored ->
          "Unknown command. Supported: `/folio link CODE`, `/folio create task \"Title\"`, "
              + "`/folio list tasks`, `/folio complete task \"Title\"`.";
    };
  }

  private String handleLink(String provider, String externalUserId, String code) {
    String normalized = code.toUpperCase(Locale.ROOT);
    IntegrationLinkCodeEntity codeEntity = linkCodes.findById(normalized).orElse(null);
    if (codeEntity == null) {
      return "Invalid or expired link code. Generate a new one in Folio Settings → Integrations.";
    }
    if (Instant.now().isAfter(codeEntity.getExpiresAt())) {
      linkCodes.delete(codeEntity);
      return "Link code expired. Generate a new one in Folio Settings → Integrations.";
    }
    if (!provider.equals(codeEntity.getProvider())) {
      return "This link code was created for a different provider.";
    }
    String firebaseUid = codeEntity.getUserId();
    String vaultId = codeEntity.getVaultId();
    String connectionId = codeEntity.getConnectionId();
    String webhookUrl = codeEntity.getWebhookUrl();
    if (firebaseUid.isEmpty() || vaultId.isEmpty() || connectionId.isEmpty() || webhookUrl.isEmpty()) {
      return "Link code is incomplete. Generate a new one in Folio.";
    }
    String indexId = provider + "_" + externalUserId;
    IntegrationUserIndexEntity idx = new IntegrationUserIndexEntity();
    idx.setId(indexId);
    idx.setProvider(provider);
    idx.setExternalUserId(externalUserId);
    idx.setUserId(firebaseUid);
    idx.setVaultId(vaultId);
    idx.setConnectionId(connectionId);
    idx.setWebhookUrl(webhookUrl);
    idx.setTeamsSecurityToken(codeEntity.getTeamsSecurityToken());
    idx.setLinkedAt(Instant.now());
    userIndex.save(idx);
    linkCodes.delete(codeEntity);
    return "Linked! Commands: `/folio create task \"Title\"`, `/folio list tasks`, "
        + "`/folio complete task \"Title\"` (or `@Folio …` in Teams).";
  }

  private String enqueue(String provider, String externalUserId, Map<String, Object> fields) {
    IntegrationUserIndexEntity index = userIndex.findById(provider + "_" + externalUserId).orElse(null);
    if (index == null) {
      return "Account not linked. In Folio Settings → Integrations, generate a link code and run `/folio link CODE`.";
    }
    String firebaseUid = index.getUserId();
    String vaultId = index.getVaultId() == null ? "" : index.getVaultId();
    if (firebaseUid == null || firebaseUid.isBlank() || vaultId.isBlank()) {
      return "Link index is invalid. Re-link your account from Folio.";
    }
    Map<String, Object> payload = new LinkedHashMap<>();
    payload.put("provider", provider);
    payload.put("externalUserId", externalUserId);
    payload.put("vaultId", vaultId);
    payload.put("connectionId", index.getConnectionId() == null ? "" : index.getConnectionId());
    payload.put("webhookUrl", index.getWebhookUrl() == null ? "" : index.getWebhookUrl());
    payload.put("status", "pending");
    payload.putAll(fields);
    try {
      PendingIntegrationCommandEntity cmd = new PendingIntegrationCommandEntity();
      cmd.setUserId(firebaseUid);
      cmd.setVaultId(vaultId);
      cmd.setStatus("pending");
      cmd.setPayload(mapper.writeValueAsString(payload));
      pendingCommands.save(cmd);
    } catch (Exception e) {
      throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "enqueue_failed");
    }
    return "Folio queued your command. It will run the next time you open Folio "
        + "(may take from seconds to days). / Folio ha encolado tu comando. "
        + "Se aplicará la próxima vez que abras Folio (puede tardar de segundos a días).";
  }

  public String slackSigningSecret() {
    return props.slackSigningSecret();
  }

  public String teamsSecurityToken(String connectionId) {
    return teamsEndpoints
        .findById(connectionId)
        .map(TeamsWebhookEndpointEntity::getTeamsSecurityToken)
        .orElse("");
  }

  public Map<String, Object> slackOauthExchange(Map<String, Object> body) throws Exception {
    String grantType = str(body.get("grantType"));
    if (grantType.isEmpty()) {
      grantType = "authorization_code";
    }
    String clientId = str(body.get("clientId"));
    if (clientId.isEmpty()) {
      clientId = props.slackOauthClientId();
    }
    String clientSecret = props.slackOauthClientSecret();
    if (clientId.isEmpty()) {
      return error(400, "missing_client_id");
    }
    var params = new StringBuilder();
    appendForm(params, "client_id", clientId);
    if (!clientSecret.isEmpty()) {
      appendForm(params, "client_secret", clientSecret);
    }
    if ("refresh_token".equals(grantType)) {
      String refreshToken = str(body.get("refreshToken"));
      if (refreshToken.isEmpty()) {
        return error(400, "missing_fields");
      }
      appendForm(params, "grant_type", "refresh_token");
      appendForm(params, "refresh_token", refreshToken);
    } else {
      String code = str(body.get("code"));
      String redirectUri = str(body.get("redirectUri"));
      String codeVerifier = str(body.get("codeVerifier"));
      if (code.isEmpty() || redirectUri.isEmpty() || codeVerifier.isEmpty()) {
        return error(400, "missing_fields");
      }
      if (!isValidSlackLoopback(redirectUri)) {
        return error(400, "invalid_redirect_uri");
      }
      appendForm(params, "grant_type", "authorization_code");
      appendForm(params, "code", code);
      appendForm(params, "redirect_uri", redirectUri);
      appendForm(params, "code_verifier", codeVerifier);
    }
    HttpRequest req =
        HttpRequest.newBuilder()
            .uri(URI.create(slackTokenUrl))
            .header("content-type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(params.toString()))
            .build();
    HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
    if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
      return error(502, "slack_token_failed");
    }
    @SuppressWarnings("unchecked")
    Map<String, Object> json = mapper.readValue(resp.body(), Map.class);
    if (!Boolean.TRUE.equals(json.get("ok"))) {
      Map<String, Object> out = new LinkedHashMap<>();
      out.put("_httpStatus", 502);
      out.put("error", "slack_oauth_denied");
      out.put("detail", json);
      return out;
    }
    json.put("_httpStatus", 200);
    return json;
  }

  public Map<String, Object> teamsOauthExchange(Map<String, Object> body) throws Exception {
    String grantType = str(body.get("grantType"));
    if (grantType.isEmpty()) {
      grantType = "authorization_code";
    }
    String clientId = str(body.get("clientId"));
    if (clientId.isEmpty()) {
      clientId = props.teamsOauthClientId();
    }
    String clientSecret = props.teamsOauthClientSecret();
    if (clientId.isEmpty()) {
      return error(400, "missing_client_id");
    }
    var params = new StringBuilder();
    appendForm(params, "client_id", clientId);
    if (!clientSecret.isEmpty()) {
      appendForm(params, "client_secret", clientSecret);
    }
    String scope = str(body.get("scope"));
    if (scope.isEmpty()) {
      scope = "openid offline_access ChannelMessage.Send";
    }
    if ("refresh_token".equals(grantType)) {
      String refreshToken = str(body.get("refreshToken"));
      if (refreshToken.isEmpty()) {
        return error(400, "missing_fields");
      }
      appendForm(params, "grant_type", "refresh_token");
      appendForm(params, "refresh_token", refreshToken);
      appendForm(params, "scope", scope);
    } else {
      String code = str(body.get("code"));
      String redirectUri = str(body.get("redirectUri"));
      String codeVerifier = str(body.get("codeVerifier"));
      if (code.isEmpty() || redirectUri.isEmpty() || codeVerifier.isEmpty()) {
        return error(400, "missing_fields");
      }
      if (!isValidTeamsLoopback(redirectUri)) {
        return error(400, "invalid_redirect_uri");
      }
      appendForm(params, "grant_type", "authorization_code");
      appendForm(params, "code", code);
      appendForm(params, "redirect_uri", redirectUri);
      appendForm(params, "code_verifier", codeVerifier);
      appendForm(params, "scope", scope);
    }
    HttpRequest req =
        HttpRequest.newBuilder()
            .uri(URI.create(teamsTokenUrl))
            .header("content-type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(params.toString()))
            .build();
    HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
    if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
      return error(502, "teams_token_failed");
    }
    @SuppressWarnings("unchecked")
    Map<String, Object> json = mapper.readValue(resp.body(), Map.class);
    json.put("_httpStatus", 200);
    return json;
  }

  private void postWebhookJson(String webhookUrl, Object payload) {
    try {
      requireAllowedHost(webhookUrl);
      HttpRequest req =
          HttpRequest.newBuilder()
              .uri(URI.create(webhookUrl))
              .timeout(Duration.ofSeconds(15))
              .header("Content-Type", "application/json")
              .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload)))
              .build();
      HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
      if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
        throw new ApiException(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "internal",
            "webhook_failed_" + resp.statusCode() + ": " + resp.body());
      }
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "webhook_post_failed");
    }
  }

  private static void requireProvider(String provider) {
    if (!"slack".equals(provider) && !"teams".equals(provider) && !"discord".equals(provider)) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "invalid_provider");
    }
  }

  private static void requireAllowedHost(String webhookUrl) {
    try {
      String host = URI.create(webhookUrl).toURL().getHost().toLowerCase(Locale.ROOT);
      if (!integrationWebhookHostAllowed(host)) {
        throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "webhook_host_not_allowed");
      }
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "invalid_webhook_url");
    }
  }

  static boolean integrationWebhookHostAllowed(String hostname) {
    String h = hostname.toLowerCase(Locale.ROOT);
    if (h.equals("hooks.slack.com")) return true;
    if (h.endsWith(".logic.azure.com")) return true;
    if (h.endsWith(".powerplatform.com")) return true;
    if (h.endsWith(".office.com")) return true;
    if (h.endsWith(".office365.com")) return true;
    if (h.endsWith(".webhook.office.com")) return true;
    if (h.equals("discord.com") || h.equals("discordapp.com")) return true;
    if (h.endsWith(".discord.com") || h.endsWith(".discordapp.com")) return true;
    return false;
  }

  private static boolean isValidSlackLoopback(String redirectUri) {
    try {
      URL u = URI.create(redirectUri).toURL();
      return "http".equals(u.getProtocol())
          && "127.0.0.1".equals(u.getHost())
          && u.getPort() == 45749
          && u.getPath().endsWith("/callback");
    } catch (Exception e) {
      return false;
    }
  }

  private static boolean isValidTeamsLoopback(String redirectUri) {
    try {
      URL u = URI.create(redirectUri).toURL();
      return "http".equals(u.getProtocol())
          && "127.0.0.1".equals(u.getHost())
          && u.getPort() == 45750
          && u.getPath().endsWith("/callback");
    } catch (Exception e) {
      return false;
    }
  }

  private static Map<String, Object> error(int status, String code) {
    Map<String, Object> m = new LinkedHashMap<>();
    m.put("_httpStatus", status);
    m.put("error", code);
    return m;
  }

  private static void appendForm(StringBuilder sb, String key, String value) {
    if (!sb.isEmpty()) {
      sb.append('&');
    }
    sb.append(java.net.URLEncoder.encode(key, StandardCharsets.UTF_8));
    sb.append('=');
    sb.append(java.net.URLEncoder.encode(value, StandardCharsets.UTF_8));
  }

  private static String str(Object v) {
    return v == null ? "" : String.valueOf(v).trim();
  }
}
