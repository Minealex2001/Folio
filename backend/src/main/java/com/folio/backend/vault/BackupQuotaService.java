package com.folio.backend.vault;

import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.UserBackupUsageEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.repository.UserBackupUsageRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserRepository;
import com.folio.backend.storage.FolioCloudFeatureGate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BackupQuotaService {

  public static final long FREE_BACKUP_QUOTA_BYTES = 500L * 1024 * 1024;
  public static final long PAID_BACKUP_BASE_QUOTA_BYTES = 5L * 1024 * 1024 * 1024;
  public static final long STUDENT_BACKUP_BASE_QUOTA_BYTES = 15L * 1024 * 1024 * 1024;

  private final UserBackupUsageRepository usageRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final UserRepository userRepository;
  private final FolioCloudFeatureGate featureGate;

  public BackupQuotaService(
      UserBackupUsageRepository usageRepository,
      UserFolioCloudRepository folioCloudRepository,
      UserRepository userRepository,
      FolioCloudFeatureGate featureGate) {
    this.usageRepository = usageRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.userRepository = userRepository;
    this.featureGate = featureGate;
  }

  public void requireBackup(String uid) {
    if (!featureGate.backupOk(uid)) {
      throw new ApiException(
          HttpStatus.FORBIDDEN,
          "permission_denied",
          "Folio Cloud backup is not active for this account.");
    }
  }

  @Transactional
  public UserBackupUsageEntity getOrCreateUsage(String uid) {
    return usageRepository
        .findById(uid)
        .orElseGet(() -> usageRepository.save(UserBackupUsageEntity.defaultsFor(uid)));
  }

  public long effectiveQuotaBytes(String uid) {
    if (featureGate.isStaff(uid)) {
      return Long.MAX_VALUE / 4;
    }
    UserBackupUsageEntity usage = getOrCreateUsage(uid);
    UserFolioCloudEntity cloud =
        folioCloudRepository.findById(uid).orElse(null);
    if (cloud == null || !cloud.isActive() || !featureGate.backupOk(uid)) {
      return 0;
    }
    // Free plan: price_id null/blank → 500 MiB; paid → base (+ student).
    boolean freePlan =
        cloud.getSubscriptionPriceId() == null || cloud.getSubscriptionPriceId().isBlank();
    long base =
        freePlan
            ? FREE_BACKUP_QUOTA_BYTES
            : (cloud.isStudent() ? STUDENT_BACKUP_BASE_QUOTA_BYTES : PAID_BACKUP_BASE_QUOTA_BYTES);
    return base + Math.max(0, usage.getPurchasedBytes());
  }

  @Transactional
  public void applyDelta(String uid, long deltaBytes) {
    UserBackupUsageEntity usage = getOrCreateUsage(uid);
    long quota = effectiveQuotaBytes(uid);
    long newUsed = Math.max(0, usage.getUsedBytes() + deltaBytes);
    if (quota > 0 && newUsed > quota) {
      throw new ApiException(
          HttpStatus.INSUFFICIENT_STORAGE,
          "resource_exhausted",
          "Se superó la cuota de almacenamiento de copias en la nube.");
    }
    usage.setUsedBytes(newUsed);
    usageRepository.save(usage);
  }

  @Transactional
  public void setUsedBytes(String uid, long usedBytes) {
    UserBackupUsageEntity usage = getOrCreateUsage(uid);
    usage.setUsedBytes(Math.max(0, usedBytes));
    usageRepository.save(usage);
  }
}
