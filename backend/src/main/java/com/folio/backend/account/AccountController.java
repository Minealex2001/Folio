package com.folio.backend.account;

import com.folio.backend.account.dto.AccountExportResponse;
import com.folio.backend.account.dto.AccountMeResponse;
import com.folio.backend.account.dto.CancelDeletionResponse;
import com.folio.backend.account.dto.DeletionScheduleResponse;
import com.folio.backend.account.dto.UpdateDisplayNameRequest;
import com.folio.backend.user.FolioUserPrincipal;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/account")
public class AccountController {

  private final AccountService accountService;
  private final AccountDeletionService accountDeletionService;

  public AccountController(
      AccountService accountService, AccountDeletionService accountDeletionService) {
    this.accountService = accountService;
    this.accountDeletionService = accountDeletionService;
  }

  @GetMapping("/me")
  public AccountMeResponse me() {
    return accountService.me(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/ensure")
  public AccountMeResponse ensure() {
    return accountService.ensure(FolioUserPrincipal.requireUid());
  }

  @PatchMapping("/display-name")
  public AccountMeResponse updateDisplayName(@Valid @RequestBody UpdateDisplayNameRequest request) {
    return accountService.updateDisplayName(FolioUserPrincipal.requireUid(), request);
  }

  @PostMapping("/deletion/request")
  public DeletionScheduleResponse requestDeletion() {
    return accountDeletionService.requestDeletion(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/deletion/cancel")
  public CancelDeletionResponse cancelDeletion() {
    return accountDeletionService.cancelDeletion(FolioUserPrincipal.requireUid());
  }

  @GetMapping("/export")
  public AccountExportResponse exportAccountData() {
    return accountDeletionService.exportAccountData(FolioUserPrincipal.requireUid());
  }
}
