package com.folio.backend.billing;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.folio.backend.persistence.entity.FamilyMemberEntity;
import com.folio.backend.persistence.entity.UserBillingMicrosoftStoreEntity;
import com.folio.backend.persistence.entity.UserBillingStripeEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.FamilyMemberRepository;
import com.folio.backend.persistence.repository.UserBillingMicrosoftStoreRepository;
import com.folio.backend.persistence.repository.UserBillingStripeRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Port of {@code recomputeEffectiveFolioCloud} — merges Stripe + Microsoft Store billing into
 * {@code user_folio_cloud} and monthly ink. Does not maintain a {@code folioCloudSubscribers}
 * index (query {@code user_folio_cloud} directly instead).
 */
@Service
public class FolioCloudEntitlementService {

  public static final int MONTHLY_INK_ALLOWANCE = 500;
  public static final int STUDENT_INK_ALLOWANCE = 1000;
  public static final String INK_TIMEZONE = "Europe/Madrid";

  private static final Logger log = LoggerFactory.getLogger(FolioCloudEntitlementService.class);
  private static final DateTimeFormatter PERIOD_FMT = DateTimeFormatter.ofPattern("yyyy-MM");

  private final UserRepository userRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final UserInkRepository inkRepository;
  private final UserBillingStripeRepository stripeBillingRepository;
  private final UserBillingMicrosoftStoreRepository msBillingRepository;
  private final FamilyMemberRepository familyMemberRepository;
  private final StripeCatalog catalog;
  private final StripeApiClient stripeApi;
  private final ObjectMapper objectMapper;

  public FolioCloudEntitlementService(
      UserRepository userRepository,
      UserFolioCloudRepository folioCloudRepository,
      UserInkRepository inkRepository,
      UserBillingStripeRepository stripeBillingRepository,
      UserBillingMicrosoftStoreRepository msBillingRepository,
      FamilyMemberRepository familyMemberRepository,
      StripeCatalog catalog,
      StripeApiClient stripeApi,
      ObjectMapper objectMapper) {
    this.userRepository = userRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.inkRepository = inkRepository;
    this.stripeBillingRepository = stripeBillingRepository;
    this.msBillingRepository = msBillingRepository;
    this.familyMemberRepository = familyMemberRepository;
    this.catalog = catalog;
    this.stripeApi = stripeApi;
    this.objectMapper = objectMapper;
  }

  public static String monthPeriodKeyEuropeMadrid() {
    ZonedDateTime z = ZonedDateTime.now(ZoneId.of(INK_TIMEZONE));
    return PERIOD_FMT.format(z);
  }

  @Transactional
  public void recomputeEffectiveFolioCloud(String uid) {
    UserEntity user = userRepository.findById(uid).orElse(null);
    if (user == null) {
      return;
    }
    UserFolioCloudEntity cloud =
        folioCloudRepository.findById(uid).orElseGet(() -> UserFolioCloudEntity.defaultsFor(uid));

    // Admin / QA grant: full cloud features + monthly ink without Stripe.
    if (cloud.isAdminOverride() || user.isFolioStaff()) {
      applyAdminOrStaffEntitlements(uid, cloud, user.isFolioStaff());
      return;
    }

    UserBillingStripeEntity stripeBilling =
        stripeBillingRepository.findById(uid).orElse(null);
    UserBillingMicrosoftStoreEntity msBilling =
        msBillingRepository.findById(uid).orElse(null);

    String familyOwnerUid = cloud.getFamilyOwnerUid();
    // Prefer membership table if present
    familyOwnerUid =
        familyMemberRepository
            .findByIdMemberUid(uid)
            .map(m -> m.getId().getFamilyOwnerUid())
            .orElse(familyOwnerUid);

    UserFolioCloudEntity ownerFc = null;
    if (familyOwnerUid != null && !familyOwnerUid.isBlank()) {
      ownerFc = folioCloudRepository.findById(familyOwnerUid).orElse(null);
    }

    String stripeStatus = "canceled";
    String stripePriceId = null;
    boolean stripeActiveFlag = false;
    boolean isStudent = false;

    if (familyOwnerUid != null && !familyOwnerUid.isBlank()) {
      if (ownerFc != null) {
        stripeStatus =
            ownerFc.getSubscriptionStatus() != null ? ownerFc.getSubscriptionStatus() : "canceled";
        stripePriceId = ownerFc.getSubscriptionPriceId();
        stripeActiveFlag = isFolioCloudPaidPlan(ownerFc);
      }
      isStudent = false;
    } else if (stripeBilling != null) {
      ObjectNode raw = readRaw(stripeBilling.getRaw());
      stripeStatus = textOr(raw, "subscriptionStatus", "canceled");
      stripePriceId = stripeBilling.getPriceId();
      stripeActiveFlag = raw.path("active").asBoolean(false);
    } else {
      stripeStatus =
          cloud.getSubscriptionStatus() != null ? cloud.getSubscriptionStatus() : "canceled";
      stripePriceId = cloud.getSubscriptionPriceId();
      stripeActiveFlag =
          cloud.isActive()
              && !"canceled".equals(stripeStatus)
              && !"free".equals(stripeStatus)
              && !"free".equals(planOf(cloud));
    }

    boolean msMonthlyActive = msBilling != null && msBilling.isSubscriptionActive();

    boolean stripeConfigured = stripeApi.isConfigured(false);
    if (familyOwnerUid == null
        && stripeConfigured
        && stripePriceId != null
        && stripeActiveFlag) {
      isStudent =
          stripeApi.catalogMatchesPrice(
              false, catalog.priceFolioCloudStudent(false), stripePriceId);
    }

    boolean stripeFeaturesAll = false;
    if (stripeConfigured && stripePriceId != null && stripeActiveFlag) {
      stripeFeaturesAll = stripeApi.isMonthlySubscriptionPrice(false, stripePriceId);
    }

    boolean paidActive = stripeActiveFlag || msMonthlyActive;
    boolean backup = stripeFeaturesAll || msMonthlyActive;
    boolean cloudAi = stripeFeaturesAll || msMonthlyActive;
    boolean publishWeb = stripeFeaturesAll || msMonthlyActive;
    boolean realtimeCollab = stripeFeaturesAll || msMonthlyActive;

    boolean folioActive = paidActive;
    String folioPlan = "cloud";
    String subscriptionStatus = stripeStatus;
    if (msMonthlyActive && (!stripeActiveFlag || "canceled".equals(stripeStatus))) {
      subscriptionStatus = "active";
    }

    if (!paidActive) {
      folioActive = true;
      folioPlan = "free";
      subscriptionStatus = "free";
      backup = true;
      cloudAi = false;
      publishWeb = false;
      realtimeCollab = false;
    }

    boolean stripeMonthlyActive = false;
    if (stripeActiveFlag && stripeConfigured && stripePriceId != null) {
      stripeMonthlyActive = stripeApi.isMonthlySubscriptionPrice(false, stripePriceId);
    }
    boolean needsMonthlyInk = stripeMonthlyActive || msMonthlyActive;

    int familySeats = 0;
    if (familyOwnerUid != null && !familyOwnerUid.isBlank()) {
      familySeats = ownerFc != null ? ownerFc.getFamilySeats() : 0;
    } else if (stripeBilling != null) {
      familySeats = stripeBilling.getFamilySeats();
    }

    boolean isFamily =
        (familyOwnerUid != null && !familyOwnerUid.isBlank()) || familySeats > 0;
    boolean studentVerified =
        (stripeBilling != null && stripeBilling.isStudentVerified())
            || cloud.isStudentVerified();

    cloud.setUserId(uid);
    cloud.setSubscriptionStatus(subscriptionStatus);
    cloud.setActive(folioActive);
    cloud.setSubscriptionPriceId(stripePriceId);
    cloud.setFamily(isFamily);
    cloud.setStudent(isStudent);
    cloud.setStudentVerified(studentVerified);
    cloud.setFamilyOwnerUid(
        familyOwnerUid != null && !familyOwnerUid.isBlank() ? familyOwnerUid : null);
    cloud.setFamilySeats(familySeats);
    cloud.setFeatures(featuresJson(backup, cloudAi, publishWeb, realtimeCollab, folioPlan));
    cloud.setUpdatedAt(Instant.now());
    folioCloudRepository.save(cloud);

    UserInkEntity ink =
        inkRepository.findById(uid).orElseGet(() -> UserInkEntity.defaultsFor(uid));
    if (needsMonthlyInk) {
      String currentPeriodKey = monthPeriodKeyEuropeMadrid();
      String existingPeriodKey = ink.getMonthlyPeriodKey();
      boolean shouldRefill =
          existingPeriodKey == null
              || existingPeriodKey.isBlank()
              || !existingPeriodKey.equals(currentPeriodKey);
      int refillAllowance = isStudent ? STUDENT_INK_ALLOWANCE : MONTHLY_INK_ALLOWANCE;
      if (shouldRefill) {
        ink.setMonthlyBalance(BigDecimal.valueOf(refillAllowance));
      }
      ink.setMonthlyPeriodKey(currentPeriodKey);
      inkRepository.save(ink);
    } else {
      ink.setMonthlyBalance(BigDecimal.ZERO);
      ink.setMonthlyPeriodKey(null);
      inkRepository.save(ink);
    }

    // Owner: propagate to members
    if (isFamily && (familyOwnerUid == null || familyOwnerUid.isBlank())) {
      List<FamilyMemberEntity> members = familyMemberRepository.findByIdFamilyOwnerUid(uid);
      for (FamilyMemberEntity m : members) {
        try {
          recomputeEffectiveFolioCloud(m.getId().getMemberUid());
        } catch (RuntimeException e) {
          log.warn("recompute member failed {} -> {}", uid, m.getId().getMemberUid(), e);
        }
      }
    }
  }

  public static boolean isFolioCloudPaidPlan(UserFolioCloudEntity fc) {
    if (fc == null || !fc.isActive()) {
      return false;
    }
    if (fc.isAdminOverride()) {
      return true;
    }
    String plan = planOf(fc);
    if ("free".equals(plan)) {
      return false;
    }
    if ("cloud".equals(plan)) {
      return true;
    }
    String status = fc.getSubscriptionStatus() != null ? fc.getSubscriptionStatus() : "";
    return "active".equals(status) || "trialing".equals(status) || "past_due".equals(status);
  }

  private void applyAdminOrStaffEntitlements(
      String uid, UserFolioCloudEntity cloud, boolean staff) {
    cloud.setUserId(uid);
    cloud.setSubscriptionStatus("active");
    cloud.setActive(true);
    cloud.setSubscriptionPriceId(null);
    cloud.setFeatures(featuresJson(true, true, true, true, "cloud"));
    cloud.setUpdatedAt(Instant.now());
    // Keep admin_override as-is; staff alone also gets full features while flag is set.
    folioCloudRepository.save(cloud);

    UserInkEntity ink =
        inkRepository.findById(uid).orElseGet(() -> UserInkEntity.defaultsFor(uid));
    String currentPeriodKey = monthPeriodKeyEuropeMadrid();
    String existingPeriodKey = ink.getMonthlyPeriodKey();
    boolean shouldRefill =
        existingPeriodKey == null
            || existingPeriodKey.isBlank()
            || !existingPeriodKey.equals(currentPeriodKey);
    if (shouldRefill) {
      ink.setMonthlyBalance(BigDecimal.valueOf(MONTHLY_INK_ALLOWANCE));
    }
    if (staff && ink.getPurchasedBalance().compareTo(BigDecimal.valueOf(10_000)) < 0) {
      // Comfortable pool for QA without touching Stripe ink packs.
      ink.setPurchasedBalance(BigDecimal.valueOf(10_000));
    }
    ink.setMonthlyPeriodKey(currentPeriodKey);
    inkRepository.save(ink);
  }

  private static String planOf(UserFolioCloudEntity fc) {
    try {
      JsonNode n = new ObjectMapper().readTree(fc.getFeatures() == null ? "{}" : fc.getFeatures());
      return n.path("plan").asText("");
    } catch (Exception e) {
      return "";
    }
  }

  private ObjectNode readRaw(String raw) {
    try {
      JsonNode n = objectMapper.readTree(raw == null || raw.isBlank() ? "{}" : raw);
      if (n instanceof ObjectNode o) {
        return o;
      }
    } catch (Exception ignored) {
    }
    return objectMapper.createObjectNode();
  }

  private String featuresJson(
      boolean backup, boolean cloudAi, boolean publishWeb, boolean realtimeCollab, String plan) {
    ObjectNode n = objectMapper.createObjectNode();
    n.put("backup", backup);
    n.put("cloudAi", cloudAi);
    n.put("publishWeb", publishWeb);
    n.put("realtimeCollab", realtimeCollab);
    n.put("plan", plan);
    return n.toString();
  }

  private static String textOr(JsonNode n, String field, String def) {
    String v = n.path(field).asText(null);
    return v == null || v.isBlank() ? def : v;
  }
}
