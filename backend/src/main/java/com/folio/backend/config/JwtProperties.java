package com.folio.backend.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.jwt")
public record JwtProperties(String signingSecret, Duration accessTokenTtl, Duration refreshTokenTtl) {}
