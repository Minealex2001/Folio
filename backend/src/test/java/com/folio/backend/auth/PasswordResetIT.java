package com.folio.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.TestMailConfig.RecordingEmailService;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class PasswordResetIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private RecordingEmailService emailService;

  @BeforeEach
  void clearMail() {
    emailService.clear();
  }

  @Test
  void unknownEmailStillReturns200AndSendsNothing() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"ghost@example.com\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true));
    assertThat(emailService.sent()).isEmpty();
    assertThat(emailService.lastResetToken()).isNull();
  }

  @Test
  void resetPasswordChangesHashRevokesRefreshAndRejectsReuse() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"reset@example.com","password":"password123","displayName":"Reset"}
                    """))
        .andExpect(status().isCreated());

    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """
                        {"email":"reset@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    String refresh = JsonPath.read(login.getResponse().getContentAsString(), "$.refreshToken");

    mockMvc
        .perform(
            post("/api/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"reset@example.com\"}"))
        .andExpect(status().isOk());

    String token = emailService.lastResetToken();
    assertThat(token).isNotBlank();

    mockMvc
        .perform(
            post("/api/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"token\":\"" + token + "\",\"newPassword\":\"newpassword99\"}"))
        .andExpect(status().isOk());

    mockMvc
        .perform(
            post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"reset@example.com","password":"password123"}
                    """))
        .andExpect(status().isUnauthorized());

    mockMvc
        .perform(
            post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"reset@example.com","password":"newpassword99"}
                    """))
        .andExpect(status().isOk());

    mockMvc
        .perform(
            post("/api/v1/auth/refresh")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + refresh + "\"}"))
        .andExpect(status().isUnauthorized());

    mockMvc
        .perform(
            post("/api/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"token\":\"" + token + "\",\"newPassword\":\"anotherpassword\"}"))
        .andExpect(status().isBadRequest());
  }
}
