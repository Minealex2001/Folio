package com.folio.backend.account;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.persistence.entity.PublishedPageEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.repository.PublishedPageRepository;
import com.folio.backend.persistence.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class AccountDeletionIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private UserRepository userRepository;
  @Autowired private PublishedPageRepository publishedPageRepository;

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
                        {"email":"deletion@example.com","password":"password123","displayName":"Delete Me"}
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
                        {"email":"deletion@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    accessToken = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");
  }

  @Test
  void requestDeletionTwiceReturnsSameScheduledFor() throws Exception {
    MvcResult first =
        mockMvc
            .perform(
                post("/api/v1/account/deletion/request")
                    .header("Authorization", "Bearer " + accessToken))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.scheduledFor").exists())
            .andReturn();
    String scheduledFor =
        JsonPath.read(first.getResponse().getContentAsString(), "$.scheduledFor");

    mockMvc
        .perform(
            post("/api/v1/account/deletion/request")
                .header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.scheduledFor").value(scheduledFor));

    UserEntity user = userRepository.findById(uid).orElseThrow();
    assertThat(user.getDeletionRequestedAt()).isNotNull();
    assertThat(user.getDeletionScheduledFor()).isEqualTo(Instant.parse(scheduledFor));
  }

  @Test
  void cancelDeletionBeforeDeadlineClearsColumns() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/account/deletion/request")
                .header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk());

    mockMvc
        .perform(
            post("/api/v1/account/deletion/cancel")
                .header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true));

    UserEntity user = userRepository.findById(uid).orElseThrow();
    assertThat(user.getDeletionRequestedAt()).isNull();
    assertThat(user.getDeletionScheduledFor()).isNull();
  }

  @Test
  void cancelDeletionAfterDeadlineIsRejected() throws Exception {
    UserEntity user = userRepository.findById(uid).orElseThrow();
    user.setDeletionRequestedAt(Instant.now().minus(40, ChronoUnit.DAYS));
    user.setDeletionScheduledFor(Instant.now().minus(1, ChronoUnit.HOURS));
    userRepository.save(user);

    mockMvc
        .perform(
            post("/api/v1/account/deletion/cancel")
                .header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isPreconditionFailed())
        .andExpect(jsonPath("$.error").value("failed_precondition"));
  }

  @Test
  void exportRespectsPublishedPagesLimit() throws Exception {
    for (int i = 0; i < 150; i++) {
      PublishedPageEntity page = new PublishedPageEntity();
      page.setId(UUID.randomUUID());
      page.setOwnerUid(uid);
      page.setStoragePath("published/" + uid + "/page-" + i + ".html");
      publishedPageRepository.save(page);
    }

    MvcResult result =
        mockMvc
            .perform(get("/api/v1/account/export").header("Authorization", "Bearer " + accessToken))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.exportedAt").exists())
            .andExpect(jsonPath("$.data.uid").value(uid))
            .andExpect(jsonPath("$.data.email").value("deletion@example.com"))
            .andReturn();

    int pageCount =
        JsonPath.read(result.getResponse().getContentAsString(), "$.data.publishedPages.length()");
    assertThat(pageCount).isEqualTo(100);
  }
}
