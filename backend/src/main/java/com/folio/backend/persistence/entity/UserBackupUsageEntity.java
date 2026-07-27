package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "user_backup_usage")
public class UserBackupUsageEntity {

  @Id
  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "used_bytes", nullable = false)
  private long usedBytes;

  @Column(name = "purchased_bytes", nullable = false)
  private long purchasedBytes;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @PrePersist
  @PreUpdate
  void touch() {
    updatedAt = Instant.now();
  }

  public static UserBackupUsageEntity defaultsFor(String userId) {
    UserBackupUsageEntity e = new UserBackupUsageEntity();
    e.userId = userId;
    e.usedBytes = 0;
    e.purchasedBytes = 0;
    return e;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public long getUsedBytes() {
    return usedBytes;
  }

  public void setUsedBytes(long usedBytes) {
    this.usedBytes = usedBytes;
  }

  public long getPurchasedBytes() {
    return purchasedBytes;
  }

  public void setPurchasedBytes(long purchasedBytes) {
    this.purchasedBytes = purchasedBytes;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }

  public void setUpdatedAt(Instant updatedAt) {
    this.updatedAt = updatedAt;
  }
}
