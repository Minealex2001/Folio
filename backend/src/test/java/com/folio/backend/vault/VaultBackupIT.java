package com.folio.backend.vault;

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

class VaultBackupIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private TestEntitlements entitlements;

  private String token;
  private String uid;
  private String otherToken;

  @BeforeEach
  void setUp() throws Exception {
    String email = uniqueEmail("vault");
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        "{\"email\":\""
                            + email
                            + "\",\"password\":\"password123\",\"displayName\":\"V\"}"))
            .andExpect(status().isCreated())
            .andReturn();
    uid = JsonPath.read(reg.getResponse().getContentAsString(), "$.uid");
    entitlements.enableBackup(uid);
    token = login(email);

    String email2 = uniqueEmail("vault2");
    mockMvc
        .perform(
            post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"email\":\""
                        + email2
                        + "\",\"password\":\"password123\",\"displayName\":\"O\"}"))
        .andExpect(status().isCreated());
    otherToken = login(email2);
  }

  @Test
  void finalizeMetaListTrimDeleteLifecycle() throws Exception {
    String vaultId = "vault_alpha";
    String snap = "users/" + uid + "/vaults/" + vaultId + "/cloud-packs/snapshots/s1.bin";
    String fp = "abc123";

    mockMvc
        .perform(
            post("/api/v1/vault/backups/cloud-pack/finalize")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"vaultId":"%s","snapshotStoragePath":"%s","snapshotSizeBytes":100,
                     "contentFingerprint":"%s","newBlobs":[{"blobId":"%s","sizeBytes":50}]}
                    """
                        .formatted(
                            vaultId,
                            snap,
                            fp,
                            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true))
        .andExpect(jsonPath("$.usedBytes").value(150));

    mockMvc
        .perform(
            post("/api/v1/vault/backups/cloud-pack/latest-meta")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"vaultId\":\"" + vaultId + "\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.latest.contentFingerprint").value(fp));

    mockMvc
        .perform(
            post("/api/v1/vault/backups/cloud-pack/blobs-exist")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"vaultId\":\""
                        + vaultId
                        + "\",\"blobIds\":[\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"]}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.missing").isArray());

    mockMvc
        .perform(
            post("/api/v1/vault/backups/list")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"vaultId\":\"" + vaultId + "\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.blobs.length()").value(1));

    mockMvc
        .perform(
            post("/api/v1/vault/backups/vaults")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.vaults[0].vaultId").value(vaultId));

    mockMvc
        .perform(
            post("/api/v1/vault/backups/trim-by-bytes")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"targetUsedBytes\":0}"))
        .andExpect(status().isOk());

    mockMvc
        .perform(
            post("/api/v1/vault/backups/usage")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.usedBytes").value(0));
  }

  @Test
  void otherUidGets403() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/vault/backups/cloud-pack/latest-meta")
                .header("Authorization", "Bearer " + otherToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"vaultId\":\"v1\"}"))
        .andExpect(status().isForbidden());
  }

  private String login(String email) throws Exception {
    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"email\":\"" + email + "\",\"password\":\"password123\"}"))
            .andExpect(status().isOk())
            .andReturn();
    return JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");
  }
}
