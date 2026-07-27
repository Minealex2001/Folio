package com.folio.backend.account;

import com.folio.backend.billing.FolioCloudEntitlementService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Port of {@code processScheduledAccountDeletions} (functions/src/index.ts) — diario a las 3:15
 * en {@link FolioCloudEntitlementService#INK_TIMEZONE}.
 *
 * <p>Sin IdP externo: no hay trigger {@code onUserDeleted} separado; este job es el único
 * disparador automático del purge.
 */
@Component
public class ScheduledAccountDeletionJob {

  private final AccountDeletionService accountDeletionService;

  public ScheduledAccountDeletionJob(AccountDeletionService accountDeletionService) {
    this.accountDeletionService = accountDeletionService;
  }

  @Scheduled(cron = "0 15 3 * * *", zone = FolioCloudEntitlementService.INK_TIMEZONE)
  public void runScheduled() {
    accountDeletionService.processScheduledAccountDeletions();
  }
}
