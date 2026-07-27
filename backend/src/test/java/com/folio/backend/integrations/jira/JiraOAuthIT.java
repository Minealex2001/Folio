package com.folio.backend.integrations.jira;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.sun.net.httpserver.HttpServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

class JiraOAuthIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private JiraOAuthService jiraOAuthService;

  private HttpServer server;

  @BeforeEach
  void startMockAtlassian() throws Exception {
    server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
    server.createContext(
        "/oauth/token",
        exchange -> {
          byte[] body =
              """
              {"access_token":"at_test","refresh_token":"rt_test","expires_in":3600,"token_type":"Bearer"}
              """
                  .getBytes(StandardCharsets.UTF_8);
          exchange.getResponseHeaders().add("Content-Type", "application/json");
          exchange.sendResponseHeaders(200, body.length);
          try (OutputStream os = exchange.getResponseBody()) {
            os.write(body);
          }
        });
    server.start();
    jiraOAuthService.setTokenUrlForTests(
        "http://127.0.0.1:" + server.getAddress().getPort() + "/oauth/token");
  }

  @AfterEach
  void stopServer() {
    if (server != null) {
      server.stop(0);
    }
  }

  @Test
  void oauthExchangeIsPublicAndReturnsDartShape() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/jira/oauth-exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "code":"abc",
                      "redirectUri":"http://127.0.0.1:45747/callback",
                      "clientId":"test-jira-client",
                      "codeVerifier":"verifier123"
                    }
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.access_token").value("at_test"))
        .andExpect(jsonPath("$.refresh_token").value("rt_test"))
        .andExpect(jsonPath("$.expires_in").value(3600));
  }

  @Test
  void oauthExchangeRejectsBadRedirect() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/jira/oauth-exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"code":"abc","redirectUri":"https://evil.example/callback"}
                    """))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("invalid_redirect_uri"));
  }
}
