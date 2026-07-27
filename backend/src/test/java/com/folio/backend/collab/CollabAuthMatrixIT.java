package com.folio.backend.collab;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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

class CollabAuthMatrixIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private TestEntitlements entitlements;

  private String ownerToken;
  private String ownerUid;
  private String outsiderToken;

  @BeforeEach
  void setUp() throws Exception {
    String e1 = uniqueEmail("collab-owner");
    ownerUid = register(e1);
    entitlements.enableCollab(ownerUid);
    ownerToken = login(e1);

    String e2 = uniqueEmail("collab-out");
    String outUid = register(e2);
    entitlements.enableCollab(outUid);
    outsiderToken = login(e2);
  }

  @Test
  void authMatrixCreateJoinUpdateMediaClose() throws Exception {
    MvcResult created =
        mockMvc
            .perform(
                post("/api/v1/collab/rooms")
                    .header("Authorization", "Bearer " + ownerToken)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"vaultPageId\":\"page1\"}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.roomId").exists())
            .andReturn();
    String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId");
    String joinCode = JsonPath.read(created.getResponse().getContentAsString(), "$.joinCode");

    mockMvc
        .perform(get("/api/v1/collab/rooms/" + roomId).header("Authorization", "Bearer " + outsiderToken))
        .andExpect(status().isForbidden());

    mockMvc
        .perform(
            put("/api/v1/collab/rooms/" + roomId)
                .header("Authorization", "Bearer " + outsiderToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"contentCipher\":\"cipher\",\"contentVersion\":1,\"updatedBy\":\"x\",\"changedKeys\":[\"contentCipher\",\"contentVersion\",\"updatedAt\",\"updatedBy\"]}"))
        .andExpect(status().isForbidden());

    mockMvc
        .perform(
            post("/api/v1/collab/rooms/join")
                .header("Authorization", "Bearer " + outsiderToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"joinCode\":\"" + joinCode + "\"}"))
        .andExpect(status().isOk());

    // e2e seal pending: member cannot seal (owner only)
    mockMvc
        .perform(
            put("/api/v1/collab/rooms/" + roomId)
                .header("Authorization", "Bearer " + outsiderToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"wrappedRoomKey\":\"abcdefghijklmnopqrstuvwx\",\"contentCipher\":\"c\",\"contentVersion\":1,\"updatedBy\":\"x\",\"changedKeys\":[\"wrappedRoomKey\",\"contentCipher\",\"contentVersion\",\"updatedAt\",\"updatedBy\"]}"))
        .andExpect(status().isForbidden());

    mockMvc
        .perform(
            put("/api/v1/collab/rooms/" + roomId)
                .header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"wrappedRoomKey\":\"abcdefghijklmnopqrstuvwx\",\"contentCipher\":\"cipher1\",\"contentVersion\":1,\"updatedBy\":\""
                        + ownerUid
                        + "\",\"changedKeys\":[\"wrappedRoomKey\",\"contentCipher\",\"contentVersion\",\"updatedAt\",\"updatedBy\"]}"))
        .andExpect(status().isOk());

    // illegal field after seal
    mockMvc
        .perform(
            put("/api/v1/collab/rooms/" + roomId)
                .header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"wrappedRoomKey\":\"changed\",\"contentCipher\":\"c2\",\"contentVersion\":2,\"changedKeys\":[\"wrappedRoomKey\",\"contentCipher\",\"contentVersion\"]}"))
        .andExpect(status().isForbidden());

    mockMvc
        .perform(
            post("/api/v1/collab/rooms/" + roomId + "/media/prepare")
                .header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"blockId\":\"b1\",\"mediaKind\":\"image\",\"sizeBytes\":100}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.uploadUrl").exists());

    mockMvc
        .perform(
            post("/api/v1/collab/rooms/" + roomId + "/media/prepare")
                .header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"blockId\":\"b1\",\"mediaKind\":\"image\",\"sizeBytes\":"
                        + (CollabService.MEDIA_MAX_BYTES + 1)
                        + "}"))
        .andExpect(status().isBadRequest());

    mockMvc
        .perform(
            post("/api/v1/collab/rooms/" + roomId + "/close")
                .header("Authorization", "Bearer " + ownerToken))
        .andExpect(status().isOk());
  }

  private String register(String email) throws Exception {
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        "{\"email\":\""
                            + email
                            + "\",\"password\":\"password123\",\"displayName\":\"C\"}"))
            .andExpect(status().isCreated())
            .andReturn();
    return JsonPath.read(reg.getResponse().getContentAsString(), "$.uid");
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
