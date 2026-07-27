package com.folio.backend.vault;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.TestEntitlements;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class DeviceSyncIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private TestEntitlements entitlements;
  @Autowired private DeviceSyncService deviceSyncService;

  private String token;
  private String uid;

  @BeforeEach
  void setUp() throws Exception {
    String email = uniqueEmail("sync");
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        "{\"email\":\""
                            + email
                            + "\",\"password\":\"password123\",\"displayName\":\"S\"}"))
            .andExpect(status().isCreated())
            .andReturn();
    uid = JsonPath.read(reg.getResponse().getContentAsString(), "$.uid");
    entitlements.enableBackup(uid);
    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"email\":\"" + email + "\",\"password\":\"password123\"}"))
            .andExpect(status().isOk())
            .andReturn();
    token = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");
  }

  @Test
  void finalizeV1ThenV2AdjustsQuota() throws Exception {
    String vaultId = "sync_v";
    String pack = "users/" + uid + "/vaults/" + vaultId + "/device-sync/packs/p1.bin";
    mockMvc
        .perform(
            post("/api/v1/vault/device-sync/finalize")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"vaultId":"%s","syncFormatVersion":1,"contentFingerprint":"aa",
                     "packStoragePath":"%s","packSizeBytes":1000}
                    """
                        .formatted(vaultId, pack)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.syncFormatVersion").value(1))
        .andExpect(jsonPath("$.usedBytes").value(1000));

    String manifest = "users/" + uid + "/vaults/" + vaultId + "/device-sync/manifests/m1.bin";
    mockMvc
        .perform(
            post("/api/v1/vault/device-sync/finalize")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"vaultId":"%s","syncFormatVersion":2,"contentFingerprint":"bb",
                     "manifestStoragePath":"%s","manifestSizeBytes":200,
                     "oldPackStoragePath":"%s","oldPackSizeBytes":1000}
                    """
                        .formatted(vaultId, manifest, pack)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.syncFormatVersion").value(2))
        .andExpect(jsonPath("$.usedBytes").value(200));
  }

  @Test
  void ensurePlainSecretIsIdempotent() {
    String vaultId = "plain_v";
    String first = (String) deviceSyncService.ensurePlainVaultSyncSecret(uid, vaultId).get("secret");
    String second = (String) deviceSyncService.ensurePlainVaultSyncSecret(uid, vaultId).get("secret");
    assertThat(first).isEqualTo(second).isNotBlank();
  }
}
