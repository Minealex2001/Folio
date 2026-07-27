package com.folio.backend.account.dto;

import java.time.Instant;
import java.util.Map;

public record AccountExportResponse(Instant exportedAt, Map<String, Object> data) {}
