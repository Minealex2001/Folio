package com.folio.backend.account.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateDisplayNameRequest(
    @NotBlank(message = "displayName is required") @Size(max = 80) String displayName) {}
