package com.folio.backend.auth.dto;

public record TokenResponse(
    String accessToken, long expiresIn, String refreshToken, String tokenType) {

  public static TokenResponse of(String accessToken, long expiresIn, String refreshToken) {
    return new TokenResponse(accessToken, expiresIn, refreshToken, "Bearer");
  }
}
