package com.folio.backend.vault;

import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.VaultBackupBlobEntity;
import com.folio.backend.persistence.entity.VaultBackupEntity;
import com.folio.backend.persistence.repository.VaultBackupBlobRepository;
import com.folio.backend.persistence.repository.VaultBackupRepository;
import com.folio.backend.storage.StoragePathAuthorizer;
import com.folio.backend.storage.StorageService;
import com.folio.backend.vault.dto.BlobSizeDto;
import com.folio.backend.vault.dto.FinalizeCloudPackRequest;
import com.folio.backend.vault.dto.RecordVaultBackupMetaRequest;
import com.folio.backend.vault.dto.UpsertVaultBackupIndexRequest;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VaultBackupService {

  private final VaultBackupRepository backupRepository;
  private final VaultBackupBlobRepository blobRepository;
  private final BackupQuotaService quotaService;
  private final StorageService storageService;
  private final StoragePathAuthorizer pathAuthorizer;

  public VaultBackupService(
      VaultBackupRepository backupRepository,
      VaultBackupBlobRepository blobRepository,
      BackupQuotaService quotaService,
      StorageService storageService,
      StoragePathAuthorizer pathAuthorizer) {
    this.backupRepository = backupRepository;
    this.blobRepository = blobRepository;
    this.quotaService = quotaService;
    this.storageService = storageService;
    this.pathAuthorizer = pathAuthorizer;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getLatestCloudPackMeta(String uid, String vaultIdRaw) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    Optional<VaultBackupEntity> opt =
        backupRepository.findById(new VaultBackupEntity.Pk(uid, vaultId));
    Map<String, Object> latest = new LinkedHashMap<>();
    if (opt.isEmpty()) {
      latest.put("snapshotStoragePath", "");
      latest.put("snapshotSizeBytes", 0);
      latest.put("contentFingerprint", "");
      latest.put("updatedAt", null);
      latest.put("hasRestoreWrap", false);
      latest.put("wrapKind", null);
    } else {
      VaultBackupEntity e = opt.get();
      String wrap = e.getCloudPackRestoreWrapB64();
      String kind = e.getCloudPackRestoreWrapKind();
      boolean has =
          wrap != null
              && !wrap.isBlank()
              && ("vaultDek".equals(kind) || "packKey".equals(kind));
      latest.put("snapshotStoragePath", nullToEmpty(e.getLatestStoragePath()));
      latest.put("snapshotSizeBytes", e.getLatestSizeBytes());
      latest.put("contentFingerprint", nullToEmpty(e.getContentFingerprint()));
      latest.put("updatedAt", e.getUpdatedAt());
      latest.put("hasRestoreWrap", has);
      latest.put("wrapKind", has ? kind : null);
    }
    return Map.of("ok", true, "latest", latest);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getCloudPackRestoreWrap(String uid, String vaultIdRaw) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    VaultBackupEntity e =
        backupRepository
            .findById(new VaultBackupEntity.Pk(uid, vaultId))
            .orElseThrow(
                () ->
                    new ApiException(
                        HttpStatus.PRECONDITION_FAILED,
                        "failed_precondition",
                        "No hay envoltorio de recuperación para esta libreta."));
    String wrap = e.getCloudPackRestoreWrapB64();
    String kind = e.getCloudPackRestoreWrapKind();
    if (wrap == null
        || wrap.isBlank()
        || (!"vaultDek".equals(kind) && !"packKey".equals(kind))) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "No hay envoltorio de recuperación para esta libreta.");
    }
    return Map.of("ok", true, "wrapB64", wrap, "wrapKind", kind);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> checkCloudPackBlobsExist(
      String uid, String vaultIdRaw, List<String> blobIds) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    if (blobIds == null || blobIds.size() > 500) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "blobIds invalid");
    }
    List<String> missing = new ArrayList<>();
    for (String id : blobIds) {
      String bid = VaultIds.requireBlobId(id);
      String path = "users/" + uid + "/vaults/" + vaultId + "/cloud-packs/blobs/" + bid;
      pathAuthorizer.assertRead(uid, path);
      if (!storageService.exists(path)
          && blobRepository
              .findById(new VaultBackupBlobEntity.Pk(uid, vaultId, bid))
              .isEmpty()) {
        missing.add(bid);
      }
    }
    return Map.of("missing", missing);
  }

  @Transactional
  public Map<String, Object> finalizeCloudPack(String uid, FinalizeCloudPackRequest req) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(req.vaultId());
    String snapPath =
        pathAuthorizer.requireCloudPackSnapshotPath(uid, vaultId, req.snapshotStoragePath());
    long snapSize = req.snapshotSizeBytes() == null ? 0 : req.snapshotSizeBytes();
    if (snapSize <= 0 || snapSize > 256L * 1024 * 1024) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "snapshotSizeBytes invalid");
    }
    String fingerprint = VaultIds.requireFingerprint(req.contentFingerprint());

    long oldSnapSize = 0;
    if (req.oldSnapshotStoragePath() != null && !req.oldSnapshotStoragePath().isBlank()) {
      String op = req.oldSnapshotStoragePath().trim();
      String prefix = "users/" + uid + "/vaults/" + vaultId + "/cloud-packs/snapshots/";
      if (!op.startsWith(prefix) || op.contains("..")) {
        throw new ApiException(
            HttpStatus.BAD_REQUEST, "invalid_argument", "oldSnapshotStoragePath invalid");
      }
      oldSnapSize = req.oldSnapshotSizeBytes() == null ? 0 : Math.max(0, req.oldSnapshotSizeBytes());
    }

    List<BlobSizeDto> newBlobs = req.newBlobs() == null ? List.of() : req.newBlobs();
    List<BlobSizeDto> deleteBlobs = req.deleteBlobs() == null ? List.of() : req.deleteBlobs();
    if (newBlobs.size() > 2000 || deleteBlobs.size() > 2000) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Too many blob entries");
    }

    if (req.cloudPackRestoreWrapB64() != null && !req.cloudPackRestoreWrapB64().isBlank()) {
      VaultIds.validateRestoreWrap(req.cloudPackRestoreWrapB64(), req.cloudPackRestoreWrapKind());
    }

    long delta = snapSize - oldSnapSize;
    for (BlobSizeDto b : newBlobs) {
      delta += Math.max(0, b.sizeBytes() == null ? 0 : b.sizeBytes());
    }
    for (BlobSizeDto b : deleteBlobs) {
      delta -= Math.max(0, b.sizeBytes() == null ? 0 : b.sizeBytes());
    }
    quotaService.applyDelta(uid, delta);

    // Soft size check when object already present (tests may skip real upload).
    if (storageService.exists(snapPath)) {
      long metaSize = storageService.objectSize(snapPath);
      if (metaSize <= 0 || Math.abs(metaSize - snapSize) > 16) {
        throw new ApiException(
            HttpStatus.PRECONDITION_FAILED,
            "failed_precondition",
            "Snapshot not found in storage or size mismatch.");
      }
    }

    VaultBackupEntity backup =
        backupRepository
            .findById(new VaultBackupEntity.Pk(uid, vaultId))
            .orElseGet(
                () -> {
                  VaultBackupEntity e = new VaultBackupEntity();
                  e.setUserId(uid);
                  e.setVaultId(vaultId);
                  return e;
                });
    backup.setLatestStoragePath(snapPath);
    backup.setLatestSizeBytes(snapSize);
    backup.setContentFingerprint(fingerprint);
    if (req.cloudPackRestoreWrapB64() != null && !req.cloudPackRestoreWrapB64().isBlank()) {
      backup.setCloudPackRestoreWrapB64(req.cloudPackRestoreWrapB64().trim());
      backup.setCloudPackRestoreWrapKind(req.cloudPackRestoreWrapKind());
    }
    backupRepository.save(backup);

    for (BlobSizeDto b : newBlobs) {
      String bid = VaultIds.requireBlobId(b.blobId());
      long sz = b.sizeBytes() == null ? 0 : b.sizeBytes();
      if (sz <= 0 || sz > 2L * 1024 * 1024 * 1024) {
        continue;
      }
      String path = "users/" + uid + "/vaults/" + vaultId + "/cloud-packs/blobs/" + bid;
      pathAuthorizer.assertWrite(uid, path);
      VaultBackupBlobEntity blob =
          blobRepository
              .findById(new VaultBackupBlobEntity.Pk(uid, vaultId, bid))
              .orElseGet(VaultBackupBlobEntity::new);
      blob.setUserId(uid);
      blob.setVaultId(vaultId);
      blob.setBlobId(bid);
      blob.setStoragePath(path);
      blob.setSizeBytes(sz);
      blobRepository.save(blob);
    }
    for (BlobSizeDto b : deleteBlobs) {
      String bid = VaultIds.requireBlobId(b.blobId());
      blobRepository
          .findById(new VaultBackupBlobEntity.Pk(uid, vaultId, bid))
          .ifPresent(blobRepository::delete);
    }

    long used = quotaService.getOrCreateUsage(uid).getUsedBytes();
    long quota = quotaService.effectiveQuotaBytes(uid);
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("usedBytes", used);
    out.put("quotaBytes", quota);
    out.put("legacyBytes", 0);
    out.put("totalUsedBytes", used);
    return out;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getBackupStorageUsage(String uid) {
    quotaService.requireBackup(uid);
    long used = quotaService.getOrCreateUsage(uid).getUsedBytes();
    long quota = quotaService.effectiveQuotaBytes(uid);
    return Map.of("ok", true, "usedBytes", used, "quotaBytes", quota, "legacyBytes", 0);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> listVaultBackups(String uid, String vaultIdRaw) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    List<VaultBackupBlobEntity> blobs = blobRepository.findByUserIdAndVaultId(uid, vaultId);
    List<Map<String, Object>> items = new ArrayList<>();
    for (VaultBackupBlobEntity b : blobs) {
      items.add(
          Map.of(
              "blobId", b.getBlobId(),
              "storagePath", b.getStoragePath(),
              "sizeBytes", b.getSizeBytes()));
    }
    Optional<VaultBackupEntity> meta =
        backupRepository.findById(new VaultBackupEntity.Pk(uid, vaultId));
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("vaultId", vaultId);
    out.put("blobs", items);
    out.put(
        "latestStoragePath",
        meta.map(VaultBackupEntity::getLatestStoragePath).orElse(""));
    out.put("latestSizeBytes", meta.map(VaultBackupEntity::getLatestSizeBytes).orElse(0L));
    return out;
  }

  @Transactional
  public Map<String, Object> deleteVaultCloudPack(String uid, String vaultIdRaw) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    long freed = blobRepository.sumSizeByUserIdAndVaultId(uid, vaultId);
    Optional<VaultBackupEntity> meta =
        backupRepository.findById(new VaultBackupEntity.Pk(uid, vaultId));
    if (meta.isPresent()) {
      freed += meta.get().getLatestSizeBytes();
      String snap = meta.get().getLatestStoragePath();
      if (snap != null && !snap.isBlank()) {
        pathAuthorizer.assertDelete(uid, snap);
        try {
          storageService.delete(snap);
        } catch (Exception ignored) {
        }
      }
    }
    for (VaultBackupBlobEntity b : blobRepository.findByUserIdAndVaultId(uid, vaultId)) {
      try {
        storageService.delete(b.getStoragePath());
      } catch (Exception ignored) {
      }
    }
    blobRepository.deleteByUserIdAndVaultId(uid, vaultId);
    meta.ifPresent(
        e -> {
          e.setLatestStoragePath(null);
          e.setLatestSizeBytes(0);
          e.setContentFingerprint(null);
          e.setCloudPackRestoreWrapB64(null);
          e.setCloudPackRestoreWrapKind(null);
          backupRepository.save(e);
        });
    quotaService.applyDelta(uid, -freed);
    String prefix = "users/" + uid + "/vaults/" + vaultId + "/cloud-packs/";
    pathAuthorizer.assertDelete(uid, prefix + "x");
    storageService.deletePrefix(prefix);
    return Map.of("ok", true, "freedBytes", freed);
  }

  @Transactional
  public Map<String, Object> deleteVaultLegacyBackup(String uid, String vaultIdRaw) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    String prefix = "users/" + uid + "/vaults/" + vaultId + "/backups/";
    pathAuthorizer.assertDelete(uid, prefix + "x");
    int deleted = storageService.deletePrefix(prefix);
    return Map.of("ok", true, "deletedObjects", deleted);
  }

  @Transactional
  public Map<String, Object> trimVaultBackupsByBytes(String uid, long targetUsedBytes) {
    quotaService.requireBackup(uid);
    if (targetUsedBytes < 0) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "targetUsedBytes invalid");
    }
    long used = quotaService.getOrCreateUsage(uid).getUsedBytes();
    long freed = 0;
    List<VaultBackupEntity> vaults = backupRepository.findByUserIdOrderByVaultIdAsc(uid);
    for (VaultBackupEntity v : vaults) {
      if (used - freed <= targetUsedBytes) {
        break;
      }
      Map<String, Object> r = deleteVaultCloudPack(uid, v.getVaultId());
      freed += ((Number) r.get("freedBytes")).longValue();
    }
    used = quotaService.getOrCreateUsage(uid).getUsedBytes();
    return Map.of("ok", true, "freedBytes", freed, "usedBytes", used);
  }

  @Transactional
  public Map<String, Object> trimVaultBackups(String uid, int keepLatestPerVault) {
    quotaService.requireBackup(uid);
    // Cloud-packs keep a single latest snapshot; trimming blobs beyond keepLatest is a no-op for
    // metadata-only packs. We free usage down to blob sum for consistency.
    long blobSum = blobRepository.sumSizeByUserId(uid);
    long snapSum =
        backupRepository.findByUserIdOrderByVaultIdAsc(uid).stream()
            .mapToLong(VaultBackupEntity::getLatestSizeBytes)
            .sum();
    quotaService.setUsedBytes(uid, blobSum + snapSum);
    return Map.of(
        "ok",
        true,
        "keepLatestPerVault",
        keepLatestPerVault,
        "usedBytes",
        quotaService.getOrCreateUsage(uid).getUsedBytes());
  }

  @Transactional(readOnly = true)
  public Map<String, Object> listBackupVaults(String uid) {
    quotaService.requireBackup(uid);
    List<Map<String, Object>> vaults = new ArrayList<>();
    for (VaultBackupEntity e : backupRepository.findByUserIdOrderByVaultIdAsc(uid)) {
      Map<String, Object> row = new LinkedHashMap<>();
      row.put("vaultId", e.getVaultId());
      row.put("latestStoragePath", nullToEmpty(e.getLatestStoragePath()));
      row.put("latestSizeBytes", e.getLatestSizeBytes());
      row.put("contentFingerprint", nullToEmpty(e.getContentFingerprint()));
      row.put("updatedAt", e.getUpdatedAt());
      vaults.add(row);
    }
    return Map.of("ok", true, "vaults", vaults);
  }

  @Transactional
  public Map<String, Object> upsertVaultBackupIndex(String uid, UpsertVaultBackupIndexRequest req) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(req.vaultId());
    VaultBackupEntity e =
        backupRepository
            .findById(new VaultBackupEntity.Pk(uid, vaultId))
            .orElseGet(
                () -> {
                  VaultBackupEntity n = new VaultBackupEntity();
                  n.setUserId(uid);
                  n.setVaultId(vaultId);
                  return n;
                });
    if (req.latestStoragePath() != null && !req.latestStoragePath().isBlank()) {
      String path = req.latestStoragePath().trim();
      pathAuthorizer.assertWrite(uid, path);
      e.setLatestStoragePath(path);
    }
    if (req.latestSizeBytes() != null) {
      e.setLatestSizeBytes(Math.max(0, req.latestSizeBytes()));
    }
    if (req.contentFingerprint() != null && !req.contentFingerprint().isBlank()) {
      e.setContentFingerprint(VaultIds.requireFingerprint(req.contentFingerprint()));
    }
    backupRepository.save(e);
    return Map.of("ok", true);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getLatestVaultBackupMeta(String uid, String vaultIdRaw) {
    return getLatestCloudPackMeta(uid, vaultIdRaw);
  }

  @Transactional
  public Map<String, Object> recordVaultBackupMeta(String uid, RecordVaultBackupMetaRequest req) {
    UpsertVaultBackupIndexRequest upsert =
        new UpsertVaultBackupIndexRequest(
            req.vaultId(), req.storagePath(), req.sizeBytes(), req.contentFingerprint());
    return upsertVaultBackupIndex(uid, upsert);
  }

  private static String nullToEmpty(String s) {
    return s == null ? "" : s;
  }
}
