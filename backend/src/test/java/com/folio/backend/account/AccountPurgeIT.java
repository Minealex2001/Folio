package com.folio.backend.account;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.billing.StripeApiClient;
import com.folio.backend.config.StorageProperties;
import com.folio.backend.integrations.IntegrationUserIndexEntity;
import com.folio.backend.integrations.IntegrationUserIndexRepository;
import com.folio.backend.persistence.entity.CollabRoomEntity;
import com.folio.backend.persistence.entity.CollabRoomMemberEntity;
import com.folio.backend.persistence.entity.CommunityTemplateEntity;
import com.folio.backend.persistence.entity.FamilyEntity;
import com.folio.backend.persistence.entity.FamilyMemberEntity;
import com.folio.backend.persistence.entity.PublishedPageEntity;
import com.folio.backend.persistence.entity.UserBillingStripeEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.repository.CollabRoomMemberRepository;
import com.folio.backend.persistence.repository.CollabRoomRepository;
import com.folio.backend.persistence.repository.CommunityTemplateRepository;
import com.folio.backend.persistence.repository.FamilyMemberRepository;
import com.folio.backend.persistence.repository.FamilyRepository;
import com.folio.backend.persistence.repository.PublishedPageRepository;
import com.folio.backend.persistence.repository.UserBillingStripeRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserRepository;
import com.folio.backend.storage.StorageService;
import com.jayway.jsonpath.JsonPath;
import com.stripe.model.Subscription;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;

class AccountPurgeIT extends AbstractIntegrationTest {

  private static final AtomicBoolean MINIO_READY = new AtomicBoolean(false);

  @Autowired private MockMvc mockMvc;
  @Autowired private AccountDeletionService accountDeletionService;
  @Autowired private UserRepository userRepository;
  @Autowired private UserFolioCloudRepository folioCloudRepository;
  @Autowired private UserBillingStripeRepository stripeBillingRepository;
  @Autowired private FamilyRepository familyRepository;
  @Autowired private FamilyMemberRepository familyMemberRepository;
  @Autowired private CollabRoomRepository collabRoomRepository;
  @Autowired private CollabRoomMemberRepository collabRoomMemberRepository;
  @Autowired private PublishedPageRepository publishedPageRepository;
  @Autowired private CommunityTemplateRepository communityTemplateRepository;
  @Autowired private IntegrationUserIndexRepository integrationUserIndexRepository;
  @Autowired private StorageService storageService;
  @Autowired private S3Client s3Client;
  @Autowired private StorageProperties storageProperties;

  @MockBean private StripeApiClient stripeApi;

  private String ownerUid;
  private String member1Uid;
  private String member2Uid;
  private String otherOwnerUid;
  private UUID ownedRoom1;
  private UUID ownedRoom2;
  private UUID otherRoomId;

  @BeforeAll
  static void ensureMinio() {
    try {
      ensureComposeMinio();
      MINIO_READY.set(true);
    } catch (Exception e) {
      System.err.println("MinIO unavailable for AccountPurgeIT: " + e.getMessage());
      MINIO_READY.set(false);
    }
  }

  @BeforeEach
  void seed() throws Exception {
    when(stripeApi.isConfigured(anyBoolean())).thenReturn(true);

    ownerUid = register("purge-owner@example.com", "Purge Owner");
    member1Uid = register("purge-m1@example.com", "Member One");
    member2Uid = register("purge-m2@example.com", "Member Two");
    otherOwnerUid = register("purge-other@example.com", "Other Owner");

    UserEntity owner = userRepository.findById(ownerUid).orElseThrow();
    owner.setStripeCustomerId("cus_purge_test");
    userRepository.save(owner);

    UserFolioCloudEntity ownerFc = folioCloudRepository.findById(ownerUid).orElseThrow();
    ownerFc.setActive(true);
    ownerFc.setSubscriptionStatus("active");
    ownerFc.setSubscriptionPriceId("price_test_family");
    folioCloudRepository.save(ownerFc);

    UserBillingStripeEntity billing = UserBillingStripeEntity.defaultsFor(ownerUid);
    billing.setPriceId("price_test_family");
    billing.setFamilySeats(3);
    stripeBillingRepository.save(billing);

    FamilyEntity family = new FamilyEntity();
    family.setOwnerUid(ownerUid);
    familyRepository.save(family);
    addFamilyMember(ownerUid, member1Uid);
    addFamilyMember(ownerUid, member2Uid);

    ownedRoom1 = createRoom(ownerUid, "owned-1");
    ownedRoom2 = createRoom(ownerUid, "owned-2");
    otherRoomId = createRoom(otherOwnerUid, "other-room");
    CollabRoomMemberEntity membership = new CollabRoomMemberEntity();
    membership.setRoomId(otherRoomId);
    membership.setMemberUid(ownerUid);
    collabRoomMemberRepository.save(membership);

    for (int i = 0; i < 3; i++) {
      PublishedPageEntity page = new PublishedPageEntity();
      page.setId(UUID.randomUUID());
      page.setOwnerUid(ownerUid);
      page.setStoragePath("published/" + ownerUid + "/p" + i + ".html");
      publishedPageRepository.save(page);
    }
    for (int i = 0; i < 2; i++) {
      CommunityTemplateEntity tpl = new CommunityTemplateEntity();
      tpl.setId(UUID.randomUUID());
      tpl.setOwnerUid(ownerUid);
      tpl.setName("Template " + i);
      tpl.setBlockCount(1);
      tpl.setStoragePath("community-templates/" + ownerUid + "/t" + i + ".folio-template");
      tpl.setStorageDownloadUrl("https://example.com/t" + i);
      communityTemplateRepository.save(tpl);
    }

    IntegrationUserIndexEntity idx = new IntegrationUserIndexEntity();
    idx.setId("slack:" + ownerUid);
    idx.setUserId(ownerUid);
    idx.setProvider("slack");
    idx.setExternalUserId("U123");
    integrationUserIndexRepository.save(idx);

    if (MINIO_READY.get()) {
      ensureBucket();
      storageService.putBytes(
          "users/" + ownerUid + "/backups/a.bin",
          "a".getBytes(StandardCharsets.UTF_8),
          "application/octet-stream");
      storageService.putBytes(
          "published/" + ownerUid + "/p0.html",
          "html".getBytes(StandardCharsets.UTF_8),
          "text/html");
      storageService.putBytes(
          "community-templates/" + ownerUid + "/t0.folio-template",
          "tpl".getBytes(StandardCharsets.UTF_8),
          "application/octet-stream");
      storageService.putBytes(
          "collab-media-e2e/" + ownedRoom1 + "/m1.bin",
          "m".getBytes(StandardCharsets.UTF_8),
          "application/octet-stream");
    }
  }

  @Test
  void purgeCascadesStripeFamilyRoomsPagesTemplatesAndStorage() {
    Assumptions.assumeTrue(MINIO_READY.get(), "MinIO required for full purge cascade");

    Subscription sub = mock(Subscription.class);
    when(sub.getId()).thenReturn("sub_active_1");
    when(sub.getStatus()).thenReturn("active");
    try {
      when(stripeApi.listSubscriptions(eq(false), eq("cus_purge_test"))).thenReturn(List.of(sub));
    } catch (Exception e) {
      throw new RuntimeException(e);
    }

    accountDeletionService.purgeUserAccount(ownerUid);

    try {
      verify(stripeApi).listSubscriptions(false, "cus_purge_test");
      verify(stripeApi).cancelSubscription(false, "sub_active_1");
      verify(stripeApi).deleteCustomer(false, "cus_purge_test");
    } catch (Exception e) {
      throw new RuntimeException(e);
    }

    assertThat(userRepository.findById(ownerUid)).isEmpty();
    assertThat(familyRepository.findById(ownerUid)).isEmpty();
    assertThat(familyMemberRepository.findByIdFamilyOwnerUid(ownerUid)).isEmpty();
    assertThat(folioCloudRepository.findById(member1Uid).orElseThrow().getFamilyOwnerUid())
        .isNull();
    assertThat(folioCloudRepository.findById(member2Uid).orElseThrow().getFamilyOwnerUid())
        .isNull();

    assertThat(collabRoomRepository.findById(ownedRoom1)).isEmpty();
    assertThat(collabRoomRepository.findById(ownedRoom2)).isEmpty();
    assertThat(collabRoomRepository.findById(otherRoomId)).isPresent();
    assertThat(collabRoomMemberRepository.existsByRoomIdAndMemberUid(otherRoomId, ownerUid))
        .isFalse();

    assertThat(publishedPageRepository.findByOwnerUidOrderByUpdatedAtDesc(ownerUid)).isEmpty();
    assertThat(communityTemplateRepository.findByOwnerUidOrderByUpdatedAtDesc(ownerUid)).isEmpty();
    assertThat(integrationUserIndexRepository.findByUserId(ownerUid)).isEmpty();

    assertThat(storageService.listKeys("users/" + ownerUid + "/")).isEmpty();
    assertThat(storageService.listKeys("published/" + ownerUid + "/")).isEmpty();
    assertThat(storageService.listKeys("community-templates/" + ownerUid + "/")).isEmpty();
    assertThat(storageService.listKeys("collab-media-e2e/" + ownedRoom1 + "/")).isEmpty();
  }

  @Test
  void purgeContinuesWhenStripeFails() {
    try {
      when(stripeApi.listSubscriptions(anyBoolean(), anyString()))
          .thenThrow(new RuntimeException("stripe down"));
      doThrow(new RuntimeException("delete failed"))
          .when(stripeApi)
          .deleteCustomer(anyBoolean(), anyString());
    } catch (Exception e) {
      throw new RuntimeException(e);
    }

    accountDeletionService.purgeUserAccount(ownerUid);

    assertThat(userRepository.findById(ownerUid)).isEmpty();
    assertThat(familyRepository.findById(ownerUid)).isEmpty();
    assertThat(collabRoomRepository.findById(ownedRoom1)).isEmpty();
    assertThat(publishedPageRepository.findByOwnerUidOrderByUpdatedAtDesc(ownerUid)).isEmpty();
    assertThat(integrationUserIndexRepository.findByUserId(ownerUid)).isEmpty();
    assertThat(folioCloudRepository.findById(member1Uid).orElseThrow().getFamilyOwnerUid())
        .isNull();

    try {
      verify(stripeApi, atLeastOnce()).listSubscriptions(eq(false), eq("cus_purge_test"));
      verify(stripeApi, never()).cancelSubscription(anyBoolean(), anyString());
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  @Test
  void scheduledJobPurgesDueUsers() {
    UserEntity owner = userRepository.findById(ownerUid).orElseThrow();
    owner.setDeletionScheduledFor(java.time.Instant.now().minusSeconds(60));
    userRepository.save(owner);

    when(stripeApi.isConfigured(anyBoolean())).thenReturn(false);

    accountDeletionService.processScheduledAccountDeletions();

    assertThat(userRepository.findById(ownerUid)).isEmpty();
    assertThat(userRepository.findById(member1Uid)).isPresent();
  }

  private void addFamilyMember(String owner, String member) {
    UserFolioCloudEntity fc = folioCloudRepository.findById(member).orElseThrow();
    fc.setFamilyOwnerUid(owner);
    folioCloudRepository.save(fc);
    FamilyMemberEntity row = new FamilyMemberEntity();
    row.setId(new FamilyMemberEntity.FamilyMemberId(owner, member));
    row.setEmailSnapshot(member + "@x");
    row.setDisplayNameSnapshot("M");
    familyMemberRepository.save(row);
  }

  private UUID createRoom(String owner, String pageId) {
    CollabRoomEntity room = new CollabRoomEntity();
    room.setId(UUID.randomUUID());
    room.setOwnerUid(owner);
    room.setVaultPageId(pageId);
    room.setJoinCodeKey("key-" + pageId + "-" + UUID.randomUUID().toString().substring(0, 8));
    room.setJoinCode("CODE");
    room.setE2eV((short) 1);
    room.setContentVersion(0);
    return collabRoomRepository.save(room).getId();
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

  private void ensureBucket() {
    try {
      s3Client.headBucket(HeadBucketRequest.builder().bucket(storageProperties.bucket()).build());
    } catch (Exception e) {
      s3Client.createBucket(
          CreateBucketRequest.builder().bucket(storageProperties.bucket()).build());
    }
  }

  private static void ensureComposeMinio() throws Exception {
    java.io.File dir = backendDirStatic();
    ProcessBuilder pb =
        new ProcessBuilder("docker", "compose", "-f", "docker-compose.yml", "up", "-d", "minio");
    pb.directory(dir);
    pb.redirectErrorStream(true);
    Process p = pb.start();
    p.getInputStream().readAllBytes();
    if (p.waitFor() != 0) {
      throw new IllegalStateException("docker compose up minio failed");
    }
    for (int i = 0; i < 40; i++) {
      try {
        HttpClient client = HttpClient.newHttpClient();
        HttpResponse<String> r =
            client.send(
                HttpRequest.newBuilder(URI.create("http://localhost:9000/minio/health/live"))
                    .GET()
                    .timeout(Duration.ofSeconds(2))
                    .build(),
                HttpResponse.BodyHandlers.ofString());
        if (r.statusCode() == 200) {
          return;
        }
      } catch (Exception ignored) {
      }
      Thread.sleep(500);
    }
    throw new IllegalStateException("MinIO not ready");
  }

  private static java.io.File backendDirStatic() {
    java.io.File cwd = new java.io.File(System.getProperty("user.dir"));
    if (new java.io.File(cwd, "docker-compose.yml").isFile()) {
      return cwd;
    }
    java.io.File nested = new java.io.File(cwd, "backend/docker-compose.yml");
    if (nested.isFile()) {
      return nested.getParentFile();
    }
    throw new IllegalStateException("Cannot locate docker-compose.yml");
  }
}
