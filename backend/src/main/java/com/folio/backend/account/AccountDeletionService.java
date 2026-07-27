package com.folio.backend.account;

import com.folio.backend.account.dto.AccountExportResponse;
import com.folio.backend.account.dto.CancelDeletionResponse;
import com.folio.backend.account.dto.DeletionScheduleResponse;
import com.folio.backend.billing.FolioCloudEntitlementService;
import com.folio.backend.billing.StripeApiClient;
import com.folio.backend.common.ApiException;
import com.folio.backend.integrations.IntegrationUserIndexRepository;
import com.folio.backend.persistence.entity.CollabRoomEntity;
import com.folio.backend.persistence.entity.CollabRoomMemberEntity;
import com.folio.backend.persistence.entity.CommunityTemplateEntity;
import com.folio.backend.persistence.entity.FamilyEntity;
import com.folio.backend.persistence.entity.FamilyMemberEntity;
import com.folio.backend.persistence.entity.PublishedPageEntity;
import com.folio.backend.persistence.entity.UserBillingMicrosoftStoreEntity;
import com.folio.backend.persistence.entity.UserBillingStripeEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.entity.VaultBackupEntity;
import com.folio.backend.persistence.repository.CollabRoomMediaRepository;
import com.folio.backend.persistence.repository.CollabRoomMemberRepository;
import com.folio.backend.persistence.repository.CollabRoomRepository;
import com.folio.backend.persistence.repository.CommunityTemplateRepository;
import com.folio.backend.persistence.repository.FamilyMemberRepository;
import com.folio.backend.persistence.repository.FamilyRepository;
import com.folio.backend.persistence.repository.MicrosoftStoreProcessedBackupGrantRepository;
import com.folio.backend.persistence.repository.MicrosoftStoreProcessedPurchaseRepository;
import com.folio.backend.persistence.repository.PublishedPageRepository;
import com.folio.backend.persistence.repository.UserBillingMicrosoftStoreRepository;
import com.folio.backend.persistence.repository.UserBillingStripeRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import com.folio.backend.persistence.repository.VaultBackupRepository;
import com.folio.backend.storage.StorageService;
import com.stripe.model.Subscription;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Port of requestAccountDeletion / cancelAccountDeletion / exportAccountData / purgeUserAccount
 * (functions/src/index.ts).
 *
 * <p>Sin IdP externo (auth propio JWT): no hace falta un trigger separado equivalente a Firebase
 * {@code onUserDeleted} — el purge lo ejecuta el job programado ({@code
 * processScheduledAccountDeletions}) o una invocación directa de {@link #purgeUserAccount(String)}.
 */
@Service
public class AccountDeletionService {

  private static final Logger log = LoggerFactory.getLogger(AccountDeletionService.class);

  static final Duration DELETION_GRACE = Duration.ofDays(30);
  static final int EXPORT_LIST_LIMIT = 100;
  static final int EXPORT_COLLAB_LIMIT = 50;

  private final UserRepository userRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final UserInkRepository inkRepository;
  private final UserBillingStripeRepository stripeBillingRepository;
  private final UserBillingMicrosoftStoreRepository msBillingRepository;
  private final FamilyRepository familyRepository;
  private final FamilyMemberRepository familyMemberRepository;
  private final VaultBackupRepository vaultBackupRepository;
  private final PublishedPageRepository publishedPageRepository;
  private final CommunityTemplateRepository communityTemplateRepository;
  private final CollabRoomRepository collabRoomRepository;
  private final CollabRoomMemberRepository collabRoomMemberRepository;
  private final CollabRoomMediaRepository collabRoomMediaRepository;
  private final IntegrationUserIndexRepository integrationUserIndexRepository;
  private final MicrosoftStoreProcessedPurchaseRepository msPurchaseRepository;
  private final MicrosoftStoreProcessedBackupGrantRepository msBackupGrantRepository;
  private final FolioCloudEntitlementService entitlements;
  private final StripeApiClient stripeApi;
  private final StorageService storageService;
  private final AccountDeletionService self;

  public AccountDeletionService(
      UserRepository userRepository,
      UserFolioCloudRepository folioCloudRepository,
      UserInkRepository inkRepository,
      UserBillingStripeRepository stripeBillingRepository,
      UserBillingMicrosoftStoreRepository msBillingRepository,
      FamilyRepository familyRepository,
      FamilyMemberRepository familyMemberRepository,
      VaultBackupRepository vaultBackupRepository,
      PublishedPageRepository publishedPageRepository,
      CommunityTemplateRepository communityTemplateRepository,
      CollabRoomRepository collabRoomRepository,
      CollabRoomMemberRepository collabRoomMemberRepository,
      CollabRoomMediaRepository collabRoomMediaRepository,
      IntegrationUserIndexRepository integrationUserIndexRepository,
      MicrosoftStoreProcessedPurchaseRepository msPurchaseRepository,
      MicrosoftStoreProcessedBackupGrantRepository msBackupGrantRepository,
      FolioCloudEntitlementService entitlements,
      StripeApiClient stripeApi,
      StorageService storageService,
      @Lazy AccountDeletionService self) {
    this.userRepository = userRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.inkRepository = inkRepository;
    this.stripeBillingRepository = stripeBillingRepository;
    this.msBillingRepository = msBillingRepository;
    this.familyRepository = familyRepository;
    this.familyMemberRepository = familyMemberRepository;
    this.vaultBackupRepository = vaultBackupRepository;
    this.publishedPageRepository = publishedPageRepository;
    this.communityTemplateRepository = communityTemplateRepository;
    this.collabRoomRepository = collabRoomRepository;
    this.collabRoomMemberRepository = collabRoomMemberRepository;
    this.collabRoomMediaRepository = collabRoomMediaRepository;
    this.integrationUserIndexRepository = integrationUserIndexRepository;
    this.msPurchaseRepository = msPurchaseRepository;
    this.msBackupGrantRepository = msBackupGrantRepository;
    this.entitlements = entitlements;
    this.stripeApi = stripeApi;
    this.storageService = storageService;
    this.self = self;
  }

  @Transactional
  public DeletionScheduleResponse requestDeletion(String uid) {
    UserEntity user = requireUser(uid);
    Instant existing = user.getDeletionScheduledFor();
    if (existing != null) {
      return new DeletionScheduleResponse(existing);
    }
    Instant now = Instant.now().truncatedTo(ChronoUnit.MICROS);
    Instant scheduled = now.plus(DELETION_GRACE);
    user.setDeletionRequestedAt(now);
    user.setDeletionScheduledFor(scheduled);
    userRepository.save(user);
    return new DeletionScheduleResponse(scheduled);
  }

  @Transactional
  public CancelDeletionResponse cancelDeletion(String uid) {
    UserEntity user = requireUser(uid);
    Instant scheduled = user.getDeletionScheduledFor();
    if (scheduled != null && scheduled.isBefore(Instant.now())) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Account deletion pending");
    }
    user.setDeletionRequestedAt(null);
    user.setDeletionScheduledFor(null);
    userRepository.save(user);
    return new CancelDeletionResponse(true);
  }

  @Transactional(readOnly = true)
  public AccountExportResponse exportAccountData(String uid) {
    UserEntity user = requireUser(uid);
    UserFolioCloudEntity cloud =
        folioCloudRepository.findById(uid).orElseGet(() -> UserFolioCloudEntity.defaultsFor(uid));
    UserInkEntity ink = inkRepository.findById(uid).orElseGet(() -> UserInkEntity.defaultsFor(uid));
    UserBillingStripeEntity stripeBilling = stripeBillingRepository.findById(uid).orElse(null);
    UserBillingMicrosoftStoreEntity msBilling = msBillingRepository.findById(uid).orElse(null);

    PageRequest listLimit = PageRequest.of(0, EXPORT_LIST_LIMIT);
    PageRequest collabLimit = PageRequest.of(0, EXPORT_COLLAB_LIMIT);

    List<VaultBackupEntity> vaults =
        vaultBackupRepository.findByUserIdOrderByVaultIdAsc(uid, listLimit);
    List<PublishedPageEntity> pages =
        publishedPageRepository.findByOwnerUidOrderByUpdatedAtDesc(uid, listLimit);
    List<CommunityTemplateEntity> templates =
        communityTemplateRepository.findByOwnerUidOrderByUpdatedAtDesc(uid, listLimit);

    Map<UUID, Map<String, Object>> collabRooms = new LinkedHashMap<>();
    for (CollabRoomEntity room : collabRoomRepository.findByOwnerUid(uid, collabLimit)) {
      collabRooms.put(room.getId(), toCollabRoomExport(room));
    }
    for (CollabRoomMemberEntity membership :
        collabRoomMemberRepository.findByMemberUid(uid, collabLimit)) {
      if (collabRooms.containsKey(membership.getRoomId())) {
        continue;
      }
      if (collabRooms.size() >= EXPORT_COLLAB_LIMIT) {
        break;
      }
      collabRoomRepository
          .findById(membership.getRoomId())
          .ifPresent(room -> collabRooms.put(room.getId(), toCollabRoomExport(room)));
    }

    Map<String, Object> family = resolveFamilyExport(uid, cloud);

    Map<String, Object> data = new LinkedHashMap<>();
    data.put("uid", uid);
    data.put("email", user.getEmail());
    data.put("displayName", user.getDisplayName());
    data.put("createdAt", user.getCreatedAt() != null ? user.getCreatedAt().toString() : null);
    data.put("folioCloud", toFolioCloudExport(cloud));
    data.put("billing", summarizedBillingForExport(stripeBilling, msBilling, cloud));
    data.put("ink", toInkExport(ink));
    data.put("family", family);
    data.put(
        "vaultBackups",
        vaults.stream()
            .map(
                v -> {
                  Map<String, Object> row = new LinkedHashMap<>();
                  row.put("vaultId", v.getVaultId());
                  row.put("latestStoragePath", v.getLatestStoragePath());
                  row.put("latestSizeBytes", v.getLatestSizeBytes());
                  row.put("contentFingerprint", v.getContentFingerprint());
                  row.put(
                      "updatedAt", v.getUpdatedAt() != null ? v.getUpdatedAt().toString() : null);
                  return row;
                })
            .toList());
    data.put(
        "publishedPages",
        pages.stream()
            .map(
                p -> {
                  Map<String, Object> row = new LinkedHashMap<>();
                  row.put("id", p.getId().toString());
                  row.put("storagePath", p.getStoragePath());
                  row.put(
                      "updatedAt", p.getUpdatedAt() != null ? p.getUpdatedAt().toString() : null);
                  return row;
                })
            .toList());
    data.put(
        "communityTemplates",
        templates.stream()
            .map(
                t -> {
                  Map<String, Object> row = new LinkedHashMap<>();
                  row.put("id", t.getId().toString());
                  row.put("name", t.getName());
                  row.put("blockCount", t.getBlockCount());
                  row.put("storagePath", t.getStoragePath());
                  row.put(
                      "updatedAt", t.getUpdatedAt() != null ? t.getUpdatedAt().toString() : null);
                  return row;
                })
            .toList());
    data.put("collabRooms", new ArrayList<>(collabRooms.values()));

    return new AccountExportResponse(Instant.now(), data);
  }

  /**
   * Cascada completa de borrado de cuenta. Cada paso externo (Stripe, Storage) está envuelto para
   * que un fallo no aborte el resto.
   */
  @Transactional
  public void purgeUserAccount(String uid) {
    if (uid == null || uid.isBlank()) {
      return;
    }
    UserEntity user = userRepository.findById(uid).orElse(null);
    if (user == null) {
      return;
    }

    cancelAndDeleteStripeCustomer(uid, user.getStripeCustomerId());
    detachFromFamilyAsMember(uid);
    dissolveOwnedFamily(uid);
    deleteOwnedCollabRooms(uid);
    removeCollabMemberships(uid);
    clearCollabUpdatedBy(uid);

    deleteStoragePrefixBestEffort("users/" + uid + "/");
    deleteStoragePrefixBestEffort("published/" + uid + "/");
    deleteStoragePrefixBestEffort("community-templates/" + uid + "/");

    try {
      publishedPageRepository.deleteByOwnerUid(uid);
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: delete published_pages failed {}", uid, e);
    }
    try {
      communityTemplateRepository.deleteByOwnerUid(uid);
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: delete community_templates failed {}", uid, e);
    }
    try {
      integrationUserIndexRepository.deleteByUserId(uid);
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: delete integration_user_index failed {}", uid, e);
    }
    try {
      msPurchaseRepository.deleteByUserId(uid);
      msBackupGrantRepository.deleteByUserId(uid);
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: delete microsoft_store processed rows failed {}", uid, e);
    }

    // Defensive: clear any remaining family_owner_uid pointers at this user before DELETE.
    try {
      for (UserFolioCloudEntity pointing : folioCloudRepository.findByFamilyOwnerUid(uid)) {
        pointing.setFamilyOwnerUid(null);
        folioCloudRepository.save(pointing);
      }
      folioCloudRepository.flush();
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: clear inbound family_owner_uid failed {}", uid, e);
    }

    userRepository.deleteById(uid);
  }

  /** Invocable por el job programado: usuarios con deletion_scheduled_for &lt;= now. */
  public void processScheduledAccountDeletions() {
    Instant now = Instant.now();
    List<UserEntity> due = userRepository.findByDeletionScheduledForLessThanEqual(now);
    for (UserEntity user : due) {
      String uid = user.getId();
      try {
        // Via proxy so each purge runs in its own @Transactional boundary.
        self.purgeUserAccount(uid);
      } catch (Exception e) {
        log.error("processScheduledAccountDeletions failed {}", uid, e);
      }
    }
  }

  private void cancelAndDeleteStripeCustomer(String uid, String stripeCustomerId) {
    String customerId = stripeCustomerId == null ? "" : stripeCustomerId.trim();
    if (customerId.isEmpty() || !stripeApi.isConfigured(false)) {
      return;
    }
    try {
      List<Subscription> subs = stripeApi.listSubscriptions(false, customerId);
      for (Subscription sub : subs) {
        String status = sub.getStatus() == null ? "" : sub.getStatus();
        if ("canceled".equals(status) || "incomplete_expired".equals(status)) {
          continue;
        }
        try {
          stripeApi.cancelSubscription(false, sub.getId());
        } catch (Exception e) {
          log.warn("purgeUserAccount: cancel subscription failed {} {} {}", uid, sub.getId(), e.toString());
        }
      }
    } catch (Exception e) {
      log.warn("purgeUserAccount: list subscriptions failed {} {}", uid, e.toString());
    }
    try {
      stripeApi.deleteCustomer(false, customerId);
    } catch (Exception e) {
      log.warn(
          "purgeUserAccount: delete customer failed {} {} {}", uid, customerId, e.toString());
    }
  }

  private void detachFromFamilyAsMember(String uid) {
    UserFolioCloudEntity cloud = folioCloudRepository.findById(uid).orElse(null);
    String familyOwnerUid =
        cloud != null && cloud.getFamilyOwnerUid() != null ? cloud.getFamilyOwnerUid().trim() : "";
    if (familyOwnerUid.isEmpty()) {
      familyOwnerUid =
          familyMemberRepository
              .findByIdMemberUid(uid)
              .map(m -> m.getId().getFamilyOwnerUid())
              .orElse("");
    }
    if (familyOwnerUid.isEmpty()) {
      return;
    }
    try {
      familyMemberRepository.deleteById(
          new FamilyMemberEntity.FamilyMemberId(familyOwnerUid, uid));
      familyMemberRepository.flush();
      if (cloud != null) {
        cloud.setFamilyOwnerUid(null);
        folioCloudRepository.saveAndFlush(cloud);
      }
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: remove from family failed {} {}", uid, familyOwnerUid, e);
    }
    try {
      entitlements.recomputeEffectiveFolioCloud(familyOwnerUid);
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: recompute family owner failed {}", familyOwnerUid, e);
    }
  }

  private void dissolveOwnedFamily(String uid) {
    if (!familyRepository.existsById(uid)) {
      return;
    }
    List<FamilyMemberEntity> members = familyMemberRepository.findByIdFamilyOwnerUid(uid);
    List<String> memberUids =
        members.stream()
            .map(m -> m.getId().getMemberUid())
            .filter(memberUid -> memberUid != null && !memberUid.equals(uid))
            .toList();
    // Drop memberships before recompute — otherwise recompute restores familyOwnerUid from the table.
    try {
      familyMemberRepository.deleteAll(members);
      familyRepository.deleteById(uid);
      familyMemberRepository.flush();
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: delete family doc failed {}", uid, e);
    }
    for (String memberUid : memberUids) {
      try {
        UserFolioCloudEntity memberCloud =
            folioCloudRepository
                .findById(memberUid)
                .orElseGet(() -> UserFolioCloudEntity.defaultsFor(memberUid));
        memberCloud.setFamilyOwnerUid(null);
        folioCloudRepository.saveAndFlush(memberCloud);
      } catch (RuntimeException e) {
        log.warn("purgeUserAccount: clear member familyOwnerUid failed {}", memberUid, e);
      }
      try {
        entitlements.recomputeEffectiveFolioCloud(memberUid);
      } catch (RuntimeException e) {
        log.warn("purgeUserAccount: recompute former family member failed {}", memberUid, e);
      }
    }
  }

  private void deleteOwnedCollabRooms(String uid) {
    for (CollabRoomEntity room : collabRoomRepository.findByOwnerUid(uid)) {
      UUID roomId = room.getId();
      deleteStoragePrefixBestEffort("collab-media-e2e/" + roomId + "/");
      try {
        collabRoomMediaRepository.deleteByRoomId(roomId);
        collabRoomMemberRepository.deleteByRoomId(roomId);
        collabRoomRepository.deleteById(roomId);
      } catch (RuntimeException e) {
        log.warn("purgeUserAccount: delete owned collab room failed {} {}", roomId, e);
      }
    }
  }

  private void removeCollabMemberships(String uid) {
    for (CollabRoomMemberEntity membership : collabRoomMemberRepository.findByMemberUid(uid)) {
      try {
        CollabRoomEntity room = collabRoomRepository.findById(membership.getRoomId()).orElse(null);
        if (room != null && uid.equals(room.getOwnerUid())) {
          continue;
        }
        collabRoomMemberRepository.deleteByRoomIdAndMemberUid(membership.getRoomId(), uid);
      } catch (RuntimeException e) {
        log.warn(
            "purgeUserAccount: remove collab member failed {} {}",
            membership.getRoomId(),
            uid,
            e);
      }
    }
  }

  private void clearCollabUpdatedBy(String uid) {
    try {
      collabRoomRepository.clearUpdatedBy(uid);
    } catch (RuntimeException e) {
      log.warn("purgeUserAccount: clear collab updated_by failed {}", uid, e);
    }
  }

  private void deleteStoragePrefixBestEffort(String prefix) {
    try {
      storageService.deletePrefix(prefix);
    } catch (Exception e) {
      log.warn("purgeUserAccount: deleteStoragePrefix failed {} {}", prefix, e.toString());
    }
  }

  private Map<String, Object> resolveFamilyExport(String uid, UserFolioCloudEntity cloud) {
    if (familyRepository.existsById(uid)) {
      FamilyEntity family = familyRepository.findById(uid).orElse(null);
      List<FamilyMemberEntity> members = familyMemberRepository.findByIdFamilyOwnerUid(uid);
      Map<String, Object> out = new LinkedHashMap<>();
      out.put("role", "owner");
      out.put(
          "members",
          members.stream().map(m -> m.getId().getMemberUid()).toList());
      if (family != null && family.getCreatedAt() != null) {
        out.put("createdAt", family.getCreatedAt().toString());
      }
      return out;
    }
    String familyOwnerUid =
        cloud.getFamilyOwnerUid() != null ? cloud.getFamilyOwnerUid().trim() : "";
    if (!familyOwnerUid.isEmpty()) {
      Map<String, Object> out = new LinkedHashMap<>();
      out.put("role", "member");
      out.put("ownerUid", familyOwnerUid);
      return out;
    }
    return Map.of("role", "none");
  }

  private static Map<String, Object> summarizedBillingForExport(
      UserBillingStripeEntity stripe,
      UserBillingMicrosoftStoreEntity ms,
      UserFolioCloudEntity cloud) {
    Map<String, Object> out = new LinkedHashMap<>();
    if (cloud != null) {
      out.put("studentVerified", cloud.isStudentVerified());
    } else if (stripe != null) {
      out.put("studentVerified", stripe.isStudentVerified());
    }
    if (stripe != null) {
      Map<String, Object> stripeOut = new LinkedHashMap<>();
      if (cloud != null && cloud.getSubscriptionStatus() != null) {
        stripeOut.put("subscriptionStatus", cloud.getSubscriptionStatus());
      }
      if (stripe.getPriceId() != null) {
        stripeOut.put("subscriptionPriceId", stripe.getPriceId());
      }
      if (cloud != null) {
        stripeOut.put("active", cloud.isActive());
      }
      stripeOut.put("familySeats", stripe.getFamilySeats());
      out.put("stripe", stripeOut);
    }
    if (ms != null) {
      Map<String, Object> msOut = new LinkedHashMap<>();
      msOut.put("subscriptionActive", ms.isSubscriptionActive());
      if (ms.getSubscriptionStoreProductId() != null) {
        msOut.put("subscriptionStoreProductId", ms.getSubscriptionStoreProductId());
      }
      if (ms.getLastValidatedAt() != null) {
        msOut.put("lastValidatedAt", ms.getLastValidatedAt().toString());
      }
      if (ms.getLastItemCount() != null) {
        msOut.put("lastItemCount", ms.getLastItemCount());
      }
      out.put("microsoftStore", msOut);
    }
    return out.isEmpty() ? null : out;
  }

  private static Map<String, Object> toFolioCloudExport(UserFolioCloudEntity cloud) {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("active", cloud.isActive());
    out.put("subscriptionStatus", cloud.getSubscriptionStatus());
    out.put("subscriptionPriceId", cloud.getSubscriptionPriceId());
    out.put("isFamily", cloud.isFamily());
    out.put("isStudent", cloud.isStudent());
    out.put("studentVerified", cloud.isStudentVerified());
    out.put("familyOwnerUid", cloud.getFamilyOwnerUid());
    out.put("familySeats", cloud.getFamilySeats());
    out.put("features", cloud.getFeatures());
    return out;
  }

  private static Map<String, Object> toInkExport(UserInkEntity ink) {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("monthlyBalance", ink.getMonthlyBalance());
    out.put("purchasedBalance", ink.getPurchasedBalance());
    out.put("monthlyPeriodKey", ink.getMonthlyPeriodKey());
    return out;
  }

  private static Map<String, Object> toCollabRoomExport(CollabRoomEntity room) {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("id", room.getId().toString());
    out.put("ownerUid", room.getOwnerUid());
    out.put("vaultPageId", room.getVaultPageId());
    out.put("joinCodeKey", room.getJoinCodeKey());
    out.put("e2eV", room.getE2eV());
    out.put("contentVersion", room.getContentVersion());
    out.put("title", room.getTitle());
    out.put("updatedAt", room.getUpdatedAt() != null ? room.getUpdatedAt().toString() : null);
    return out;
  }

  private UserEntity requireUser(String uid) {
    return userRepository
        .findById(uid)
        .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "user_not_found", "User not found"));
  }
}
