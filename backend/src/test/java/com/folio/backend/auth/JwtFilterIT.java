package com.folio.backend.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class JwtFilterIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;

  @Value("${folio.jwt.signing-secret}")
  private String signingSecret;

  private String accessToken;

  @BeforeEach
  void registerAndLogin() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"jwt@example.com","password":"password123","displayName":"Jwt"}
                    """))
        .andExpect(status().isCreated());
    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"jwt@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    accessToken = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");
  }

  @Test
  void usersMeWithoutHeaderReturns401() throws Exception {
    mockMvc.perform(get("/api/v1/users/me")).andExpect(status().isUnauthorized());
  }

  @Test
  void usersMeWithInvalidTokenReturns401() throws Exception {
    mockMvc
        .perform(get("/api/v1/users/me").header("Authorization", "Bearer not-a-jwt"))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void usersMeWithExpiredTokenReturns401() throws Exception {
    SecretKey key = Keys.hmacShaKeyFor(signingSecret.getBytes(StandardCharsets.UTF_8));
    Instant now = Instant.now();
    String expired =
        Jwts.builder()
            .subject("someone")
            .claim("email", "jwt@example.com")
            .issuedAt(Date.from(now.minusSeconds(3600)))
            .expiration(Date.from(now.minusSeconds(60)))
            .signWith(key)
            .compact();
    mockMvc
        .perform(get("/api/v1/users/me").header("Authorization", "Bearer " + expired))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void usersMeWithValidTokenReturns200() throws Exception {
    mockMvc
        .perform(get("/api/v1/users/me").header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.uid").isNotEmpty())
        .andExpect(jsonPath("$.email").value("jwt@example.com"));
  }
}
