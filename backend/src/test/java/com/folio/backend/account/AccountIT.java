package com.folio.backend.account;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class AccountIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private UserFolioCloudRepository folioCloudRepository;
  @Autowired private UserInkRepository inkRepository;

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
                        {"email":"account@example.com","password":"password123","displayName":"  Acc   Name  "}
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
                        {"email":"account@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    accessToken = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");
  }

  @Test
  void accountMeReturnsJoinedShape() throws Exception {
    mockMvc
        .perform(get("/api/v1/account/me").header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.uid").value(uid))
        .andExpect(jsonPath("$.email").value("account@example.com"))
        .andExpect(jsonPath("$.displayName").value("Acc Name"))
        .andExpect(jsonPath("$.folioCloud.active").value(false))
        .andExpect(jsonPath("$.ink.monthlyBalance").value(0))
        .andExpect(jsonPath("$.ink.purchasedBalance").value(0));
  }

  @Test
  void ensureIsIdempotentAndRepairsMissingRows() throws Exception {
    folioCloudRepository.deleteById(uid);
    inkRepository.deleteById(uid);

    mockMvc
        .perform(post("/api/v1/account/ensure").header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.uid").value(uid))
        .andExpect(jsonPath("$.folioCloud").exists())
        .andExpect(jsonPath("$.ink").exists());

    mockMvc
        .perform(post("/api/v1/account/ensure").header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.uid").value(uid));
  }

  @Test
  void displayNameRejectsTooLongAndCollapsesSpaces() throws Exception {
    String tooLong = "x".repeat(81);
    mockMvc
        .perform(
            patch("/api/v1/account/display-name")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"displayName\":\"" + tooLong + "\"}"))
        .andExpect(status().isBadRequest());

    mockMvc
        .perform(
            patch("/api/v1/account/display-name")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"displayName\":\"  New   Name  \"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.displayName").value("New Name"));
  }
}
