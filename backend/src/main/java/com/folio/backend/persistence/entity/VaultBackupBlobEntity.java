package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;

@Entity
@Table(name = "vault_backup_blobs")
@IdClass(VaultBackupBlobEntity.Pk.class)
public class VaultBackupBlobEntity {

  @Id
  @Column(name = "user_id", nullable = false)
  private String userId;

  @Id
  @Column(name = "vault_id", nullable = false)
  private String vaultId;

  @Id
  @Column(name = "blob_id", nullable = false)
  private String blobId;

  @Column(name = "storage_path", nullable = false)
  private String storagePath;

  @Column(name = "size_bytes", nullable = false)
  private long sizeBytes;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @PrePersist
  void onCreate() {
    if (createdAt == null) {
      createdAt = Instant.now();
    }
  }

  public static class Pk implements Serializable {
    private String userId;
    private String vaultId;
    private String blobId;

    public Pk() {}

    public Pk(String userId, String vaultId, String blobId) {
      this.userId = userId;
      this.vaultId = vaultId;
      this.blobId = blobId;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof Pk pk)) return false;
      return Objects.equals(userId, pk.userId)
          && Objects.equals(vaultId, pk.vaultId)
          && Objects.equals(blobId, pk.blobId);
    }

    @Override
    public int hashCode() {
      return Objects.hash(userId, vaultId, blobId);
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

  public String getBlobId() {
    return blobId;
  }

  public void setBlobId(String blobId) {
    this.blobId = blobId;
  }

  public String getStoragePath() {
    return storagePath;
  }

  public void setStoragePath(String storagePath) {
    this.storagePath = storagePath;
  }

  public long getSizeBytes() {
    return sizeBytes;
  }

  public void setSizeBytes(long sizeBytes) {
    this.sizeBytes = sizeBytes;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(Instant createdAt) {
    this.createdAt = createdAt;
  }
}
