package com.folio.backend.ink;

import static org.assertj.core.api.Assertions.assertThat;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.billing.FolioCloudEntitlementService;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

class MonthlyInkRefillIT extends AbstractIntegrationTest {

  @Autowired private MonthlyInkRefillJob job;
  @Autowired private UserRepository userRepository;
  @Autowired private UserFolioCloudRepository folioCloudRepository;
  @Autowired private UserInkRepository inkRepository;
  @Autowired private PasswordEncoder passwordEncoder;

  @Test
  void onlyEligibleSubscriberIsRefilled() {
    UserEntity eligible = saveUser("uid-ink-eligible", "eligible@example.com");
    UserEntity ineligible = saveUser("uid-ink-ineligible", "ineligible@example.com");

    UserFolioCloudEntity eCloud = UserFolioCloudEntity.defaultsFor(eligible.getId());
    eCloud.setActive(true);
    eCloud.setSubscriptionPriceId("price_test_monthly");
    eCloud.setSubscriptionStatus("active");
    eCloud.setFeatures("{\"plan\":\"cloud\",\"backup\":true,\"cloudAi\":true}");
    folioCloudRepository.save(eCloud);

    UserFolioCloudEntity iCloud = UserFolioCloudEntity.defaultsFor(ineligible.getId());
    iCloud.setActive(true);
    iCloud.setSubscriptionPriceId(null);
    iCloud.setSubscriptionStatus("free");
    iCloud.setFeatures("{\"plan\":\"free\",\"backup\":true}");
    folioCloudRepository.save(iCloud);

    UserInkEntity eInk = UserInkEntity.defaultsFor(eligible.getId());
    eInk.setMonthlyBalance(BigDecimal.TEN);
    eInk.setMonthlyPeriodKey("2000-01");
    inkRepository.save(eInk);

    UserInkEntity iInk = UserInkEntity.defaultsFor(ineligible.getId());
    iInk.setMonthlyBalance(BigDecimal.valueOf(7));
    iInk.setMonthlyPeriodKey("2000-01");
    inkRepository.save(iInk);

    int n = job.runRefill();
    assertThat(n).isEqualTo(1);

    UserInkEntity afterEligible = inkRepository.findById(eligible.getId()).orElseThrow();
    assertThat(afterEligible.getMonthlyBalance())
        .isEqualByComparingTo(BigDecimal.valueOf(FolioCloudEntitlementService.MONTHLY_INK_ALLOWANCE));
    assertThat(afterEligible.getMonthlyPeriodKey())
        .isEqualTo(FolioCloudEntitlementService.monthPeriodKeyEuropeMadrid());

    UserInkEntity afterIneligible = inkRepository.findById(ineligible.getId()).orElseThrow();
    assertThat(afterIneligible.getMonthlyBalance()).isEqualByComparingTo(BigDecimal.valueOf(7));
    assertThat(afterIneligible.getMonthlyPeriodKey()).isEqualTo("2000-01");
  }

  private UserEntity saveUser(String id, String email) {
    UserEntity u = new UserEntity();
    u.setId(id);
    u.setEmail(email);
    u.setDisplayName("U");
    u.setPasswordHash(passwordEncoder.encode("password123"));
    return userRepository.save(u);
  }
}
