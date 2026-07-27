package com.folio.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class AuthLoginIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private JwtService jwtService;

  @BeforeEach
  void registerUser() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"login@example.com","password":"password123","displayName":"Login"}
                    """))
        .andExpect(status().isCreated());
  }

  @Test
  void loginReturnsJwtWithCorrectSubject() throws Exception {
    MvcResult result =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"login@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.accessToken").isNotEmpty())
            .andExpect(jsonPath("$.refreshToken").isNotEmpty())
            .andExpect(jsonPath("$.expiresIn").value(900))
            .andExpect(jsonPath("$.tokenType").value("Bearer"))
            .andReturn();

    String access = JsonPath.read(result.getResponse().getContentAsString(), "$.accessToken");
    Claims claims = jwtService.parseValidClaims(access);
    assertThat(claims.getSubject()).isNotBlank();
    assertThat(claims.get("email", String.class)).isEqualTo("login@example.com");
  }

  @Test
  void wrongPasswordAndUnknownEmailReturnSame401() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"login@example.com","password":"wrong-password"}
                    """))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error").value("invalid_credentials"));

    mockMvc
        .perform(
            post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"nobody@example.com","password":"password123"}
                    """))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error").value("invalid_credentials"));
  }
}
