package com.folio.backend.integrations;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "teams_webhook_endpoints")
public class TeamsWebhookEndpointEntity {

  @Id
  @Column(name = "connection_id")
  private String connectionId;

  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "teams_security_token", nullable = false)
  private String teamsSecurityToken;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @PrePersist
  @PreUpdate
  void touch() {
    updatedAt = Instant.now();
  }

  public String getConnectionId() {
    return connectionId;
  }

  public void setConnectionId(String connectionId) {
    this.connectionId = connectionId;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public String getTeamsSecurityToken() {
    return teamsSecurityToken;
  }

  public void setTeamsSecurityToken(String teamsSecurityToken) {
    this.teamsSecurityToken = teamsSecurityToken;
  }
}
