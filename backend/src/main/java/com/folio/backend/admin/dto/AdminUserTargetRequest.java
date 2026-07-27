package com.folio.backend.admin.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/** Target a user by uid and/or email (at least one required). */
public record AdminUserTargetRequest(
    String uid,
    String email,
    /** When granting Cloud: also set folioStaff (unlimited backup quota, etc.). Default false. */
    Boolean alsoStaff,
    /** Purchased ink drops to add (grant-ink / optional on grant-cloud). */
    @Min(0) @Max(1_000_000) Integer inkDrops,
    /** For /admin/staff — default true when omitted. */
    Boolean staff) {}
