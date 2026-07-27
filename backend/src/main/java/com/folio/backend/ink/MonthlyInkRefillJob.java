package com.folio.backend.ink;

import com.folio.backend.billing.FolioCloudEntitlementService;
import com.folio.backend.billing.StripeApiClient;
import com.folio.backend.billing.StripeCatalog;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.UserBillingMicrosoftStoreRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import java.math.BigDecimal;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Port of {@code monthlyInkRefill}. Logic is in {@link #runRefill()} so tests can invoke it
 * without waiting for the cron. Eligibility uses a direct query on {@code user_folio_cloud}
 * (plus MS Store monthly) instead of the removed {@code folioCloudSubscribers} index.
 */
@Component
public class MonthlyInkRefillJob {

  private static final Logger log = LoggerFactory.getLogger(MonthlyInkRefillJob.class);

  private final UserFolioCloudRepository folioCloudRepository;
  private final UserInkRepository inkRepository;
  private final UserBillingMicrosoftStoreRepository msBillingRepository;
  private final StripeCatalog catalog;
  private final StripeApiClient stripeApi;

  public MonthlyInkRefillJob(
      UserFolioCloudRepository folioCloudRepository,
      UserInkRepository inkRepository,
      UserBillingMicrosoftStoreRepository msBillingRepository,
      StripeCatalog catalog,
      StripeApiClient stripeApi) {
    this.folioCloudRepository = folioCloudRepository;
    this.inkRepository = inkRepository;
    this.msBillingRepository = msBillingRepository;
    this.catalog = catalog;
    this.stripeApi = stripeApi;
  }

  @Scheduled(cron = "0 0 8 1 * *", zone = FolioCloudEntitlementService.INK_TIMEZONE)
  public void scheduled() {
    runRefill();
  }

  @Transactional
  public int runRefill() {
    String monthlyResolved = null;
    String studentResolved = null;
    String familyResolved = null;
    if (stripeApi.isConfigured(false)) {
      try {
        String monthlyRaw = catalog.priceFolioCloudMonthly(false);
        String studentRaw = catalog.priceFolioCloudStudent(false);
        String familyRaw = catalog.priceFolioCloudFamily(false);
        if (!monthlyRaw.isBlank()) {
          monthlyResolved = stripeApi.resolveCatalogIdToPriceId(false, monthlyRaw);
        }
        if (!studentRaw.isBlank()) {
          studentResolved = stripeApi.resolveCatalogIdToPriceId(false, studentRaw);
        }
        if (!familyRaw.isBlank()) {
          familyResolved = stripeApi.resolveCatalogIdToPriceId(false, familyRaw);
        }
      } catch (Exception e) {
        log.error("monthlyInkRefill: resolve prices", e);
      }
    } else {
      log.warn("monthlyInkRefill: Stripe key not set — still processing MS Store + exact price ids");
    }

    List<UserFolioCloudEntity> eligible = folioCloudRepository.findEligibleForMonthlyInkRefill();
    String periodKey = FolioCloudEntitlementService.monthPeriodKeyEuropeMadrid();
    int n = 0;
    for (UserFolioCloudEntity cloud : eligible) {
      String uid = cloud.getUserId();
      String priceId = cloud.getSubscriptionPriceId();
      boolean msMonthly =
          msBillingRepository
              .findById(uid)
              .map(m -> m.isSubscriptionActive())
              .orElse(false);

      boolean isMonthly =
          msMonthly
              || (priceId != null
                  && (priceId.equals(monthlyResolved) || priceId.equals(familyResolved)));
      boolean isStudent = priceId != null && priceId.equals(studentResolved);

      if (!isMonthly && !isStudent) {
        continue;
      }

      int refillAllowance =
          isStudent
              ? FolioCloudEntitlementService.STUDENT_INK_ALLOWANCE
              : FolioCloudEntitlementService.MONTHLY_INK_ALLOWANCE;
      UserInkEntity ink =
          inkRepository.findById(uid).orElseGet(() -> UserInkEntity.defaultsFor(uid));
      ink.setMonthlyBalance(BigDecimal.valueOf(refillAllowance));
      ink.setMonthlyPeriodKey(periodKey);
      inkRepository.save(ink);
      n++;
    }
    log.info("monthlyInkRefill: done {} ({} users)", periodKey, n);
    return n;
  }
}
