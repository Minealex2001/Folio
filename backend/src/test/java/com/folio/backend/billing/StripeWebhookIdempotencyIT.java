package com.folio.backend.billing;

import static org.assertj.core.api.Assertions.assertThat;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.StripeWebhookEventRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.math.BigDecimal;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

class StripeWebhookIdempotencyIT extends AbstractIntegrationTest {

  @Autowired private StripeWebhookService webhookService;
  @Autowired private StripeWebhookEventRepository webhookEventRepository;
  @Autowired private UserRepository userRepository;
  @Autowired private UserInkRepository inkRepository;
  @Autowired private PasswordEncoder passwordEncoder;
  @Autowired private BillingService billingService;

  @Test
  void sameEventProcessedTwiceIsNoOp() {
    UserEntity user = new UserEntity();
    user.setId("uid-webhook-1");
    user.setEmail("webhook@example.com");
    user.setDisplayName("W");
    user.setPasswordHash(passwordEncoder.encode("password123"));
    userRepository.save(user);
    inkRepository.save(UserInkEntity.defaultsFor(user.getId()));

    AtomicInteger effectCount = new AtomicInteger();
    Runnable effect =
        () -> {
          effectCount.incrementAndGet();
          billingService.grantPurchasedInk(user.getId(), 100);
        };

    Map<String, Object> first = webhookService.processVerifiedEvent("evt_test_idem_1", effect);
    Map<String, Object> second = webhookService.processVerifiedEvent("evt_test_idem_1", effect);

    assertThat(first.get("received")).isEqualTo(true);
    assertThat(first.containsKey("duplicate")).isFalse();
    assertThat(second.get("duplicate")).isEqualTo(true);
    assertThat(effectCount.get()).isEqualTo(1);
    assertThat(webhookEventRepository.existsById("evt_test_idem_1")).isTrue();
    assertThat(inkRepository.findById(user.getId()).orElseThrow().getPurchasedBalance())
        .isEqualByComparingTo(BigDecimal.valueOf(100));
  }
}
