package com.folio.backend.integrations.spotify;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
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
import org.springframework.test.web.servlet.MvcResult;

class SpotifyIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private SpotifyController spotifyController;

  private String accessToken;
  private HttpServer server;

  @BeforeEach
  void setup() throws Exception {
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"spotify@example.com","password":"password123","displayName":"Spot"}
                        """))
            .andExpect(status().isCreated())
            .andReturn();

    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"spotify@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    accessToken = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");

    server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
    server.createContext(
        "/api/token",
        exchange -> {
          byte[] body =
              """
              {"access_token":"sp_at","refresh_token":"sp_rt","expires_in":3600}
              """
                  .getBytes(StandardCharsets.UTF_8);
          exchange.getResponseHeaders().add("Content-Type", "application/json");
          exchange.sendResponseHeaders(200, body.length);
          try (OutputStream os = exchange.getResponseBody()) {
            os.write(body);
          }
        });
    server.createContext(
        "/v1/me",
        exchange -> {
          byte[] body = "{\"id\":\"user1\"}".getBytes(StandardCharsets.UTF_8);
          exchange.getResponseHeaders().add("Content-Type", "application/json");
          exchange.sendResponseHeaders(200, body.length);
          try (OutputStream os = exchange.getResponseBody()) {
            os.write(body);
          }
        });
    server.start();
    int port = server.getAddress().getPort();
    spotifyController.tokenUrlOverride = "http://127.0.0.1:" + port + "/api/token";
    spotifyController.apiBaseOverride = "http://127.0.0.1:" + port;
  }

  @AfterEach
  void stop() {
    if (server != null) {
      server.stop(0);
    }
    spotifyController.tokenUrlOverride = null;
    spotifyController.apiBaseOverride = null;
  }

  @Test
  void oauthExchangeRequiresAuth() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/spotify/oauth-exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void oauthExchangeHappyPath() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/spotify/oauth-exchange")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "code":"c",
                      "redirectUri":"http://127.0.0.1:45748/callback",
                      "codeVerifier":"v",
                      "clientId":"test-spotify-client"
                    }
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.access_token").value("sp_at"));
  }

  @Test
  void oauthCallbackIsPublicHtml() throws Exception {
    mockMvc
        .perform(get("/api/v1/integrations/spotify/oauth-callback").param("code", "x").param("state", "s"))
        .andExpect(status().isOk())
        .andExpect(content().string(org.hamcrest.Matchers.containsString("folio-spotify-oauth")));
  }

  @Test
  void apiProxyPassthrough() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/spotify/api-proxy")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"method":"GET","path":"/v1/me","accessToken":"tok"}
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value(200))
        .andExpect(jsonPath("$.body.id").value("user1"));
  }

  @Test
  void apiProxyRejectsBadPath() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/integrations/spotify/api-proxy")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"method":"GET","path":"/evil","accessToken":"tok"}
                    """))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("invalid_request"));
  }
}
