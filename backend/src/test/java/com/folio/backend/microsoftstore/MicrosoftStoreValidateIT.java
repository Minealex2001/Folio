package com.folio.backend.microsoftstore;

import static org.assertj.core.api.Assertions.assertThat;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.MicrosoftStoreProcessedPurchaseRepository;
import com.folio.backend.persistence.repository.UserBillingMicrosoftStoreRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.math.BigDecimal;
import java.util.Map;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

class MicrosoftStoreValidateIT extends AbstractIntegrationTest {

  @Autowired private MicrosoftStoreService microsoftStoreService;
  @Autowired private MicrosoftStoreProperties properties;
  @Autowired private UserRepository userRepository;
  @Autowired private UserInkRepository inkRepository;
  @Autowired private UserBillingMicrosoftStoreRepository msBillingRepository;
  @Autowired private MicrosoftStoreProcessedPurchaseRepository purchaseRepository;
  @Autowired private PasswordEncoder passwordEncoder;

  private MockWebServer server;

  @BeforeEach
  void startServer() throws Exception {
    server = new MockWebServer();
    server.start();
    String base = server.url("/").toString().replaceAll("/$", "");
    properties.setTokenUrlTemplate(base + "/oauth2/v2.0/token");
    properties.setCollectionsQueryUrl(base + "/v6.0/collections/query");
  }

  @AfterEach
  void stopServer() throws Exception {
    server.shutdown();
  }

  @Test
  void firstValidateGrantsInkSecondIsNoOp() {
    UserEntity user = new UserEntity();
    user.setId("uid-ms-1");
    user.setEmail("ms@example.com");
    user.setDisplayName("MS");
    user.setPasswordHash(passwordEncoder.encode("password123"));
    userRepository.save(user);
    inkRepository.save(UserInkEntity.defaultsFor(user.getId()));

    String itemsJson =
        """
        {"Items":[{"ProductId":"9NTESTINKSMALL","SkuId":"sku1","quantity":1,"State":"Active","OrderManagementData":{"OrderId":"order-abc-1"}}]}
        """;

    enqueueTokenAndItems(itemsJson);
    Map<String, Object> first =
        microsoftStoreService.validate(user.getId(), "collections-id-1");
    assertThat(first.get("ok")).isEqualTo(true);
    assertThat(first.get("storeItems")).isEqualTo(1);
    assertThat(inkRepository.findById(user.getId()).orElseThrow().getPurchasedBalance())
        .isEqualByComparingTo(BigDecimal.valueOf(300));
    assertThat(purchaseRepository.count()).isEqualTo(1);

    enqueueTokenAndItems(itemsJson);
    microsoftStoreService.validate(user.getId(), "collections-id-1");
    assertThat(inkRepository.findById(user.getId()).orElseThrow().getPurchasedBalance())
        .isEqualByComparingTo(BigDecimal.valueOf(300));
    assertThat(purchaseRepository.count()).isEqualTo(1);
    assertThat(msBillingRepository.findById(user.getId()).orElseThrow().getLastItemCount())
        .isEqualTo(1);
  }

  private void enqueueTokenAndItems(String itemsJson) {
    server.enqueue(
        new MockResponse()
            .setBody("{\"access_token\":\"tok-test\"}")
            .addHeader("Content-Type", "application/json"));
    server.enqueue(
        new MockResponse().setBody(itemsJson).addHeader("Content-Type", "application/json"));
  }
}
