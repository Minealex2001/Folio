package com.folio.backend.billing;

import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.Price;
import com.stripe.model.Product;
import com.stripe.model.Subscription;
import com.stripe.model.SubscriptionCollection;
import com.stripe.model.checkout.Session;
import com.stripe.param.SubscriptionListParams;
import com.stripe.param.SubscriptionSearchParams;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Component;

@Component
public class DefaultStripeApiClient implements StripeApiClient {

  private static final long BACKUP_SMALL = 20L * 1024 * 1024 * 1024;
  private static final long BACKUP_MEDIUM = 75L * 1024 * 1024 * 1024;
  private static final long BACKUP_LARGE = 250L * 1024 * 1024 * 1024;

  private final StripeCatalog catalog;

  public DefaultStripeApiClient(StripeCatalog catalog) {
    this.catalog = catalog;
  }

  @Override
  public boolean isConfigured(boolean debug) {
    return !catalog.secretKey(debug).isEmpty();
  }

  private void applyKey(boolean debug) {
    Stripe.apiKey = catalog.secretKey(debug);
  }

  @Override
  public String resolveCatalogIdToPriceId(boolean debug, String catalogId) throws StripeException {
    applyKey(debug);
    String id = catalogId == null ? "" : catalogId.trim();
    if (id.isEmpty()) {
      throw new IllegalArgumentException("Empty Stripe catalog id");
    }
    if (id.startsWith("price_")) {
      return id;
    }
    if (id.startsWith("prod_")) {
      Product product = Product.retrieve(id);
      Object dp = product.getDefaultPrice();
      if (dp == null) {
        throw new IllegalStateException("Stripe product " + id + " has no default price");
      }
      if (dp instanceof String s) {
        return s;
      }
      if (dp instanceof Price p) {
        return p.getId();
      }
      return String.valueOf(dp);
    }
    throw new IllegalArgumentException("Invalid Stripe catalog id: " + id);
  }

  @Override
  public Optional<CatalogPriceDisplay> retrieveCatalogPriceDisplay(boolean debug, String catalogId) {
    String raw = catalogId == null ? "" : catalogId.trim();
    if (raw.isEmpty()) {
      return Optional.empty();
    }
    try {
      String priceId = resolveCatalogIdToPriceId(debug, raw);
      Price price = Price.retrieve(priceId);
      Long amount = price.getUnitAmount();
      if (amount == null) {
        return Optional.empty();
      }
      String currency = price.getCurrency();
      if (currency == null || currency.isBlank()) {
        currency = "eur";
      }
      return Optional.of(new CatalogPriceDisplay(amount, currency.toLowerCase()));
    } catch (Exception e) {
      return Optional.empty();
    }
  }

  @Override
  public boolean catalogMatchesPrice(boolean debug, String envCatalogId, String actualPriceId) {
    if (actualPriceId == null || envCatalogId == null || envCatalogId.isBlank()) {
      return false;
    }
    String env = envCatalogId.trim();
    try {
      if (env.startsWith("price_")) {
        return env.equals(actualPriceId);
      }
      if (env.startsWith("prod_")) {
        applyKey(debug);
        Price price = Price.retrieve(actualPriceId);
        Object prod = price.getProduct();
        String prodId = prod instanceof String s ? s : (prod instanceof Product p ? p.getId() : null);
        return env.equals(prodId);
      }
    } catch (Exception e) {
      return false;
    }
    return false;
  }

  @Override
  public boolean isMonthlySubscriptionPrice(boolean debug, String priceId) {
    if (priceId == null) {
      return false;
    }
    if (catalogMatchesPrice(debug, catalog.priceFolioCloudMonthly(debug), priceId)) {
      return true;
    }
    if (catalogMatchesPrice(debug, catalog.priceFolioCloudFamily(debug), priceId)) {
      return true;
    }
    if (catalogMatchesPrice(debug, catalog.priceFolioCloudStudent(debug), priceId)) {
      return true;
    }
    return catalog.legacyPriceIds().contains(priceId);
  }

  @Override
  public int inkDropsForPriceId(boolean debug, String priceId) {
    if (priceId == null) {
      return 0;
    }
    if (catalogMatchesPrice(debug, catalog.priceInkSmall(debug), priceId)) {
      return 300;
    }
    if (catalogMatchesPrice(debug, catalog.priceInkMedium(debug), priceId)) {
      return 1000;
    }
    if (catalogMatchesPrice(debug, catalog.priceInkLarge(debug), priceId)) {
      return 2500;
    }
    return 0;
  }

  @Override
  public long backupStorageBytesForPriceId(boolean debug, String priceId) {
    if (priceId == null) {
      return 0;
    }
    if (catalogMatchesPrice(debug, catalog.priceBackupLarge(debug), priceId)) {
      return BACKUP_LARGE;
    }
    if (catalogMatchesPrice(debug, catalog.priceBackupMedium(debug), priceId)) {
      return BACKUP_MEDIUM;
    }
    if (catalogMatchesPrice(debug, catalog.priceBackupSmall(debug), priceId)) {
      return BACKUP_SMALL;
    }
    return 0;
  }

  @Override
  public Session createCheckoutSession(boolean debug, StripeApiClient.SessionCreateParams params)
      throws StripeException {
    applyKey(debug);
    com.stripe.param.checkout.SessionCreateParams.Builder b =
        com.stripe.param.checkout.SessionCreateParams.builder()
            .setMode(
                "subscription".equals(params.mode())
                    ? com.stripe.param.checkout.SessionCreateParams.Mode.SUBSCRIPTION
                    : com.stripe.param.checkout.SessionCreateParams.Mode.PAYMENT)
            .addLineItem(
                com.stripe.param.checkout.SessionCreateParams.LineItem.builder()
                    .setPrice(params.priceId())
                    .setQuantity(1L)
                    .build())
            .setAllowPromotionCodes(true)
            .setSuccessUrl(params.successUrl())
            .setCancelUrl(params.cancelUrl())
            .setClientReferenceId(params.clientReferenceId())
            .putMetadata("firebase_uid", params.firebaseUid());
    if ("subscription".equals(params.mode())) {
      b.setSubscriptionData(
          com.stripe.param.checkout.SessionCreateParams.SubscriptionData.builder()
              .putMetadata("firebase_uid", params.firebaseUid())
              .build());
    } else {
      b.setPaymentIntentData(
          com.stripe.param.checkout.SessionCreateParams.PaymentIntentData.builder()
              .putMetadata("firebase_uid", params.firebaseUid())
              .build());
    }
    return Session.create(b.build());
  }

  @Override
  public com.stripe.model.billingportal.Session createBillingPortalSession(
      boolean debug, String customerId, String returnUrl) throws StripeException {
    applyKey(debug);
    Map<String, Object> params = new HashMap<>();
    params.put("customer", customerId);
    params.put("return_url", returnUrl);
    return com.stripe.model.billingportal.Session.create(params);
  }

  @Override
  public Session retrieveCheckoutSession(boolean debug, String sessionId) throws StripeException {
    applyKey(debug);
    Map<String, Object> params = new HashMap<>();
    params.put("expand", List.of("line_items.data.price", "subscription"));
    return Session.retrieve(sessionId, params, null);
  }

  @Override
  public Subscription retrieveSubscription(boolean debug, String subscriptionId)
      throws StripeException {
    applyKey(debug);
    return Subscription.retrieve(subscriptionId);
  }

  @Override
  public List<Subscription> listSubscriptions(boolean debug, String customerId)
      throws StripeException {
    applyKey(debug);
    SubscriptionCollection col =
        Subscription.list(
            SubscriptionListParams.builder()
                .setCustomer(customerId)
                .setStatus(SubscriptionListParams.Status.ALL)
                .setLimit(100L)
                .build());
    return col.getData();
  }

  @Override
  public void cancelSubscription(boolean debug, String subscriptionId) throws StripeException {
    applyKey(debug);
    Subscription.retrieve(subscriptionId).cancel();
  }

  @Override
  public void deleteCustomer(boolean debug, String customerId) throws StripeException {
    applyKey(debug);
    com.stripe.model.Customer.retrieve(customerId).delete();
  }

  @Override
  public Optional<String> searchCustomerIdByFirebaseUid(boolean debug, String uid)
      throws StripeException {
    applyKey(debug);
    String escaped = uid.replace("\\", "\\\\").replace("'", "\\'");
    var search =
        Subscription.search(
            SubscriptionSearchParams.builder()
                .setQuery("metadata['firebase_uid']:'" + escaped + "'")
                .setLimit(10L)
                .build());
    for (Subscription sub : search.getData()) {
      Object c = sub.getCustomer();
      if (c instanceof String s && !s.isBlank()) {
        return Optional.of(s);
      }
    }
    return Optional.empty();
  }
}
