package com.folio.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.app")
public record AppProperties(String publicBaseUrl) {}
