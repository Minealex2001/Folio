package com.folio.backend.auth;

import com.folio.backend.auth.dto.LoginRequest;
import com.folio.backend.auth.dto.RegisterRequest;
import com.folio.backend.auth.dto.RegisterResponse;
import com.folio.backend.auth.dto.TokenResponse;
import com.folio.backend.common.ApiException;
import com.folio.backend.config.JwtProperties;
import com.folio.backend.persistence.entity.EmailVerificationTokenEntity;
import com.folio.backend.persistence.entity.PasswordResetTokenEntity;
import com.folio.backend.persistence.entity.RefreshTokenEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.EmailVerificationTokenRepository;
import com.folio.backend.persistence.repository.PasswordResetTokenRepository;
import com.folio.backend.persistence.repository.RefreshTokenRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

  /**
   * Email verification is NOT required to call the API today (no endpoint gates on
   * email_verified_at). A gate can be added later if product decides to enforce it.
   */
  private static final Duration EMAIL_VERIFICATION_TTL = Duration.ofHours(24);

  private static final Duration PASSWORD_RESET_TTL = Duration.ofHours(1);

  private final UserRepository userRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final UserInkRepository inkRepository;
  private final RefreshTokenRepository refreshTokenRepository;
  private final EmailVerificationTokenRepository emailVerificationTokenRepository;
  private final PasswordResetTokenRepository passwordResetTokenRepository;
  private final PasswordEncoder passwordEncoder;
  private final JwtService jwtService;
  private final JwtProperties jwtProperties;
  private final EmailService emailService;

  public AuthService(
      UserRepository userRepository,
      UserFolioCloudRepository folioCloudRepository,
      UserInkRepository inkRepository,
      RefreshTokenRepository refreshTokenRepository,
      EmailVerificationTokenRepository emailVerificationTokenRepository,
      PasswordResetTokenRepository passwordResetTokenRepository,
      PasswordEncoder passwordEncoder,
      JwtService jwtService,
      JwtProperties jwtProperties,
      EmailService emailService) {
    this.userRepository = userRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.inkRepository = inkRepository;
    this.refreshTokenRepository = refreshTokenRepository;
    this.emailVerificationTokenRepository = emailVerificationTokenRepository;
    this.passwordResetTokenRepository = passwordResetTokenRepository;
    this.passwordEncoder = passwordEncoder;
    this.jwtService = jwtService;
    this.jwtProperties = jwtProperties;
    this.emailService = emailService;
  }

  @Transactional
  public RegisterResponse register(RegisterRequest request) {
    String email = request.email().trim().toLowerCase();
    if (userRepository.existsByEmailIgnoreCase(email)) {
      throw new ApiException(HttpStatus.CONFLICT, "email_taken", "Email already registered");
    }
    String uid = UUID.randomUUID().toString().replace("-", "");
    UserEntity user = new UserEntity();
    user.setId(uid);
    user.setEmail(email);
    user.setDisplayName(normalizeDisplayName(request.displayName()));
    user.setPasswordHash(passwordEncoder.encode(request.password()));
    user.setStatus("active");
    userRepository.save(user);
    folioCloudRepository.save(UserFolioCloudEntity.defaultsFor(uid));
    inkRepository.save(UserInkEntity.defaultsFor(uid));
    issueAndSendEmailVerification(user);
    return new RegisterResponse(uid, email, user.getDisplayName());
  }

  @Transactional
  public TokenResponse login(LoginRequest request) {
    String email = request.email().trim().toLowerCase();
    UserEntity user =
        userRepository
            .findByEmailIgnoreCase(email)
            .filter(u -> passwordEncoder.matches(request.password(), u.getPasswordHash()))
            .orElseThrow(
                () ->
                    new ApiException(
                        HttpStatus.UNAUTHORIZED, "invalid_credentials", "Invalid email or password"));
    return issueTokenPair(user, null);
  }

  @Transactional
  public TokenResponse refresh(String rawRefreshToken) {
    String hash = TokenHasher.sha256Hex(rawRefreshToken);
    RefreshTokenEntity existing =
        refreshTokenRepository
            .findByTokenHash(hash)
            .orElseThrow(
                () ->
                    new ApiException(
                        HttpStatus.UNAUTHORIZED, "invalid_refresh", "Invalid refresh token"));

    if (existing.getRevokedAt() != null) {
      // Reuse of a revoked token → revoke entire chain for the user (defensive)
      refreshTokenRepository.revokeAllActiveForUser(existing.getUserId());
      throw new ApiException(
          HttpStatus.UNAUTHORIZED, "invalid_refresh", "Refresh token reuse detected");
    }
    if (existing.getExpiresAt().isBefore(Instant.now())) {
      existing.setRevokedAt(Instant.now());
      refreshTokenRepository.save(existing);
      throw new ApiException(HttpStatus.UNAUTHORIZED, "invalid_refresh", "Refresh token expired");
    }

    UserEntity user =
        userRepository
            .findById(existing.getUserId())
            .orElseThrow(
                () ->
                    new ApiException(
                        HttpStatus.UNAUTHORIZED, "invalid_refresh", "Invalid refresh token"));

    TokenResponse pair = issueTokenPair(user, existing.getDeviceLabel());
    // Mark old token revoked and link rotation chain (replaced_by set after new token saved)
    RefreshTokenEntity newest =
        refreshTokenRepository
            .findByTokenHash(TokenHasher.sha256Hex(pair.refreshToken()))
            .orElseThrow();
    existing.setRevokedAt(Instant.now());
    existing.setReplacedBy(newest.getId());
    refreshTokenRepository.save(existing);
    return pair;
  }

  @Transactional
  public void logout(String uid, String rawRefreshToken) {
    String hash = TokenHasher.sha256Hex(rawRefreshToken);
    refreshTokenRepository
        .findByTokenHash(hash)
        .filter(t -> t.getUserId().equals(uid))
        .ifPresent(
            t -> {
              if (t.getRevokedAt() == null) {
                t.setRevokedAt(Instant.now());
                refreshTokenRepository.save(t);
              }
            });
  }

  @Transactional
  public void verifyEmail(String rawToken) {
    String hash = TokenHasher.sha256Hex(rawToken);
    EmailVerificationTokenEntity token =
        emailVerificationTokenRepository
            .findByTokenHash(hash)
            .orElseThrow(
                () -> new ApiException(HttpStatus.BAD_REQUEST, "invalid_token", "Invalid token"));
    if (token.getConsumedAt() != null) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "token_used", "Token already used");
    }
    if (token.getExpiresAt().isBefore(Instant.now())) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "token_expired", "Token expired");
    }
    UserEntity user =
        userRepository
            .findById(token.getUserId())
            .orElseThrow(
                () -> new ApiException(HttpStatus.BAD_REQUEST, "invalid_token", "Invalid token"));
    user.setEmailVerifiedAt(Instant.now());
    userRepository.save(user);
    token.setConsumedAt(Instant.now());
    emailVerificationTokenRepository.save(token);
  }

  @Transactional
  public void resendVerification(String uid) {
    UserEntity user =
        userRepository
            .findById(uid)
            .orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "user_not_found", "User not found"));
    if (user.getEmailVerifiedAt() != null) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "already_verified", "Email already verified");
    }
    emailVerificationTokenRepository.consumeAllPendingForUser(uid);
    issueAndSendEmailVerification(user);
  }

  @Transactional
  public void forgotPassword(String email) {
    // Always 200 — do not reveal whether the email exists
    userRepository
        .findByEmailIgnoreCase(email.trim().toLowerCase())
        .ifPresent(
            user -> {
              String raw = TokenHasher.generateOpaqueToken();
              PasswordResetTokenEntity token = new PasswordResetTokenEntity();
              token.setUserId(user.getId());
              token.setTokenHash(TokenHasher.sha256Hex(raw));
              token.setExpiresAt(Instant.now().plus(PASSWORD_RESET_TTL));
              passwordResetTokenRepository.save(token);
              emailService.sendPasswordReset(user.getEmail(), raw);
            });
  }

  @Transactional
  public void resetPassword(String rawToken, String newPassword) {
    String hash = TokenHasher.sha256Hex(rawToken);
    PasswordResetTokenEntity token =
        passwordResetTokenRepository
            .findByTokenHash(hash)
            .orElseThrow(
                () -> new ApiException(HttpStatus.BAD_REQUEST, "invalid_token", "Invalid token"));
    if (token.getConsumedAt() != null) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "token_used", "Token already used");
    }
    if (token.getExpiresAt().isBefore(Instant.now())) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "token_expired", "Token expired");
    }
    UserEntity user =
        userRepository
            .findById(token.getUserId())
            .orElseThrow(
                () -> new ApiException(HttpStatus.BAD_REQUEST, "invalid_token", "Invalid token"));
    user.setPasswordHash(passwordEncoder.encode(newPassword));
    userRepository.save(user);
    token.setConsumedAt(Instant.now());
    passwordResetTokenRepository.save(token);
    refreshTokenRepository.revokeAllActiveForUser(user.getId());
  }

  private TokenResponse issueTokenPair(UserEntity user, String deviceLabel) {
    String access = jwtService.issueAccessToken(user.getId(), user.getEmail());
    String rawRefresh = TokenHasher.generateOpaqueToken();
    RefreshTokenEntity refresh = new RefreshTokenEntity();
    refresh.setUserId(user.getId());
    refresh.setTokenHash(TokenHasher.sha256Hex(rawRefresh));
    refresh.setExpiresAt(Instant.now().plus(jwtProperties.refreshTokenTtl()));
    refresh.setDeviceLabel(deviceLabel);
    refreshTokenRepository.save(refresh);
    return TokenResponse.of(access, jwtService.accessTokenExpiresInSeconds(), rawRefresh);
  }

  private void issueAndSendEmailVerification(UserEntity user) {
    String raw = TokenHasher.generateOpaqueToken();
    EmailVerificationTokenEntity token = new EmailVerificationTokenEntity();
    token.setUserId(user.getId());
    token.setTokenHash(TokenHasher.sha256Hex(raw));
    token.setExpiresAt(Instant.now().plus(EMAIL_VERIFICATION_TTL));
    emailVerificationTokenRepository.save(token);
    emailService.sendEmailVerification(user.getEmail(), raw);
  }

  private static String normalizeDisplayName(String raw) {
    if (raw == null) {
      return null;
    }
    String collapsed = raw.trim().replaceAll("\\s+", " ");
    return collapsed.isEmpty() ? null : collapsed;
  }
}
