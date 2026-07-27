package com.folio.backend.billing;

import com.folio.backend.persistence.entity.StripeProcessedCheckoutEntity;
import com.folio.backend.persistence.entity.StripeWebhookEventEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.repository.StripeProcessedCheckoutRepository;
import com.folio.backend.persistence.repository.StripeWebhookEventRepository;
import com.folio.backend.persistence.repository.UserRepository;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.model.StripeObject;
import com.stripe.model.Subscription;
import com.stripe.model.checkout.Session;
import com.stripe.net.Webhook;
import java.util.HashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class StripeWebhookService {

  private static final Logger log = LoggerFactory.getLogger(StripeWebhookService.class);

  private final StripeCatalog catalog;
  private final StripeApiClient stripeApi;
  private final BillingService billingService;
  private final FolioCloudEntitlementService entitlements;
  private final StripeWebhookEventRepository webhookEventRepository;
  private final StripeProcessedCheckoutRepository processedCheckoutRepository;
  private final UserRepository userRepository;

  public StripeWebhookService(
      StripeCatalog catalog,
      StripeApiClient stripeApi,
      BillingService billingService,
      FolioCloudEntitlementService entitlements,
      StripeWebhookEventRepository webhookEventRepository,
      StripeProcessedCheckoutRepository processedCheckoutRepository,
      UserRepository userRepository) {
    this.catalog = catalog;
    this.stripeApi = stripeApi;
    this.billingService = billingService;
    this.entitlements = entitlements;
    this.webhookEventRepository = webhookEventRepository;
    this.processedCheckoutRepository = processedCheckoutRepository;
    this.userRepository = userRepository;
  }

  @Transactional
  public ResponseEntity<Map<String, Object>> handle(String payload, String sigHeader) {
    if (sigHeader == null || sigHeader.isBlank()) {
      return ResponseEntity.badRequest().body(Map.of("error", "Missing stripe-signature"));
    }
    Event event;
    boolean debug = false;
    try {
      String secret = catalog.webhookSecret(false);
      if (secret.isBlank() || !stripeApi.isConfigured(false)) {
        throw new SignatureVerificationException("Missing config", sigHeader);
      }
      event = Webhook.constructEvent(payload, sigHeader, secret);
    } catch (Exception liveErr) {
      try {
        String testSecret = catalog.webhookSecret(true);
        if (testSecret.isBlank() || !stripeApi.isConfigured(true)) {
          log.error("Webhook signature verification failed", liveErr);
          return ResponseEntity.badRequest().body(Map.of("error", "Invalid signature"));
        }
        event = Webhook.constructEvent(payload, sigHeader, testSecret);
        debug = true;
        log.info("Stripe webhook: verified using test secret");
      } catch (Exception testErr) {
        log.error("Webhook signature verification failed for live and test", liveErr);
        return ResponseEntity.badRequest().body(Map.of("error", "Invalid signature"));
      }
    }

    String eventId = event.getId();
    if (webhookEventRepository.existsById(eventId)) {
      Map<String, Object> body = new HashMap<>();
      body.put("received", true);
      body.put("duplicate", true);
      return ResponseEntity.ok(body);
    }

    try {
      switch (event.getType()) {
        case "checkout.session.completed", "checkout.session.async_payment_succeeded" -> {
          Session session = deserialize(event, Session.class);
          if (session != null) {
            handleCheckoutSessionCompleted(session, debug);
          }
        }
        case "customer.subscription.created",
            "customer.subscription.updated",
            "customer.subscription.deleted" -> {
          Subscription sub = deserialize(event, Subscription.class);
          if (sub != null) {
            handleSubscriptionEvent(event.getType(), sub, debug);
          }
        }
        default -> {
          // ignore
        }
      }
      StripeWebhookEventEntity row = new StripeWebhookEventEntity();
      row.setEventId(eventId);
      webhookEventRepository.save(row);
      return ResponseEntity.ok(Map.of("received", true));
    } catch (Exception e) {
      log.error("Webhook handler error", e);
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
          .body(Map.of("error", "Handler error"));
    }
  }

  /**
   * Idempotent processing entry used by integration tests without Stripe signature verification.
   */
  @Transactional
  public Map<String, Object> processVerifiedEvent(String eventId, Runnable effect) {
    if (webhookEventRepository.existsById(eventId)) {
      return Map.of("received", true, "duplicate", true);
    }
    effect.run();
    StripeWebhookEventEntity row = new StripeWebhookEventEntity();
    row.setEventId(eventId);
    webhookEventRepository.save(row);
    return Map.of("received", true);
  }

  private void handleCheckoutSessionCompleted(Session session, boolean debug) throws Exception {
    String uid = "";
    if (session.getMetadata() != null) {
      uid = blank(session.getMetadata().get("firebase_uid"));
    }
    if (uid.isEmpty()) {
      uid = blank(session.getClientReferenceId());
    }
    if (uid.isEmpty()) {
      log.error("checkout session: missing firebase_uid {}", session.getId());
      return;
    }

    Session expanded = stripeApi.retrieveCheckoutSession(debug, session.getId());
    String customerId = blank(expanded.getCustomer());

    String mode = expanded.getMode();
    if ("subscription".equals(mode)) {
      Subscription sub = null;
      String subId = expanded.getSubscription();
      if (subId != null && !subId.isBlank()) {
        sub = stripeApi.retrieveSubscription(debug, subId);
      }
      if (sub == null) {
        throw new IllegalStateException(
            "checkout.session.completed: subscription missing after successful payment");
      }
      if (customerId.isEmpty()) {
        customerId = blank(sub.getCustomer());
      }
      if (!customerId.isEmpty()) {
        persistCustomer(uid, customerId);
      }
      String priceId =
          sub.getItems() != null
                  && sub.getItems().getData() != null
                  && !sub.getItems().getData().isEmpty()
              ? sub.getItems().getData().get(0).getPrice().getId()
              : null;
      if (stripeApi.isMonthlySubscriptionPrice(debug, priceId)) {
        billingService.syncSubscriptionToUser(uid, sub.getStatus(), priceId, sub, debug);
      } else {
        entitlements.recomputeEffectiveFolioCloud(uid);
      }
      if (!"paid".equals(expanded.getPaymentStatus())) {
        return;
      }
      grantPaymentCheckoutInkIfNeeded(uid, expanded, debug);
      return;
    }
    if (!customerId.isEmpty()) {
      persistCustomer(uid, customerId);
    }
    if ("payment".equals(mode)) {
      if (!"paid".equals(expanded.getPaymentStatus())) {
        return;
      }
      grantPaymentCheckoutInkIfNeeded(uid, expanded, debug);
    }
  }

  private void handleSubscriptionEvent(String type, Subscription sub, boolean debug) {
    String subUid =
        sub.getMetadata() != null ? blank(sub.getMetadata().get("firebase_uid")) : "";
    if (subUid.isEmpty()) {
      return;
    }
    Object customerRef = sub.getCustomer();
    if (customerRef instanceof String cid && !cid.isBlank()) {
      persistCustomer(subUid, cid);
    }
    String priceId =
        sub.getItems() != null
                && sub.getItems().getData() != null
                && !sub.getItems().getData().isEmpty()
            ? sub.getItems().getData().get(0).getPrice().getId()
            : null;
    String statusForBilling =
        "customer.subscription.deleted".equals(type) ? "canceled" : sub.getStatus();
    if (stripeApi.isMonthlySubscriptionPrice(debug, priceId)) {
      billingService.syncSubscriptionToUser(subUid, statusForBilling, priceId, sub, debug);
    }
    entitlements.recomputeEffectiveFolioCloud(subUid);
  }

  private void grantPaymentCheckoutInkIfNeeded(String uid, Session expanded, boolean debug) {
    if (processedCheckoutRepository.existsById(expanded.getId())) {
      return;
    }
    if (!"paid".equals(expanded.getPaymentStatus())) {
      return;
    }
    int totalAdded = 0;
    if (expanded.getLineItems() != null && expanded.getLineItems().getData() != null) {
      for (var item : expanded.getLineItems().getData()) {
        String linePriceId =
            item.getPrice() != null
                ? item.getPrice().getId()
                : null;
        int drops = stripeApi.inkDropsForPriceId(debug, linePriceId);
        long qty = item.getQuantity() != null ? item.getQuantity() : 1L;
        if (drops > 0) {
          totalAdded += (int) (drops * qty);
        }
      }
    }
    if (totalAdded > 0) {
      billingService.grantPurchasedInk(uid, totalAdded);
    }
    StripeProcessedCheckoutEntity done = new StripeProcessedCheckoutEntity();
    done.setSessionId(expanded.getId());
    processedCheckoutRepository.save(done);
  }

  private void persistCustomer(String uid, String customerId) {
    userRepository
        .findById(uid)
        .ifPresent(
            u -> {
              u.setStripeCustomerId(customerId);
              userRepository.save(u);
            });
  }

  @SuppressWarnings("unchecked")
  private static <T extends StripeObject> T deserialize(Event event, Class<T> type) {
    try {
      var deser = event.getDataObjectDeserializer();
      if (deser.getObject().isPresent()) {
        StripeObject obj = deser.getObject().get();
        if (type.isInstance(obj)) {
          return (T) obj;
        }
      }
      return deser.deserializeUnsafe() != null && type.isInstance(deser.deserializeUnsafe())
          ? (T) deser.deserializeUnsafe()
          : null;
    } catch (Exception e) {
      log.warn("Failed to deserialize webhook object {}", event.getType(), e);
      return null;
    }
  }

  private static String blank(Object o) {
    return o == null ? "" : String.valueOf(o).trim();
  }
}
