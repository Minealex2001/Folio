package com.folio.backend.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8, max = 128, message = "password must be between 8 and 128 characters")
        String password,
    @Size(max = 80) String displayName) {}
