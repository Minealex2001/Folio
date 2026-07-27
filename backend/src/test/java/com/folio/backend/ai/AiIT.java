package com.folio.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.jayway.jsonpath.JsonPath;
import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class AiIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private UserInkRepository inkRepository;
  @MockBean private OpenAiClient openAiClient;

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
                        {"email":"ai@example.com","password":"password123","displayName":"AI User"}
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
                        {"email":"ai@example.com","password":"password123"}
                        """))
            .andExpect(status().isOk())
            .andReturn();
    accessToken = JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");

    UserInkEntity ink = inkRepository.findById(uid).orElseThrow();
    ink.setPurchasedBalance(BigDecimal.valueOf(50));
    ink.setMonthlyBalance(BigDecimal.ZERO);
    inkRepository.save(ink);
  }

  @Test
  void pricingRequiresAuthAndReturnsTable() throws Exception {
    mockMvc.perform(get("/api/v1/ai/pricing")).andExpect(status().isUnauthorized());

    mockMvc
        .perform(get("/api/v1/ai/pricing").header("Authorization", "Bearer " + accessToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.costByOperation.rewrite_block").value(3))
        .andExpect(jsonPath("$.inkMaxPerRequest").value(16));
  }

  @Test
  void completeDebitsInkOnSuccess() throws Exception {
    when(openAiClient.chatCompletion(any()))
        .thenReturn(new OpenAiClient.ChatResult("hello", 100, null));

    mockMvc
        .perform(
            post("/api/v1/ai/complete")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"prompt":"Say hi","operationKind":"rewrite_block"}
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.text").value("hello"))
        .andExpect(jsonPath("$.inkBaseCharged").value(3))
        .andExpect(jsonPath("$.ink.purchasedBalance").value(47));

    UserInkEntity ink = inkRepository.findById(uid).orElseThrow();
    assertThat(ink.getPurchasedBalance().intValue()).isEqualTo(47);
  }

  @Test
  void completeRefundsInkOnFailure() throws Exception {
    when(openAiClient.chatCompletion(any()))
        .thenThrow(new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "provider down"));

    mockMvc
        .perform(
            post("/api/v1/ai/complete")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"prompt":"Say hi","operationKind":"rewrite_block"}
                    """))
        .andExpect(status().isInternalServerError());

    UserInkEntity ink = inkRepository.findById(uid).orElseThrow();
    assertThat(ink.getPurchasedBalance().intValue()).isEqualTo(50);
  }

  @Test
  void transcribeDebitsAndRefundsOnFailure() throws Exception {
    when(openAiClient.transcribe(any(), any()))
        .thenThrow(new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "fail"));

    mockMvc
        .perform(
            post("/api/v1/ai/transcribe")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"audioBase64":"AQID","chargeInk":true}
                    """))
        .andExpect(status().isInternalServerError());

    UserInkEntity ink = inkRepository.findById(uid).orElseThrow();
    assertThat(ink.getPurchasedBalance().intValue()).isEqualTo(50);
  }

  @Test
  void transcribeSuccessDebitsTranscribeCost() throws Exception {
    when(openAiClient.transcribe(any(), any()))
        .thenReturn(new OpenAiClient.TranscribeResult("Speaker 1: hi"));

    mockMvc
        .perform(
            post("/api/v1/ai/transcribe")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"audioBase64":"AQID","chargeInk":true}
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.transcript").value("Speaker 1: hi"))
        .andExpect(jsonPath("$.ink.purchasedBalance").value(48));
  }
}
