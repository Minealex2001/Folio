package com.folio.backend.integrations;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "integration_link_codes")
public class IntegrationLinkCodeEntity {

  @Id private String code;

  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "vault_id", nullable = false)
  private String vaultId;

  @Column(name = "connection_id", nullable = false)
  private String connectionId;

  @Column(nullable = false)
  private String provider;

  @Column(name = "webhook_url", nullable = false)
  private String webhookUrl;

  @Column(name = "teams_security_token")
  private String teamsSecurityToken;

  @Column(name = "expires_at", nullable = false)
  private Instant expiresAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @PrePersist
  void onCreate() {
    if (createdAt == null) {
      createdAt = Instant.now();
    }
  }

  public String getCode() {
    return code;
  }

  public void setCode(String code) {
    this.code = code;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public String getVaultId() {
    return vaultId;
  }

  public void setVaultId(String vaultId) {
    this.vaultId = vaultId;
  }

  public String getConnectionId() {
    return connectionId;
  }

  public void setConnectionId(String connectionId) {
    this.connectionId = connectionId;
  }

  public String getProvider() {
    return provider;
  }

  public void setProvider(String provider) {
    this.provider = provider;
  }

  public String getWebhookUrl() {
    return webhookUrl;
  }

  public void setWebhookUrl(String webhookUrl) {
    this.webhookUrl = webhookUrl;
  }

  public String getTeamsSecurityToken() {
    return teamsSecurityToken;
  }

  public void setTeamsSecurityToken(String teamsSecurityToken) {
    this.teamsSecurityToken = teamsSecurityToken;
  }

  public Instant getExpiresAt() {
    return expiresAt;
  }

  public void setExpiresAt(Instant expiresAt) {
    this.expiresAt = expiresAt;
  }
}
