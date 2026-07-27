package com.folio.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.mail")
public record MailProperties(String from) {}
