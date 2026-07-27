package com.folio.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.storage")
public record StorageProperties(
    String endpoint,
    String accessKey,
    String secretKey,
    String bucket,
    String region,
    boolean pathStyleAccess,
    boolean bootstrapBucket) {

  public StorageProperties {
    if (endpoint == null || endpoint.isBlank()) {
      endpoint = "http://localhost:9000";
    }
    if (accessKey == null || accessKey.isBlank()) {
      accessKey = "minioadmin";
    }
    if (secretKey == null || secretKey.isBlank()) {
      secretKey = "minioadmin";
    }
    if (bucket == null || bucket.isBlank()) {
      bucket = "folio";
    }
    if (region == null || region.isBlank()) {
      region = "us-east-1";
    }
  }
}
