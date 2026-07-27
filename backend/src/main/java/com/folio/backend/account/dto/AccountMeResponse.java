package com.folio.backend.account.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record AccountMeResponse(
    String uid,
    String email,
    String displayName,
    Instant emailVerifiedAt,
    Instant createdAt,
    boolean folioStaff,
    FolioCloudDto folioCloud,
    InkDto ink) {

  public record FolioCloudDto(
      boolean active,
      String subscriptionStatus,
      String subscriptionPriceId,
      boolean family,
      boolean student,
      boolean studentVerified,
      String familyOwnerUid,
      int familySeats,
      String features) {}

  public record InkDto(
      BigDecimal monthlyBalance, BigDecimal purchasedBalance, String monthlyPeriodKey) {}
}
