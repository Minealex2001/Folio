package com.folio.backend.billing;

import com.folio.backend.billing.dto.CheckoutSessionRequest;
import com.folio.backend.billing.dto.SyncBillingRequest;
import com.folio.backend.user.FolioUserPrincipal;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/billing")
public class BillingController {

  private final BillingService billingService;
  private final StripeWebhookService webhookService;

  public BillingController(BillingService billingService, StripeWebhookService webhookService) {
    this.billingService = billingService;
    this.webhookService = webhookService;
  }

  @PostMapping("/checkout-session")
  public Map<String, String> checkout(@RequestBody(required = false) CheckoutSessionRequest body) {
    boolean debug = body != null && Boolean.TRUE.equals(body.debug());
    String kind = body != null ? body.kind() : null;
    return billingService.createCheckoutSession(FolioUserPrincipal.requireUid(), kind, debug);
  }

  @PostMapping("/portal-session")
  public Map<String, String> portal(@RequestBody(required = false) SyncBillingRequest body) {
    boolean debug = body != null && Boolean.TRUE.equals(body.debug());
    return billingService.createBillingPortalSession(FolioUserPrincipal.requireUid(), debug);
  }

  @PostMapping("/sync")
  public Map<String, Object> sync(@RequestBody(required = false) SyncBillingRequest body) {
    boolean debug = body != null && Boolean.TRUE.equals(body.debug());
    return billingService.syncFromStripe(FolioUserPrincipal.requireUid(), debug);
  }

  /** Público (igual que la callable Firebase): solo unitAmount/currency del catálogo. */
  @PostMapping("/catalog-prices")
  public Map<String, Object> catalogPrices(
      @RequestBody(required = false) SyncBillingRequest body) {
    boolean debug = body != null && Boolean.TRUE.equals(body.debug());
    return billingService.catalogPrices(debug);
  }

  @PostMapping("/webhook")
  public ResponseEntity<Map<String, Object>> webhook(
      @RequestBody String payload,
      @RequestHeader(value = "Stripe-Signature", required = false) String signature) {
    return webhookService.handle(payload, signature);
  }
}
