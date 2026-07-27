package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;

@Entity
@Table(name = "vault_backups")
@IdClass(VaultBackupEntity.Pk.class)
public class VaultBackupEntity {

  @Id
  @Column(name = "user_id", nullable = false)
  private String userId;

  @Id
  @Column(name = "vault_id", nullable = false)
  private String vaultId;

  @Column(name = "latest_storage_path")
  private String latestStoragePath;

  @Column(name = "latest_size_bytes", nullable = false)
  private long latestSizeBytes;

  @Column(name = "content_fingerprint")
  private String contentFingerprint;

  @Column(name = "cloud_pack_restore_wrap_b64")
  private String cloudPackRestoreWrapB64;

  @Column(name = "cloud_pack_restore_wrap_kind")
  private String cloudPackRestoreWrapKind;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @PrePersist
  @PreUpdate
  void touch() {
    updatedAt = Instant.now();
  }

  public static class Pk implements Serializable {
    private String userId;
    private String vaultId;

    public Pk() {}

    public Pk(String userId, String vaultId) {
      this.userId = userId;
      this.vaultId = vaultId;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof Pk pk)) return false;
      return Objects.equals(userId, pk.userId) && Objects.equals(vaultId, pk.vaultId);
    }

    @Override
    public int hashCode() {
      return Objects.hash(userId, vaultId);
    }
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

  public String getLatestStoragePath() {
    return latestStoragePath;
  }

  public void setLatestStoragePath(String latestStoragePath) {
    this.latestStoragePath = latestStoragePath;
  }

  public long getLatestSizeBytes() {
    return latestSizeBytes;
  }

  public void setLatestSizeBytes(long latestSizeBytes) {
    this.latestSizeBytes = latestSizeBytes;
  }

  public String getContentFingerprint() {
    return contentFingerprint;
  }

  public void setContentFingerprint(String contentFingerprint) {
    this.contentFingerprint = contentFingerprint;
  }

  public String getCloudPackRestoreWrapB64() {
    return cloudPackRestoreWrapB64;
  }

  public void setCloudPackRestoreWrapB64(String cloudPackRestoreWrapB64) {
    this.cloudPackRestoreWrapB64 = cloudPackRestoreWrapB64;
  }

  public String getCloudPackRestoreWrapKind() {
    return cloudPackRestoreWrapKind;
  }

  public void setCloudPackRestoreWrapKind(String cloudPackRestoreWrapKind) {
    this.cloudPackRestoreWrapKind = cloudPackRestoreWrapKind;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }

  public void setUpdatedAt(Instant updatedAt) {
    this.updatedAt = updatedAt;
  }
}
