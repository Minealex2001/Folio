package com.folio.backend.billing;

import com.stripe.exception.StripeException;
import com.stripe.model.Subscription;
import com.stripe.model.checkout.Session;
import java.util.List;
import java.util.Optional;

/** Thin Stripe API façade so tests can mock without hitting Stripe. */
public interface StripeApiClient {

  boolean isConfigured(boolean debug);

  String resolveCatalogIdToPriceId(boolean debug, String catalogId) throws StripeException;

  /** unitAmount + currency for UI catalog; empty if catalog id blank or Stripe lookup fails. */
  Optional<CatalogPriceDisplay> retrieveCatalogPriceDisplay(boolean debug, String catalogId);

  boolean catalogMatchesPrice(boolean debug, String envCatalogId, String actualPriceId);

  boolean isMonthlySubscriptionPrice(boolean debug, String priceId);

  int inkDropsForPriceId(boolean debug, String priceId);

  long backupStorageBytesForPriceId(boolean debug, String priceId);

  Session createCheckoutSession(boolean debug, SessionCreateParams params) throws StripeException;

  com.stripe.model.billingportal.Session createBillingPortalSession(
      boolean debug, String customerId, String returnUrl) throws StripeException;

  Session retrieveCheckoutSession(boolean debug, String sessionId) throws StripeException;

  Subscription retrieveSubscription(boolean debug, String subscriptionId) throws StripeException;

  List<Subscription> listSubscriptions(boolean debug, String customerId) throws StripeException;

  void cancelSubscription(boolean debug, String subscriptionId) throws StripeException;

  void deleteCustomer(boolean debug, String customerId) throws StripeException;

  Optional<String> searchCustomerIdByFirebaseUid(boolean debug, String uid) throws StripeException;

  record SessionCreateParams(
      String mode,
      String priceId,
      String successUrl,
      String cancelUrl,
      String clientReferenceId,
      String firebaseUid) {}

  record CatalogPriceDisplay(long unitAmount, String currency) {}
}
