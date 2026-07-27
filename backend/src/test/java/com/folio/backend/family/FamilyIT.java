package com.folio.backend.family;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.persistence.entity.FamilyMemberEntity;
import com.folio.backend.persistence.entity.UserBillingStripeEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.repository.FamilyMemberRepository;
import com.folio.backend.persistence.repository.UserBillingStripeRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

class FamilyIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private UserFolioCloudRepository folioCloudRepository;
  @Autowired private UserBillingStripeRepository stripeBillingRepository;
  @Autowired private FamilyMemberRepository familyMemberRepository;
  @Autowired private FamilyService familyService;

  private String ownerToken;
  private String ownerUid;
  private String memberToken;
  private String memberUid;

  @BeforeEach
  void seed() throws Exception {
    ownerUid = register("owner-fam@example.com", "Owner Fam");
    ownerToken = login("owner-fam@example.com");
    memberUid = register("member-fam@example.com", "Member Fam");
    memberToken = login("member-fam@example.com");

    UserFolioCloudEntity ownerFc =
        folioCloudRepository.findById(ownerUid).orElseThrow();
    ownerFc.setActive(true);
    ownerFc.setSubscriptionStatus("active");
    ownerFc.setSubscriptionPriceId("price_test_family");
    ownerFc.setStudent(false);
    ownerFc.setFeatures(
        "{\"plan\":\"cloud\",\"backup\":true,\"cloudAi\":true,\"publishWeb\":true,\"realtimeCollab\":true}");
    folioCloudRepository.save(ownerFc);

    UserBillingStripeEntity billing = UserBillingStripeEntity.defaultsFor(ownerUid);
    billing.setPriceId("price_test_family");
    billing.setFamilySeats(3);
    billing.setRaw("{\"subscriptionStatus\":\"active\",\"active\":true}");
    stripeBillingRepository.save(billing);
  }

  @Test
  void inviteRemoveAndDetails() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/family/invite")
                .header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"member-fam@example.com\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true));

    assertThat(familyMemberRepository.countByIdFamilyOwnerUid(ownerUid)).isEqualTo(1);
    assertThat(folioCloudRepository.findById(memberUid).orElseThrow().getFamilyOwnerUid())
        .isEqualTo(ownerUid);

    mockMvc
        .perform(get("/api/v1/family/details").header("Authorization", "Bearer " + ownerToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.members[0]").value(memberUid))
        .andExpect(jsonPath("$.membersInfo['" + memberUid + "'].email").value("member-fam@example.com"));

    mockMvc
        .perform(
            post("/api/v1/family/remove")
                .header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"memberUid\":\"" + memberUid + "\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true));

    assertThat(familyMemberRepository.countByIdFamilyOwnerUid(ownerUid)).isEqualTo(0);
    assertThat(folioCloudRepository.findById(memberUid).orElseThrow().getFamilyOwnerUid()).isNull();
  }

  @Test
  void displayNamePropagatesToFamilyMemberSnapshot() throws Exception {
    familyService.invite(
        ownerUid, new com.folio.backend.family.dto.InviteFamilyMemberRequest("member-fam@example.com", false));

    mockMvc
        .perform(
            patch("/api/v1/account/display-name")
                .header("Authorization", "Bearer " + memberToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"displayName\":\"  New   Member  \"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.displayName").value("New Member"));

    FamilyMemberEntity row =
        familyMemberRepository
            .findById(new FamilyMemberEntity.FamilyMemberId(ownerUid, memberUid))
            .orElseThrow();
    assertThat(row.getDisplayNameSnapshot()).isEqualTo("New Member");
  }

  @Test
  void displayNameSucceedsEvenIfPropagationFails() throws Exception {
    // Member not in family — propagation is a no-op; main update still works.
    mockMvc
        .perform(
            patch("/api/v1/account/display-name")
                .header("Authorization", "Bearer " + memberToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"displayName\":\"Solo Name\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.displayName").value("Solo Name"));
  }

  @Test
  void verifyStudentWithAcademicEmail() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/family/verify-student")
                .header("Authorization", "Bearer " + memberToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"pedro@ugr.es\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true))
        .andExpect(jsonPath("$.verified").value(true));

    assertThat(stripeBillingRepository.findById(memberUid).orElseThrow().isStudentVerified())
        .isTrue();
  }

  private String register(String email, String displayName) throws Exception {
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        "{\"email\":\""
                            + email
                            + "\",\"password\":\"password123\",\"displayName\":\""
                            + displayName
                            + "\"}"))
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
