package com.folio.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

class AuthRegisterIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private UserRepository userRepository;
  @Autowired private UserFolioCloudRepository folioCloudRepository;
  @Autowired private UserInkRepository inkRepository;
  @Autowired private PasswordEncoder passwordEncoder;

  @Test
  void registerCreatesUserWithArgon2HashAndDefaultRows() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"alice@example.com","password":"password123","displayName":"Alice"}
                    """))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.uid").isNotEmpty())
        .andExpect(jsonPath("$.email").value("alice@example.com"));

    UserEntity user = userRepository.findByEmailIgnoreCase("alice@example.com").orElseThrow();
    assertThat(user.getPasswordHash()).startsWith("$argon2id$");
    assertThat(passwordEncoder.matches("password123", user.getPasswordHash())).isTrue();
    assertThat(folioCloudRepository.findById(user.getId())).isPresent();
    assertThat(inkRepository.findById(user.getId())).isPresent();
  }

  @Test
  void duplicateEmailReturns409() throws Exception {
    String body =
        """
        {"email":"dup@example.com","password":"password123","displayName":"Dup"}
        """;
    mockMvc
        .perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isCreated());
    mockMvc
        .perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isConflict());
  }

  @Test
  void weakPasswordReturns400() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"email":"weak@example.com","password":"short","displayName":"W"}
                    """))
        .andExpect(status().isBadRequest());
  }
}
