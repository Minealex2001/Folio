package com.folio.backend.community;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.storage.StoragePathAuthorizer;
import com.jayway.jsonpath.JsonPath;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class CommunityTemplatesIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;

  private String token;
  private String uid;

  @BeforeEach
  void setUp() throws Exception {
    String email = uniqueEmail("tpl");
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        "{\"email\":\""
                            + email
                            + "\",\"password\":\"password123\",\"displayName\":\"T\"}"))
            .andExpect(status().isCreated())
            .andReturn();
    uid = JsonPath.read(reg.getResponse().getContentAsString(), "$.uid");
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
  void createOkConstraintsAndLifecycle() throws Exception {
    String id = UUID.randomUUID().toString();
    String path = "community-templates/" + uid + "/" + id + ".folio-template";

    mockMvc
        .perform(
            post("/api/v1/community-templates")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"id\":\""
                        + id
                        + "\",\"name\":\""
                        + "n".repeat(281)
                        + "\",\"blockCount\":1,\"storagePath\":\""
                        + path
                        + "\",\"storageDownloadUrl\":\"https://x\"}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("invalid_name"));

    mockMvc
        .perform(
            post("/api/v1/community-templates")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"id\":\""
                        + id
                        + "\",\"name\":\"ok\",\"blockCount\":50001,\"storagePath\":\""
                        + path
                        + "\",\"storageDownloadUrl\":\"https://x\"}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("invalid_blockCount"));

    mockMvc
        .perform(
            post("/api/v1/community-templates")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"id\":\""
                        + id
                        + "\",\"name\":\"ok\",\"blockCount\":1,\"storagePath\":\""
                        + path
                        + "\",\"storageDownloadUrl\":\"https://x\",\"sizeBytes\":"
                        + StoragePathAuthorizer.COMMUNITY_TEMPLATE_MAX_BYTES
                        + "}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("invalid_sizeBytes"));

    mockMvc
        .perform(
            post("/api/v1/community-templates")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"id\":\""
                        + id
                        + "\",\"name\":\"My tpl\",\"blockCount\":3,\"storagePath\":\""
                        + path
                        + "\",\"storageDownloadUrl\":\"https://cdn.example/tpl\",\"sizeBytes\":100}"))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.name").value("My tpl"));

    mockMvc.perform(get("/api/v1/community-templates/" + id)).andExpect(status().isOk());
    mockMvc.perform(get("/api/v1/community-templates")).andExpect(status().isOk());

    mockMvc
        .perform(
            delete("/api/v1/community-templates/" + id).header("Authorization", "Bearer " + token))
        .andExpect(status().isNoContent());
  }
}
