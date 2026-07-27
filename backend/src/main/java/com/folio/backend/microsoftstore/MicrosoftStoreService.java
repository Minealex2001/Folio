package com.folio.backend.microsoftstore;

import com.folio.backend.billing.BillingService;
import com.folio.backend.billing.FolioCloudEntitlementService;
import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.MicrosoftStoreProcessedBackupGrantEntity;
import com.folio.backend.persistence.entity.MicrosoftStoreProcessedPurchaseEntity;
import com.folio.backend.persistence.entity.UserBillingMicrosoftStoreEntity;
import com.folio.backend.persistence.repository.MicrosoftStoreProcessedBackupGrantRepository;
import com.folio.backend.persistence.repository.MicrosoftStoreProcessedPurchaseRepository;
import com.folio.backend.persistence.repository.UserBillingMicrosoftStoreRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MicrosoftStoreService {

  private final MicrosoftStoreProperties props;
  private final MicrosoftStoreClient client;
  private final UserBillingMicrosoftStoreRepository msBillingRepository;
  private final MicrosoftStoreProcessedPurchaseRepository purchaseRepository;
  private final MicrosoftStoreProcessedBackupGrantRepository backupGrantRepository;
  private final BillingService billingService;
  private final FolioCloudEntitlementService entitlements;

  public MicrosoftStoreService(
      MicrosoftStoreProperties props,
      MicrosoftStoreClient client,
      UserBillingMicrosoftStoreRepository msBillingRepository,
      MicrosoftStoreProcessedPurchaseRepository purchaseRepository,
      MicrosoftStoreProcessedBackupGrantRepository backupGrantRepository,
      BillingService billingService,
      FolioCloudEntitlementService entitlements) {
    this.props = props;
    this.client = client;
    this.msBillingRepository = msBillingRepository;
    this.purchaseRepository = purchaseRepository;
    this.backupGrantRepository = backupGrantRepository;
    this.billingService = billingService;
    this.entitlements = entitlements;
  }

  @Transactional
  public Map<String, Object> validate(String uid, String collectionsIdRaw) {
    String collectionsId = collectionsIdRaw == null ? "" : collectionsIdRaw.trim();
    if (collectionsId.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "collectionsId is required");
    }
    if (!props.isValidationConfigured()) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Microsoft Store validation is not configured on the server.");
    }

    List<Map<String, Object>> items = client.queryUserCollection(collectionsId);
    MicrosoftStoreClient.CollectionScan scan = client.scanCollectionItems(items);

    UserBillingMicrosoftStoreEntity billing =
        msBillingRepository
            .findById(uid)
            .orElseGet(() -> UserBillingMicrosoftStoreEntity.defaultsFor(uid));
    billing.setSubscriptionActive(scan.subscriptionActive());
    billing.setSubscriptionStoreProductId(scan.subscriptionStoreProductId());
    billing.setLastValidatedAt(Instant.now());
    billing.setLastItemCount(items.size());
    msBillingRepository.save(billing);

    grantConsumableInk(uid, scan.consumableGrants());
    grantBackupStorage(uid, scan.backupStorageGrants());
    entitlements.recomputeEffectiveFolioCloud(uid);

    return Map.of(
        "ok",
        true,
        "subscriptionActive",
        scan.subscriptionActive(),
        "storeItems",
        items.size());
  }

  private void grantConsumableInk(String uid, List<MicrosoftStoreClient.ConsumableGrant> grants) {
    for (MicrosoftStoreClient.ConsumableGrant g : grants) {
      if (g.drops() <= 0) {
        continue;
      }
      String globalId = sha256Prefix(g.dedupKey());
      String legacyId = sha256Prefix(uid + ":" + g.dedupKey());
      if (purchaseRepository.existsById(globalId)) {
        continue;
      }
      if (purchaseRepository.existsById(legacyId)) {
        MicrosoftStoreProcessedPurchaseEntity backfill = new MicrosoftStoreProcessedPurchaseEntity();
        backfill.setId(globalId);
        backfill.setUserId(uid);
        purchaseRepository.save(backfill);
        continue;
      }
      MicrosoftStoreProcessedPurchaseEntity row = new MicrosoftStoreProcessedPurchaseEntity();
      row.setId(globalId);
      row.setUserId(uid);
      purchaseRepository.save(row);
      billingService.grantPurchasedInk(uid, g.drops());
    }
  }

  private void grantBackupStorage(String uid, List<MicrosoftStoreClient.BackupGrant> grants) {
    // Backup quota tables are not fully ported yet (Fase 16+); still record idempotency markers
    // so a later quota service can apply grants without double-processing.
    for (MicrosoftStoreClient.BackupGrant g : grants) {
      if (g.bytes() <= 0) {
        continue;
      }
      String globalId = sha256Prefix(g.dedupKey() + ":foliobackup");
      String legacyId = sha256Prefix(uid + ":" + g.dedupKey() + ":foliobackup");
      if (backupGrantRepository.existsById(globalId)) {
        continue;
      }
      if (backupGrantRepository.existsById(legacyId)) {
        MicrosoftStoreProcessedBackupGrantEntity backfill =
            new MicrosoftStoreProcessedBackupGrantEntity();
        backfill.setId(globalId);
        backfill.setUserId(uid);
        backupGrantRepository.save(backfill);
        continue;
      }
      MicrosoftStoreProcessedBackupGrantEntity row = new MicrosoftStoreProcessedBackupGrantEntity();
      row.setId(globalId);
      row.setUserId(uid);
      backupGrantRepository.save(row);
    }
  }

  private static String sha256Prefix(String input) {
    try {
      MessageDigest md = MessageDigest.getInstance("SHA-256");
      byte[] dig = md.digest(input.getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(dig).substring(0, 64);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }
}
