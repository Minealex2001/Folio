package com.folio.backend.published;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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

class PublishedPagesIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private TestEntitlements entitlements;

  private String token;
  private String uid;
  private String otherToken;

  @BeforeEach
  void setUp() throws Exception {
    String email = uniqueEmail("pub");
    uid = register(email);
    entitlements.enablePublish(uid);
    token = login(email);
    String email2 = uniqueEmail("pub2");
    register(email2);
    otherToken = login(email2);
  }

  @Test
  void publishRequiresPlanFlagAndOwnerOnly() throws Exception {
    String path = "published/" + uid + "/page.html";
    mockMvc
        .perform(
            post("/api/v1/published-pages")
                .header("Authorization", "Bearer " + otherToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"storagePath\":\"published/x/page.html\"}"))
        .andExpect(status().isForbidden());

    MvcResult created =
        mockMvc
            .perform(
                post("/api/v1/published-pages")
                    .header("Authorization", "Bearer " + token)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"storagePath\":\"" + path + "\"}"))
            .andExpect(status().isCreated())
            .andReturn();
    String id = JsonPath.read(created.getResponse().getContentAsString(), "$.id");

    mockMvc.perform(get("/api/v1/published-pages/" + id)).andExpect(status().isOk());

    mockMvc
        .perform(
            put("/api/v1/published-pages/" + id)
                .header("Authorization", "Bearer " + otherToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"storagePath\":\"" + path + "\"}"))
        .andExpect(status().isForbidden());

    mockMvc
        .perform(delete("/api/v1/published-pages/" + id).header("Authorization", "Bearer " + token))
        .andExpect(status().isNoContent());
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
                            + "\",\"password\":\"password123\",\"displayName\":\"P\"}"))
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
