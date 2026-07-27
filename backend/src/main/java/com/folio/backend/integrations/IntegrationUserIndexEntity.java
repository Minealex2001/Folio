package com.folio.backend.integrations;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "integration_user_index")
public class IntegrationUserIndexEntity {

  @Id private String id;

  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(nullable = false)
  private String provider;

  @Column(name = "external_user_id")
  private String externalUserId;

  @Column(name = "vault_id")
  private String vaultId;

  @Column(name = "connection_id")
  private String connectionId;

  @Column(name = "webhook_url")
  private String webhookUrl;

  @Column(name = "teams_security_token")
  private String teamsSecurityToken;

  @Column(name = "linked_at")
  private Instant linkedAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @PrePersist
  void onCreate() {
    if (createdAt == null) {
      createdAt = Instant.now();
    }
  }

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public String getProvider() {
    return provider;
  }

  public void setProvider(String provider) {
    this.provider = provider;
  }

  public String getExternalUserId() {
    return externalUserId;
  }

  public void setExternalUserId(String externalUserId) {
    this.externalUserId = externalUserId;
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

  public void setLinkedAt(Instant linkedAt) {
    this.linkedAt = linkedAt;
  }
}
