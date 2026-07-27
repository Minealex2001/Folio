package com.folio.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.TestMailConfig.RecordingEmailService;
import com.folio.backend.persistence.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class EmailVerificationIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private RecordingEmailService emailService;
  @Autowired private UserRepository userRepository;

  @BeforeEach
  void clearMail() {
    emailService.clear();
  }

  @Test
  void verifyEmailValidThenReuseFails() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"verify@example.com","password":"password123","displayName":"Verify"}
                    """))
        .andExpect(status().isCreated());

    String token = emailService.lastVerificationToken();
    assertThat(token).isNotBlank();

    mockMvc
        .perform(
            post("/api/v1/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"" + token + "\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true));

    assertThat(userRepository.findByEmailIgnoreCase("verify@example.com").orElseThrow().getEmailVerifiedAt())
        .isNotNull();

    mockMvc
        .perform(
            post("/api/v1/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"" + token + "\"}"))
        .andExpect(status().isBadRequest());
  }

  @Test
  void expiredTokenReturns400() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"totally-unknown-token\"}"))
        .andExpect(status().isBadRequest());
  }

  @Test
  void resendVerificationRequiresAuthAndIssuesNewToken() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"resend@example.com","password":"password123","displayName":"Resend"}
                    """))
        .andExpect(status().isCreated());
    String first = emailService.lastVerificationToken();

    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"resend@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    String access = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");

    mockMvc.perform(post("/api/v1/auth/resend-verification")).andExpect(status().isUnauthorized());

    mockMvc
        .perform(post("/api/v1/auth/resend-verification").header("Authorization", "Bearer " + access))
        .andExpect(status().isOk());

    String second = emailService.lastVerificationToken();
    assertThat(second).isNotBlank().isNotEqualTo(first);
  }
}
