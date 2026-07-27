package com.folio.backend.vault;

import com.folio.backend.user.FolioUserPrincipal;
import com.folio.backend.vault.dto.FinalizeAppProfileRequest;
import com.folio.backend.vault.dto.FinalizeVaultProfileRequest;
import com.folio.backend.vault.dto.VaultIdRequest;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/vault/profiles")
public class ProfileSyncController {

  private final ProfileSyncService service;

  public ProfileSyncController(ProfileSyncService service) {
    this.service = service;
  }

  @PostMapping("/app/meta")
  public Map<String, Object> appMeta() {
    return service.getAppProfileMeta(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/app/restore-wrap")
  public Map<String, Object> appRestoreWrap() {
    return service.getAppProfileRestoreWrap(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/app/finalize")
  public Map<String, Object> appFinalize(@RequestBody FinalizeAppProfileRequest body) {
    return service.finalizeAppProfile(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/vault/meta")
  public Map<String, Object> vaultMeta(@RequestBody VaultIdRequest body) {
    return service.getVaultProfileMeta(FolioUserPrincipal.requireUid(), body.vaultId());
  }

  @PostMapping("/vault/finalize")
  public Map<String, Object> vaultFinalize(@RequestBody FinalizeVaultProfileRequest body) {
    return service.finalizeVaultProfile(FolioUserPrincipal.requireUid(), body);
  }
}
