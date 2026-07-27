package com.folio.backend.vault;

import com.folio.backend.user.FolioUserPrincipal;
import com.folio.backend.vault.dto.FinalizeDeviceSyncRequest;
import com.folio.backend.vault.dto.VaultIdRequest;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/vault/device-sync")
public class DeviceSyncController {

  private final DeviceSyncService service;

  public DeviceSyncController(DeviceSyncService service) {
    this.service = service;
  }

  @PostMapping("/meta")
  public Map<String, Object> meta(@RequestBody VaultIdRequest body) {
    return service.getDeviceSyncMeta(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/finalize")
  public Map<String, Object> finalize(@RequestBody FinalizeDeviceSyncRequest body) {
    return service.finalizeDeviceSync(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/vaults")
  public Map<String, Object> vaults() {
    return service.listDeviceSyncVaults(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/plain-secret/ensure")
  public Map<String, Object> ensureSecret(@RequestBody VaultIdRequest body) {
    return service.ensurePlainVaultSyncSecret(FolioUserPrincipal.requireUid(), body.vaultId());
  }
}
