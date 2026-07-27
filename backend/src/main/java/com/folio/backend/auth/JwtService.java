package com.folio.backend.auth;

import com.folio.backend.config.JwtProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

  private final JwtProperties properties;
  private final SecretKey key;

  public JwtService(JwtProperties properties) {
    this.properties = properties;
    byte[] secretBytes = properties.signingSecret().getBytes(StandardCharsets.UTF_8);
    if (secretBytes.length < 32) {
      throw new IllegalStateException("JWT_SIGNING_SECRET must be at least 32 bytes");
    }
    this.key = Keys.hmacShaKeyFor(secretBytes);
  }

  public String issueAccessToken(String uid, String email) {
    Instant now = Instant.now();
    Instant exp = now.plus(properties.accessTokenTtl());
    return Jwts.builder()
        .subject(uid)
        .claim("email", email)
        .issuedAt(Date.from(now))
        .expiration(Date.from(exp))
        .signWith(key)
        .compact();
  }

  public long accessTokenExpiresInSeconds() {
    return properties.accessTokenTtl().toSeconds();
  }

  public Claims parseValidClaims(String token) {
    try {
      return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
    } catch (JwtException | IllegalArgumentException e) {
      throw new InvalidJwtException("Invalid or expired token", e);
    }
  }

  public static class InvalidJwtException extends RuntimeException {
    public InvalidJwtException(String message, Throwable cause) {
      super(message, cause);
    }
  }
}
