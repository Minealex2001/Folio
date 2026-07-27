package com.folio.backend.integrations;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class SlackTeamsIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private TeamsWebhookEndpointRepository teamsEndpoints;
  @Autowired private PendingIntegrationCommandRepository pendingCommands;

  private String accessToken;
  private String uid;

  @BeforeEach
  void registerAndLogin() throws Exception {
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"slack@example.com","password":"password123","displayName":"Slack"}
                        """))
            .andExpect(status().isCreated())
            .andReturn();
    uid = JsonPath.read(reg.getResponse().getContentAsString(), "$.uid");
    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"slack@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    accessToken = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");
  }

  @Test
  void upsertWebhookConnectionHappyAndRejectsBadHost() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/webhook-connection")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "connectionId":"conn-1",
                      "provider":"slack",
                      "webhookUrl":"https://hooks.slack.com/services/T/B/X"
                    }
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true));

    mockMvc
        .perform(
            post("/api/v1/integrations/webhook-connection")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "connectionId":"conn-2",
                      "provider":"slack",
                      "webhookUrl":"https://evil.example/hook"
                    }
                    """))
        .andExpect(status().isForbidden())
        .andExpect(jsonPath("$.error").value("permission_denied"));
  }

  @Test
  void linkCodeAndSlackCommandWithValidSignature() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/link-code")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "code":"ABCD1234",
                      "vaultId":"vault-1",
                      "connectionId":"conn-slack",
                      "provider":"slack",
                      "webhookUrl":"https://hooks.slack.com/services/T/B/X"
                    }
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true));

    String body = "user_id=U123&text=link+ABCD1234";
    String ts = String.valueOf(System.currentTimeMillis() / 1000);
    String sig = slackSig(body, ts);

    mockMvc
        .perform(
            post("/api/v1/integrations/slack/command")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .header("X-Slack-Request-Timestamp", ts)
                .header("X-Slack-Signature", sig)
                .content(body))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.response_type").value("ephemeral"))
        .andExpect(jsonPath("$.text").value(org.hamcrest.Matchers.containsString("Linked!")));
  }

  @Test
  void slackCommandRejectsInvalidSignature() throws Exception {
    String body = "user_id=U123&text=list+tasks";
    mockMvc
        .perform(
            post("/api/v1/integrations/slack/command")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .header("X-Slack-Request-Timestamp", String.valueOf(System.currentTimeMillis() / 1000))
                .header("X-Slack-Signature", "v0=deadbeef")
                .content(body))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void teamsCommandRejectsInvalidHmac() throws Exception {
    TeamsWebhookEndpointEntity ep = new TeamsWebhookEndpointEntity();
    ep.setConnectionId("teams-conn");
    ep.setUserId(uid);
    ep.setTeamsSecurityToken("teams-secret");
    teamsEndpoints.save(ep);

    mockMvc
        .perform(
            post("/api/v1/integrations/teams/command?connectionId=teams-conn")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", "HMAC invalid")
                .content(
                    """
                    {"from":{"id":"t1"},"text":"/folio list tasks"}
                    """))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void teamsCommandWithValidHmacEnqueues() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/link-code")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "code":"TEAMCODE",
                      "vaultId":"vault-t",
                      "connectionId":"teams-conn-2",
                      "provider":"teams",
                      "webhookUrl":"https://prod.webhook.office.com/webhookb2/x",
                      "teamsSecurityToken":"teams-secret-2"
                    }
                    """))
        .andExpect(status().isOk());

    // link first
    String linkBody =
        """
        {"from":{"id":"teams-user-1"},"text":"/folio link TEAMCODE"}
        """;
    String auth = teamsHmac(linkBody, "teams-secret-2");
    mockMvc
        .perform(
            post("/api/v1/integrations/teams/command?connectionId=teams-conn-2")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", auth)
                .content(linkBody))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.text").value(org.hamcrest.Matchers.containsString("Linked!")));

    String cmdBody =
        """
        {"from":{"id":"teams-user-1"},"text":"/folio list tasks"}
        """;
    String auth2 = teamsHmac(cmdBody, "teams-secret-2");
    mockMvc
        .perform(
            post("/api/v1/integrations/teams/command?connectionId=teams-conn-2")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", auth2)
                .content(cmdBody))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.text").value(org.hamcrest.Matchers.containsString("queued")));

    assertThat(pendingCommands.findByUserIdAndStatusAndVaultId(uid, "pending", "vault-t"))
        .isNotEmpty();
  }

  @Test
  void listPendingRequiresAuth() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/pending-commands")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"vaultId\":\"v\"}"))
        .andExpect(status().isUnauthorized());
  }

  private static String slackSig(String body, String ts) throws Exception {
    String base = "v0:" + ts + ":" + body;
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(
        new SecretKeySpec(
            "test-slack-signing-secret".getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
    return "v0=" + HexFormat.of().formatHex(mac.doFinal(base.getBytes(StandardCharsets.UTF_8)));
  }

  private static String teamsHmac(String body, String token) throws Exception {
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(token.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
    String hash =
        java.util.Base64.getEncoder()
            .encodeToString(mac.doFinal(body.getBytes(StandardCharsets.UTF_8)));
    return "HMAC " + hash;
  }
}
