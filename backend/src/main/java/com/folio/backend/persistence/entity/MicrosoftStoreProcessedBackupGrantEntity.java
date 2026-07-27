package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "microsoft_store_processed_backup_grants")
public class MicrosoftStoreProcessedBackupGrantEntity {

  @Id
  @Column(name = "id", nullable = false)
  private String id;

  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "processed_at", nullable = false)
  private Instant processedAt;

  @PrePersist
  void onCreate() {
    if (processedAt == null) {
      processedAt = Instant.now();
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

  public Instant getProcessedAt() {
    return processedAt;
  }

  public void setProcessedAt(Instant processedAt) {
    this.processedAt = processedAt;
  }
}
