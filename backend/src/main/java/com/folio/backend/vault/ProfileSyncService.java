package com.folio.backend.vault;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.UserAppProfileEntity;
import com.folio.backend.persistence.entity.UserVaultProfileEntity;
import com.folio.backend.persistence.repository.UserAppProfileRepository;
import com.folio.backend.persistence.repository.UserVaultProfileRepository;
import com.folio.backend.storage.StoragePathAuthorizer;
import com.folio.backend.storage.StorageService;
import com.folio.backend.vault.dto.FinalizeAppProfileRequest;
import com.folio.backend.vault.dto.FinalizeVaultProfileRequest;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProfileSyncService {

  private final UserAppProfileRepository appProfileRepository;
  private final UserVaultProfileRepository vaultProfileRepository;
  private final BackupQuotaService quotaService;
  private final StoragePathAuthorizer pathAuthorizer;
  private final StorageService storageService;
  private final ObjectMapper objectMapper;

  public ProfileSyncService(
      UserAppProfileRepository appProfileRepository,
      UserVaultProfileRepository vaultProfileRepository,
      BackupQuotaService quotaService,
      StoragePathAuthorizer pathAuthorizer,
      StorageService storageService,
      ObjectMapper objectMapper) {
    this.appProfileRepository = appProfileRepository;
    this.vaultProfileRepository = vaultProfileRepository;
    this.quotaService = quotaService;
    this.pathAuthorizer = pathAuthorizer;
    this.storageService = storageService;
    this.objectMapper = objectMapper;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getAppProfileMeta(String uid) {
    quotaService.requireBackup(uid);
    return appProfileRepository
        .findById(uid)
        .map(this::appMeta)
        .orElseGet(ProfileSyncService::emptyAppMeta);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getAppProfileRestoreWrap(String uid) {
    quotaService.requireBackup(uid);
    // Paridad Firebase callable: sin wrap → 200 con string vacío (el cliente crea
    // clave local en el primer push). No 412.
    String wrap =
        appProfileRepository
            .findById(uid)
            .map(UserAppProfileEntity::getRestoreWrapB64)
            .orElse("");
    if (wrap == null) {
      wrap = "";
    }
    wrap = wrap.trim();
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("restoreWrapB64", wrap);
    out.put("wrapB64", wrap); // alias legacy / Postman
    return out;
  }

  @Transactional
  public Map<String, Object> finalizeAppProfile(String uid, FinalizeAppProfileRequest req) {
    quotaService.requireBackup(uid);
    String path = pathAuthorizer.requireAppProfilePackPath(uid, req.packStoragePath());
    long size = req.packSizeBytes() == null ? 0 : req.packSizeBytes();
    if (size <= 0 || size > 32L * 1024 * 1024) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "packSizeBytes invalid");
    }
    String fp = VaultIds.requireFingerprint(req.contentFingerprint());
    UserAppProfileEntity prev = appProfileRepository.findById(uid).orElse(null);
    long oldSize = prev == null ? 0 : prev.getPackSizeBytes();
    quotaService.applyDelta(uid, size - oldSize);
    if (storageService.exists(path)) {
      long meta = storageService.objectSize(path);
      if (meta <= 0 || Math.abs(meta - size) > 16) {
        throw new ApiException(
            HttpStatus.PRECONDITION_FAILED,
            "failed_precondition",
            "App profile pack not found or size mismatch.");
      }
    }
    UserAppProfileEntity e = prev == null ? new UserAppProfileEntity() : prev;
    e.setUserId(uid);
    e.setRev((prev == null ? 0 : prev.getRev()) + 1);
    e.setContentFingerprint(fp);
    e.setPackStoragePath(path);
    e.setPackSizeBytes(size);
    if (req.restoreWrapB64() != null && !req.restoreWrapB64().isBlank()) {
      e.setRestoreWrapB64(req.restoreWrapB64().trim());
    }
    try {
      e.setIconIds(
          req.iconIds() == null
              ? "[]"
              : objectMapper.writeValueAsString(req.iconIds()));
    } catch (Exception ex) {
      e.setIconIds("[]");
    }
    appProfileRepository.save(e);
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("rev", e.getRev());
    out.put("usedBytes", quotaService.getOrCreateUsage(uid).getUsedBytes());
    return out;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getVaultProfileMeta(String uid, String vaultIdRaw) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(vaultIdRaw);
    return vaultProfileRepository
        .findById(new UserVaultProfileEntity.Pk(uid, vaultId))
        .map(this::vaultMeta)
        .orElseGet(() -> emptyVaultMeta(vaultId));
  }

  @Transactional
  public Map<String, Object> finalizeVaultProfile(String uid, FinalizeVaultProfileRequest req) {
    quotaService.requireBackup(uid);
    String vaultId = VaultIds.requireVaultId(req.vaultId());
    String path = pathAuthorizer.requireVaultProfilePackPath(uid, vaultId, req.packStoragePath());
    long size = req.packSizeBytes() == null ? 0 : req.packSizeBytes();
    if (size <= 0 || size > 32L * 1024 * 1024) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "packSizeBytes invalid");
    }
    String fp = VaultIds.requireFingerprint(req.contentFingerprint());
    UserVaultProfileEntity prev =
        vaultProfileRepository.findById(new UserVaultProfileEntity.Pk(uid, vaultId)).orElse(null);
    long oldSize = prev == null ? 0 : prev.getPackSizeBytes();
    quotaService.applyDelta(uid, size - oldSize);
    UserVaultProfileEntity e = prev == null ? new UserVaultProfileEntity() : prev;
    e.setUserId(uid);
    e.setVaultId(vaultId);
    e.setRev((prev == null ? 0 : prev.getRev()) + 1);
    e.setContentFingerprint(fp);
    e.setPackStoragePath(path);
    e.setPackSizeBytes(size);
    if (req.restoreWrapB64() != null && !req.restoreWrapB64().isBlank()) {
      e.setRestoreWrapB64(req.restoreWrapB64().trim());
    }
    vaultProfileRepository.save(e);
    return Map.of("ok", true, "rev", e.getRev());
  }

  private Map<String, Object> appMeta(UserAppProfileEntity e) {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("rev", e.getRev());
    out.put("contentFingerprint", e.getContentFingerprint());
    out.put("packStoragePath", e.getPackStoragePath());
    out.put("packSizeBytes", e.getPackSizeBytes());
    out.put("hasRestoreWrap", e.getRestoreWrapB64() != null && !e.getRestoreWrapB64().isBlank());
    try {
      out.put("iconIds", objectMapper.readValue(e.getIconIds(), List.class));
    } catch (Exception ex) {
      out.put("iconIds", List.of());
    }
    out.put("updatedAt", e.getUpdatedAt());
    return out;
  }

  private Map<String, Object> vaultMeta(UserVaultProfileEntity e) {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("vaultId", e.getVaultId());
    out.put("rev", e.getRev());
    out.put("contentFingerprint", e.getContentFingerprint());
    out.put("packStoragePath", e.getPackStoragePath());
    out.put("packSizeBytes", e.getPackSizeBytes());
    out.put("hasRestoreWrap", e.getRestoreWrapB64() != null && !e.getRestoreWrapB64().isBlank());
    out.put("updatedAt", e.getUpdatedAt());
    return out;
  }

  /** Empty meta must allow null {@code updatedAt}; {@link Map#of} rejects null values. */
  private static Map<String, Object> emptyAppMeta() {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("rev", 0);
    out.put("contentFingerprint", "");
    out.put("packStoragePath", "");
    out.put("packSizeBytes", 0);
    out.put("hasRestoreWrap", false);
    out.put("iconIds", List.of());
    out.put("updatedAt", null);
    return out;
  }

  private static Map<String, Object> emptyVaultMeta(String vaultId) {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("ok", true);
    out.put("vaultId", vaultId);
    out.put("rev", 0);
    out.put("contentFingerprint", "");
    out.put("packStoragePath", "");
    out.put("packSizeBytes", 0);
    out.put("hasRestoreWrap", false);
    out.put("updatedAt", null);
    return out;
  }
}
