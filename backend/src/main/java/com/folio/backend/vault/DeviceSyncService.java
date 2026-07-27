package com.folio.backend.vault;

import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.UserPlainVaultSyncSecretEntity;
import com.folio.backend.persistence.entity.UserVaultSyncEntity;
import com.folio.backend.persistence.repository.UserPlainVaultSyncSecretRepository;
import com.folio.backend.persistence.repository.UserVaultSyncRepository;
import com.folio.backend.storage.StoragePathAuthorizer;
import com.folio.backend.storage.StorageService;
import com.folio.backend.vault.dto.BlobSizeDto;
import com.folio.backend.vault.dto.FinalizeDeviceSyncRequest;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DeviceSyncService {

  private final UserVaultSyncRepository syncRepository;
  private final UserPlainVaultSyncSecretRepository secretRepository;
  private final BackupQuotaService quotaService;
  private final StoragePathAuthorizer pathAuthorizer;
  private final StorageService storageService;
  private final SecureRandom secureRandom = new SecureRandom();

  public DeviceSyncService(
      UserVaultSyncRepository syncRepository,
      UserPlainVaultSyncSecretRepository secretRepository,
      BackupQuotaService quotaService,
      StoragePathAuthorizer pathAuthorizer,
      StorageService storageService) {
    this.syncRepository = syncRepository;
    this.secretRepository = secretRepository;
    this.quotaService = quotaService;
    this.pathAuthorizer = pathAuthorizer;
    this.storageService = storageService;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getDeviceSyncMeta(String uid, String vaultIdRaw) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    UserVaultSyncEntity e =
        syncRepository
            .findById(new UserVaultSyncEntity.Pk(uid, vaultId))
            .orElse(null);
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    if (e == null) {
      out.put("rev", 0);
      out.put("contentFingerprint", "");
      out.put("packStoragePath", "");
      out.put("packSizeBytes", 0);
      out.put("syncFormatVersion", 1);
      out.put("manifestStoragePath", "");
      out.put("manifestSizeBytes", 0);
      out.put("deviceId", "");
      out.put("deviceName", "");
      out.put("vaultMode", "");
      out.put("packKeyKind", "");
      out.put("dekAccountWrapB64", "");
      out.put("updatedAt", null);
      return out;
    }
    out.put("rev", e.getRev());
    out.put("contentFingerprint", nullToEmpty(e.getContentFingerprint()));
    out.put("packStoragePath", nullToEmpty(e.getPackStoragePath()));
    out.put("packSizeBytes", e.getPackSizeBytes());
    out.put("syncFormatVersion", (int) e.getSyncFormatVersion());
    out.put("manifestStoragePath", nullToEmpty(e.getManifestStoragePath()));
    out.put("manifestSizeBytes", e.getManifestSizeBytes());
    out.put("deviceId", nullToEmpty(e.getDeviceId()));
    out.put("deviceName", nullToEmpty(e.getDeviceName()));
    out.put("vaultMode", nullToEmpty(e.getVaultMode()));
    out.put("packKeyKind", nullToEmpty(e.getPackKeyKind()));
    out.put("dekAccountWrapB64", nullToEmpty(e.getDekAccountWrapB64()));
    out.put("updatedAt", e.getUpdatedAt());
    return out;
  }

  @Transactional
  public Map<String, Object> finalizeDeviceSync(String uid, FinalizeDeviceSyncRequest req) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(req.vaultId());
    int syncFormatVersion =
        req.syncFormatVersion() == null ? 1 : Math.max(1, req.syncFormatVersion());
    boolean isV2 = syncFormatVersion >= 2;
    String fingerprint = VaultIds.requireFingerprint(req.contentFingerprint());

    String packPath = "";
    long packSize = 0;
    String manifestPath = "";
    long manifestSize = 0;
    long oldPackSize = 0;
    long oldManifestSize = 0;

    if (isV2) {
      manifestPath =
          pathAuthorizer.requireDeviceSyncManifestPath(uid, vaultId, req.manifestStoragePath());
      manifestSize = req.manifestSizeBytes() == null ? 0 : req.manifestSizeBytes();
      if (manifestSize <= 0 || manifestSize > 16L * 1024 * 1024) {
        throw new ApiException(
            HttpStatus.BAD_REQUEST, "invalid_argument", "manifestSizeBytes invalid");
      }
    } else {
      packPath = pathAuthorizer.requireDeviceSyncPackPath(uid, vaultId, req.packStoragePath());
      packSize = req.packSizeBytes() == null ? 0 : req.packSizeBytes();
      if (packSize <= 0 || packSize > 80L * 1024 * 1024) {
        throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "packSizeBytes invalid");
      }
    }

    if (req.oldPackStoragePath() != null && !req.oldPackStoragePath().isBlank()) {
      try {
        pathAuthorizer.requireDeviceSyncPackPath(uid, vaultId, req.oldPackStoragePath());
        oldPackSize = req.oldPackSizeBytes() == null ? 0 : Math.max(0, req.oldPackSizeBytes());
      } catch (ApiException ignored) {
        oldPackSize = 0;
      }
    }
    if (req.oldManifestStoragePath() != null && !req.oldManifestStoragePath().isBlank()) {
      try {
        pathAuthorizer.requireDeviceSyncManifestPath(uid, vaultId, req.oldManifestStoragePath());
        oldManifestSize =
            req.oldManifestSizeBytes() == null ? 0 : Math.max(0, req.oldManifestSizeBytes());
      } catch (ApiException ignored) {
        oldManifestSize = 0;
      }
    }

    List<BlobSizeDto> newBlobs = req.newBlobs() == null ? List.of() : req.newBlobs();
    List<BlobSizeDto> deleteBlobs = req.deleteBlobs() == null ? List.of() : req.deleteBlobs();
    if (newBlobs.size() > 20000 || deleteBlobs.size() > 20000) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Too many blob entries");
    }

    String primaryPath = isV2 ? manifestPath : packPath;
    long primarySize = isV2 ? manifestSize : packSize;
    if (storageService.exists(primaryPath)) {
      long metaSize = storageService.objectSize(primaryPath);
      if (metaSize <= 0 || Math.abs(metaSize - primarySize) > 16) {
        throw new ApiException(
            HttpStatus.PRECONDITION_FAILED,
            "failed_precondition",
            "Sync pack/manifest not found in storage or size mismatch.");
      }
    }

    long delta = primarySize - (isV2 ? oldManifestSize : oldPackSize);
    if (isV2 && oldPackSize > 0) {
      delta -= oldPackSize;
    }
    for (BlobSizeDto b : newBlobs) {
      delta += Math.max(0, b.sizeBytes() == null ? 0 : b.sizeBytes());
    }
    for (BlobSizeDto b : deleteBlobs) {
      delta -= Math.max(0, b.sizeBytes() == null ? 0 : b.sizeBytes());
    }
    quotaService.applyDelta(uid, delta);

    UserVaultSyncEntity e =
        syncRepository
            .findById(new UserVaultSyncEntity.Pk(uid, vaultId))
            .orElseGet(
                () -> {
                  UserVaultSyncEntity n = new UserVaultSyncEntity();
                  n.setUserId(uid);
                  n.setVaultId(vaultId);
                  return n;
                });
    e.setRev(e.getRev() + 1);
    e.setContentFingerprint(fingerprint);
    e.setSyncFormatVersion((short) (isV2 ? 2 : 1));
    if (req.deviceId() != null && !req.deviceId().isBlank()) {
      String d = req.deviceId().trim();
      e.setDeviceId(d.substring(0, Math.min(128, d.length())));
    }
    if (req.deviceName() != null && !req.deviceName().isBlank()) {
      String d = req.deviceName().trim();
      e.setDeviceName(d.substring(0, Math.min(120, d.length())));
    }
    if (req.vaultMode() != null
        && ("plain".equals(req.vaultMode().trim()) || "encrypted".equals(req.vaultMode().trim()))) {
      e.setVaultMode(req.vaultMode().trim());
    }
    if (req.packKeyKind() != null
        && ("account".equals(req.packKeyKind().trim())
            || "vault".equals(req.packKeyKind().trim()))) {
      e.setPackKeyKind(req.packKeyKind().trim());
    }
    if (req.dekAccountWrapB64() != null && !req.dekAccountWrapB64().isBlank()) {
      String w = req.dekAccountWrapB64().trim();
      if (w.length() <= 8192) {
        e.setDekAccountWrapB64(w);
      }
    }
    if (isV2) {
      e.setManifestStoragePath(manifestPath);
      e.setManifestSizeBytes(manifestSize);
      e.setPackStoragePath("");
      e.setPackSizeBytes(0);
    } else {
      e.setPackStoragePath(packPath);
      e.setPackSizeBytes(packSize);
      e.setManifestStoragePath("");
      e.setManifestSizeBytes(0);
    }
    syncRepository.save(e);

    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("rev", e.getRev());
    out.put("usedBytes", quotaService.getOrCreateUsage(uid).getUsedBytes());
    out.put("quotaBytes", quotaService.effectiveQuotaBytes(uid));
    out.put("syncFormatVersion", (int) e.getSyncFormatVersion());
    return out;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> listDeviceSyncVaults(String uid) {
    quotaService.requireBackup(uid);
    List<Map<String, Object>> vaults = new ArrayList<>();
    for (UserVaultSyncEntity e : syncRepository.findByUserIdOrderByVaultIdAsc(uid)) {
      String pack = nullToEmpty(e.getPackStoragePath());
      String manifest = nullToEmpty(e.getManifestStoragePath());
      String fp = nullToEmpty(e.getContentFingerprint());
      Map<String, Object> row = new LinkedHashMap<>();
      row.put("vaultId", e.getVaultId());
      row.put("vaultMode", nullToEmpty(e.getVaultMode()));
      row.put("rev", e.getRev());
      row.put("contentFingerprint", fp);
      row.put("hasCloudPack", !fp.isEmpty() && (!pack.isEmpty() || !manifest.isEmpty()));
      vaults.add(row);
    }
    return Map.of("vaults", vaults);
  }

  /**
   * Get-or-create 32-byte secret. Race-safe via pessimistic lock + unique PK; on conflict re-read.
   */
  @Transactional
  public Map<String, Object> ensurePlainVaultSyncSecret(String uid, String vaultIdRaw) {
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    var existing = secretRepository.findForUpdate(uid, vaultId);
    if (existing.isPresent()) {
      return Map.of("ok", true, "secret", existing.get().getSecretB64());
    }
    byte[] bytes = new byte[32];
    secureRandom.nextBytes(bytes);
    String secret = Base64.getEncoder().encodeToString(bytes);
    UserPlainVaultSyncSecretEntity e = new UserPlainVaultSyncSecretEntity();
    e.setUserId(uid);
    e.setVaultId(vaultId);
    e.setSecretB64(secret);
    try {
      secretRepository.saveAndFlush(e);
      return Map.of("ok", true, "secret", secret);
    } catch (DataIntegrityViolationException ex) {
      return Map.of(
          "ok",
          true,
          "secret",
          secretRepository
              .findById(new UserPlainVaultSyncSecretEntity.Pk(uid, vaultId))
              .orElseThrow()
              .getSecretB64());
    }
  }

  private static String nullToEmpty(String s) {
    return s == null ? "" : s;
  }
}
