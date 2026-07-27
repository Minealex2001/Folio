package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "user_app_profile")
public class UserAppProfileEntity {
  @Id @Column(name = "user_id", nullable = false) private String userId;
  @Column(name = "rev", nullable = false) private int rev;
  @Column(name = "content_fingerprint", nullable = false) private String contentFingerprint;
  @Column(name = "pack_storage_path", nullable = false) private String packStoragePath;
  @Column(name = "pack_size_bytes", nullable = false) private long packSizeBytes;
  @Column(name = "restore_wrap_b64") private String restoreWrapB64;
  @JdbcTypeCode(SqlTypes.JSON) @Column(name = "icon_ids", nullable = false, columnDefinition = "jsonb") private String iconIds = "[]";
  @Column(name = "updated_at", nullable = false) private Instant updatedAt;
  @PrePersist @PreUpdate void touch() { updatedAt = Instant.now(); if (iconIds == null) iconIds = "[]"; }
  public String getUserId() { return userId; } public void setUserId(String userId) { this.userId = userId; }
  public int getRev() { return rev; } public void setRev(int rev) { this.rev = rev; }
  public String getContentFingerprint() { return contentFingerprint; } public void setContentFingerprint(String contentFingerprint) { this.contentFingerprint = contentFingerprint; }
  public String getPackStoragePath() { return packStoragePath; } public void setPackStoragePath(String packStoragePath) { this.packStoragePath = packStoragePath; }
  public long getPackSizeBytes() { return packSizeBytes; } public void setPackSizeBytes(long packSizeBytes) { this.packSizeBytes = packSizeBytes; }
  public String getRestoreWrapB64() { return restoreWrapB64; } public void setRestoreWrapB64(String restoreWrapB64) { this.restoreWrapB64 = restoreWrapB64; }
  public String getIconIds() { return iconIds; } public void setIconIds(String iconIds) { this.iconIds = iconIds; }
  public Instant getUpdatedAt() { return updatedAt; } public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
