package com.folio.backend.microsoftstore;

import com.folio.backend.microsoftstore.dto.ValidateMicrosoftStoreRequest;
import com.folio.backend.user.FolioUserPrincipal;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MicrosoftStoreBillingController {

  private final MicrosoftStoreService microsoftStoreService;

  public MicrosoftStoreBillingController(MicrosoftStoreService microsoftStoreService) {
    this.microsoftStoreService = microsoftStoreService;
  }

  @PostMapping("/api/v1/billing/microsoft-store/validate")
  public Map<String, Object> validate(@RequestBody ValidateMicrosoftStoreRequest body) {
    return microsoftStoreService.validate(
        FolioUserPrincipal.requireUid(), body != null ? body.collectionsId() : null);
  }
}
