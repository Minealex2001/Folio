package com.folio.backend.billing;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.UserBillingStripeEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.UserBillingStripeRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import com.folio.backend.student.StudentEmailChecker;
import com.stripe.exception.StripeException;
import com.stripe.model.Subscription;
import com.stripe.model.SubscriptionItem;
import com.stripe.model.checkout.Session;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BillingService {

  private static final Logger log = LoggerFactory.getLogger(BillingService.class);

  private final StripeApiClient stripeApi;
  private final StripeCatalog catalog;
  private final UserRepository userRepository;
  private final UserBillingStripeRepository stripeBillingRepository;
  private final UserInkRepository inkRepository;
  private final FolioCloudEntitlementService entitlements;
  private final StudentEmailChecker studentEmailChecker;
  private final ObjectMapper objectMapper;

  public BillingService(
      StripeApiClient stripeApi,
      StripeCatalog catalog,
      UserRepository userRepository,
      UserBillingStripeRepository stripeBillingRepository,
      UserInkRepository inkRepository,
      FolioCloudEntitlementService entitlements,
      StudentEmailChecker studentEmailChecker,
      ObjectMapper objectMapper) {
    this.stripeApi = stripeApi;
    this.catalog = catalog;
    this.userRepository = userRepository;
    this.stripeBillingRepository = stripeBillingRepository;
    this.inkRepository = inkRepository;
    this.entitlements = entitlements;
    this.studentEmailChecker = studentEmailChecker;
    this.objectMapper = objectMapper;
  }

  @Transactional(readOnly = true)
  public Map<String, String> createCheckoutSession(String uid, String kindRaw, boolean debug) {
    requireStripe(debug);
    CheckoutKind kind = CheckoutKind.fromRaw(kindRaw);

    if (kind == CheckoutKind.folio_student_monthly) {
      UserEntity user =
          userRepository
              .findById(uid)
              .orElseThrow(
                  () -> new ApiException(HttpStatus.NOT_FOUND, "user_not_found", "User not found"));
      UserBillingStripeEntity billing = stripeBillingRepository.findById(uid).orElse(null);
      boolean studentVerified = billing != null && billing.isStudentVerified();
      boolean isStudent =
          studentVerified || studentEmailChecker.isStudentEmail(user.getEmail());
      if (!isStudent) {
        throw new ApiException(
            HttpStatus.PRECONDITION_FAILED,
            "failed_precondition",
            "Para contratar la suscripción de estudiantes debes usar un correo de estudiante verificado.");
      }
    }

    String rawCatalogId = catalog.catalogId(kind, debug);
    if (rawCatalogId.isBlank()) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Stripe catalog id not configured for kind: " + kind);
    }

    try {
      String priceId = stripeApi.resolveCatalogIdToPriceId(debug, rawCatalogId);
      String success = catalog.successUrl();
      String successWithSession =
          success.contains("?")
              ? success + "&session_id={CHECKOUT_SESSION_ID}"
              : success + "?session_id={CHECKOUT_SESSION_ID}";
      Session session =
          stripeApi.createCheckoutSession(
              debug,
              new StripeApiClient.SessionCreateParams(
                  kind.isSubscription() ? "subscription" : "payment",
                  priceId,
                  successWithSession,
                  catalog.cancelUrl(),
                  uid,
                  uid));
      if (session.getUrl() == null || session.getUrl().isBlank()) {
        throw new ApiException(
            HttpStatus.PRECONDITION_FAILED,
            "failed_precondition",
            "Stripe did not return a checkout URL");
      }
      return Map.of("url", session.getUrl());
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      log.error("createCheckoutSession", e);
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Stripe: " + safeMsg(e));
    }
  }

  @Transactional(readOnly = true)
  public Map<String, String> createBillingPortalSession(String uid, boolean debug) {
    requireStripe(debug);
    String customerId = ensureStripeCustomerId(uid, debug);
    if (customerId == null) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "No Stripe customer yet. Complete checkout first.");
    }
    try {
      var session =
          stripeApi.createBillingPortalSession(debug, customerId, catalog.portalReturnUrl());
      if (session.getUrl() == null || session.getUrl().isBlank()) {
        throw new ApiException(
            HttpStatus.PRECONDITION_FAILED,
            "failed_precondition",
            "Stripe did not return a billing portal URL");
      }
      return Map.of("url", session.getUrl());
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      log.error("createBillingPortalSession", e);
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED, "failed_precondition", "Stripe: " + safeMsg(e));
    }
  }

  @Transactional
  public Map<String, Object> syncFromStripe(String uid, boolean debug) {
    requireStripe(debug);
    String customerId = ensureStripeCustomerId(uid, debug);
    if (customerId == null) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "No Stripe customer yet. Complete checkout first.");
    }
    try {
      List<Subscription> subs = stripeApi.listSubscriptions(debug, customerId);
      Subscription chosen = findMainSubscription(debug, subs);
      if (chosen != null) {
        Object c = chosen.getCustomer();
        if (c instanceof String cid && !cid.equals(customerId)) {
          UserEntity user = userRepository.findById(uid).orElseThrow();
          user.setStripeCustomerId(cid);
          userRepository.save(user);
        }
        String priceId =
            chosen.getItems() != null
                    && chosen.getItems().getData() != null
                    && !chosen.getItems().getData().isEmpty()
                ? chosen.getItems().getData().get(0).getPrice().getId()
                : null;
        syncSubscriptionToUser(uid, chosen.getStatus(), priceId, chosen, debug);
        return Map.of("ok", true, "status", chosen.getStatus());
      }
      syncSubscriptionToUser(uid, "canceled", null, null, debug);
      return Map.of("ok", true, "status", "canceled");
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      log.error("syncFromStripe", e);
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED, "failed_precondition", "Stripe: " + safeMsg(e));
    }
  }

  @Transactional
  public void syncSubscriptionToUser(
      String uid, String status, String priceId, Subscription subObj, boolean debug) {
    boolean active =
        "active".equals(status) || "trialing".equals(status) || "past_due".equals(status);
    int familySeats = 0;
    if (active && subObj != null) {
      String seatPriceId = catalog.priceFolioCloudFamilyMember(debug);
      if (seatPriceId != null && !seatPriceId.isBlank() && subObj.getItems() != null) {
        for (SubscriptionItem item : subObj.getItems().getData()) {
          if (item.getPrice() != null && seatPriceId.equals(item.getPrice().getId())) {
            familySeats = (int) Math.min(10, item.getQuantity() != null ? item.getQuantity() : 0);
          }
        }
      }
    }

    UserBillingStripeEntity billing =
        stripeBillingRepository
            .findById(uid)
            .orElseGet(() -> UserBillingStripeEntity.defaultsFor(uid));
    billing.setPriceId(priceId);
    if (subObj != null) {
      billing.setSubscriptionId(subObj.getId());
    }
    billing.setFamilySeats(familySeats);
    ObjectNode raw = objectMapper.createObjectNode();
    raw.put("subscriptionStatus", status);
    raw.put("active", active);
    billing.setRaw(raw.toString());
    stripeBillingRepository.save(billing);
    entitlements.recomputeEffectiveFolioCloud(uid);
  }

  String ensureStripeCustomerId(String uid, boolean debug) {
    UserEntity user = userRepository.findById(uid).orElse(null);
    if (user == null) {
      return null;
    }
    if (user.getStripeCustomerId() != null && !user.getStripeCustomerId().isBlank()) {
      return user.getStripeCustomerId();
    }
    try {
      return stripeApi
          .searchCustomerIdByFirebaseUid(debug, uid)
          .map(
              cid -> {
                user.setStripeCustomerId(cid);
                userRepository.save(user);
                return cid;
              })
          .orElse(null);
    } catch (StripeException e) {
      log.warn("ensureStripeCustomerId search failed", e);
      return null;
    }
  }

  private Subscription findMainSubscription(boolean debug, List<Subscription> list) {
    String monthly = null;
    String student = null;
    try {
      String rawM = catalog.priceFolioCloudMonthly(debug);
      if (!rawM.isBlank()) {
        monthly = stripeApi.resolveCatalogIdToPriceId(debug, rawM);
      }
      String rawS = catalog.priceFolioCloudStudent(debug);
      if (!rawS.isBlank()) {
        student = stripeApi.resolveCatalogIdToPriceId(debug, rawS);
      }
    } catch (Exception e) {
      log.warn("resolve prices for sync", e);
    }
    String[] priority = {"active", "trialing", "past_due", "unpaid"};
    List<String> legacy = catalog.legacyPriceIds();
    for (String st : priority) {
      for (Subscription s : list) {
        if (!st.equals(s.getStatus())) {
          continue;
        }
        if (s.getItems() == null) {
          continue;
        }
        for (SubscriptionItem it : s.getItems().getData()) {
          String pid = it.getPrice() != null ? it.getPrice().getId() : null;
          if (pid == null) {
            continue;
          }
          if (monthly != null && monthly.equals(pid)) {
            return s;
          }
          if (student != null && student.equals(pid)) {
            return s;
          }
          if (legacy.contains(pid)) {
            return s;
          }
        }
      }
    }
    return null;
  }

  @Transactional
  public void grantPurchasedInk(String uid, int drops) {
    if (drops <= 0) {
      return;
    }
    UserInkEntity ink =
        inkRepository.findById(uid).orElseGet(() -> UserInkEntity.defaultsFor(uid));
    ink.setPurchasedBalance(ink.getPurchasedBalance().add(BigDecimal.valueOf(drops)));
    inkRepository.save(ink);
  }

  private void requireStripe(boolean debug) {
    if (!stripeApi.isConfigured(debug)) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED, "failed_precondition", "Stripe not configured on server");
    }
  }

  /**
   * Importes de catálogo Stripe para la UI (sin auth). Puerto de {@code folioCloudCatalogPrices}.
   */
  public Map<String, Object> catalogPrices(boolean debug) {
    requireStripe(debug);
    Map<String, String> entries =
        Map.ofEntries(
            Map.entry("folio_cloud_monthly", catalog.priceFolioCloudMonthly(debug)),
            Map.entry("folio_family_monthly", catalog.priceFolioCloudFamily(debug)),
            Map.entry("folio_family_member", catalog.priceFolioCloudFamilyMember(debug)),
            Map.entry("folio_student_monthly", catalog.priceFolioCloudStudent(debug)),
            Map.entry("ink_small", catalog.priceInkSmall(debug)),
            Map.entry("ink_medium", catalog.priceInkMedium(debug)),
            Map.entry("ink_large", catalog.priceInkLarge(debug)),
            Map.entry("backup_storage_pack_small", catalog.priceBackupSmall(debug)),
            Map.entry("backup_storage_pack_medium", catalog.priceBackupMedium(debug)),
            Map.entry("backup_storage_pack_large", catalog.priceBackupLarge(debug)));
    Map<String, Object> prices = new java.util.LinkedHashMap<>();
    for (var e : entries.entrySet()) {
      stripeApi
          .retrieveCatalogPriceDisplay(debug, e.getValue())
          .ifPresent(
              d ->
                  prices.put(
                      e.getKey(),
                      Map.of("unitAmount", d.unitAmount(), "currency", d.currency())));
    }
    return Map.of("prices", prices);
  }

  private static String safeMsg(Exception e) {
    String m = e.getMessage();
    return m == null ? "Unknown error" : m.substring(0, Math.min(500, m.length()));
  }
}
