package com.folio.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

class AdminIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private UserRepository userRepository;
  @Autowired private UserFolioCloudRepository folioCloudRepository;
  @Autowired private UserInkRepository inkRepository;

  @Test
  void grantCloudWithAdminKeyGivesFullFeaturesWithoutStripe() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"email\":\"qa-cloud@example.com\",\"password\":\"password123\",\"displayName\":\"QA\"}"))
        .andExpect(status().isCreated());

    mockMvc
        .perform(
            post("/api/v1/admin/entitlements/grant-cloud")
                .header(AdminGate.HEADER, "test-admin-api-key-for-it")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"email\":\"qa-cloud@example.com\",\"inkDrops\":500,\"alsoStaff\":true}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.adminOverride").value(true))
        .andExpect(jsonPath("$.folioStaff").value(true))
        .andExpect(jsonPath("$.folioCloud.active").value(true));

    var user = userRepository.findByEmailIgnoreCase("qa-cloud@example.com").orElseThrow();
    UserFolioCloudEntity cloud = folioCloudRepository.findById(user.getId()).orElseThrow();
    assertThat(cloud.isAdminOverride()).isTrue();
    assertThat(cloud.isActive()).isTrue();
    assertThat(cloud.getFeatures()).contains("cloudAi");
    assertThat(cloud.getFeatures()).contains("\"plan\"");
    assertThat(cloud.getFeatures()).contains("cloud");
    assertThat(inkRepository.findById(user.getId()).orElseThrow().getPurchasedBalance())
        .isGreaterThanOrEqualTo(BigDecimal.valueOf(500));
  }

  @Test
  void adminWithoutKeyReturns403() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/admin/users/lookup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"nobody@example.com\"}"))
        .andExpect(status().isForbidden());
  }

  @Test
  void revokeCloudClearsOverride() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"email\":\"qa-revoke@example.com\",\"password\":\"password123\",\"displayName\":\"R\"}"))
        .andExpect(status().isCreated());

    mockMvc
        .perform(
            post("/api/v1/admin/entitlements/grant-cloud")
                .header(AdminGate.HEADER, "test-admin-api-key-for-it")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"qa-revoke@example.com\"}"))
        .andExpect(status().isOk());

    mockMvc
        .perform(
            post("/api/v1/admin/entitlements/revoke-cloud")
                .header(AdminGate.HEADER, "test-admin-api-key-for-it")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"qa-revoke@example.com\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.adminOverride").value(false));
  }
}
