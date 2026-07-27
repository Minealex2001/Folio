package com.folio.backend.vault;

import com.folio.backend.user.FolioUserPrincipal;
import com.folio.backend.vault.dto.CheckBlobsRequest;
import com.folio.backend.vault.dto.FinalizeCloudPackRequest;
import com.folio.backend.vault.dto.RecordVaultBackupMetaRequest;
import com.folio.backend.vault.dto.TrimBackupsRequest;
import com.folio.backend.vault.dto.TrimByBytesRequest;
import com.folio.backend.vault.dto.UpsertVaultBackupIndexRequest;
import com.folio.backend.vault.dto.VaultIdRequest;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/vault/backups")
public class VaultBackupController {

  private final VaultBackupService service;

  public VaultBackupController(VaultBackupService service) {
    this.service = service;
  }

  @PostMapping("/cloud-pack/finalize")
  public Map<String, Object> finalizeCloudPack(@RequestBody FinalizeCloudPackRequest body) {
    return service.finalizeCloudPack(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/cloud-pack/latest-meta")
  public Map<String, Object> latestCloudPackMeta(@RequestBody VaultIdRequest body) {
    return service.getLatestCloudPackMeta(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/cloud-pack/restore-wrap")
  public Map<String, Object> restoreWrap(@RequestBody VaultIdRequest body) {
    return service.getCloudPackRestoreWrap(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/cloud-pack/blobs-exist")
  public Map<String, Object> blobsExist(@RequestBody CheckBlobsRequest body) {
    return service.checkCloudPackBlobsExist(
        FolioUserPrincipal.requireUid(), body.vaultId(), body.blobIds());
  }

  @PostMapping("/usage")
  public Map<String, Object> usage() {
    return service.getBackupStorageUsage(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/list")
  public Map<String, Object> list(@RequestBody VaultIdRequest body) {
    return service.listVaultBackups(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/cloud-pack/delete")
  public Map<String, Object> deleteCloudPack(@RequestBody VaultIdRequest body) {
    return service.deleteVaultCloudPack(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/legacy/delete")
  public Map<String, Object> deleteLegacy(@RequestBody VaultIdRequest body) {
    return service.deleteVaultLegacyBackup(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/trim-by-bytes")
  public Map<String, Object> trimByBytes(@RequestBody TrimByBytesRequest body) {
    return service.trimVaultBackupsByBytes(
        FolioUserPrincipal.requireUid(),
        body.targetUsedBytes() == null ? 0 : body.targetUsedBytes());
  }

  @PostMapping("/trim")
  public Map<String, Object> trim(@RequestBody TrimBackupsRequest body) {
    return service.trimVaultBackups(
        FolioUserPrincipal.requireUid(),
        body.keepLatestPerVault() == null ? 1 : body.keepLatestPerVault());
  }

  @PostMapping("/vaults")
  public Map<String, Object> listVaults() {
    return service.listBackupVaults(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/index/upsert")
  public Map<String, Object> upsertIndex(@RequestBody UpsertVaultBackupIndexRequest body) {
    return service.upsertVaultBackupIndex(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/latest-meta")
  public Map<String, Object> latestMeta(@RequestBody VaultIdRequest body) {
    return service.getLatestVaultBackupMeta(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/record-meta")
  public Map<String, Object> recordMeta(@RequestBody RecordVaultBackupMetaRequest body) {
    return service.recordVaultBackupMeta(FolioUserPrincipal.requireUid(), body);
  }
}
