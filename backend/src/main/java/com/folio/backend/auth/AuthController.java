package com.folio.backend.auth;

import com.folio.backend.auth.dto.ForgotPasswordRequest;
import com.folio.backend.auth.dto.LoginRequest;
import com.folio.backend.auth.dto.LogoutRequest;
import com.folio.backend.auth.dto.RefreshRequest;
import com.folio.backend.auth.dto.RegisterRequest;
import com.folio.backend.auth.dto.RegisterResponse;
import com.folio.backend.auth.dto.ResetPasswordRequest;
import com.folio.backend.auth.dto.TokenResponse;
import com.folio.backend.auth.dto.VerifyEmailRequest;
import com.folio.backend.user.FolioUserPrincipal;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

  private final AuthService authService;

  public AuthController(AuthService authService) {
    this.authService = authService;
  }

  @PostMapping("/register")
  @ResponseStatus(HttpStatus.CREATED)
  public RegisterResponse register(@Valid @RequestBody RegisterRequest request) {
    return authService.register(request);
  }

  @PostMapping("/login")
  public TokenResponse login(@Valid @RequestBody LoginRequest request) {
    return authService.login(request);
  }

  @PostMapping("/refresh")
  public TokenResponse refresh(@Valid @RequestBody RefreshRequest request) {
    return authService.refresh(request.refreshToken());
  }

  @PostMapping("/logout")
  public Map<String, Object> logout(@Valid @RequestBody LogoutRequest request) {
    String uid = FolioUserPrincipal.requireUid();
    authService.logout(uid, request.refreshToken());
    return Map.of("ok", true);
  }

  @PostMapping("/verify-email")
  public Map<String, Object> verifyEmail(@Valid @RequestBody VerifyEmailRequest request) {
    authService.verifyEmail(request.token());
    return Map.of("ok", true);
  }

  @PostMapping("/resend-verification")
  public Map<String, Object> resendVerification() {
    authService.resendVerification(FolioUserPrincipal.requireUid());
    return Map.of("ok", true);
  }

  @PostMapping("/forgot-password")
  public Map<String, Object> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
    authService.forgotPassword(request.email());
    return Map.of("ok", true);
  }

  @PostMapping("/reset-password")
  public Map<String, Object> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
    authService.resetPassword(request.token(), request.newPassword());
    return Map.of("ok", true);
  }
}
