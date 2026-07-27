package com.folio.backend.account.dto;

import java.time.Instant;

public record DeletionScheduleResponse(Instant scheduledFor) {}
