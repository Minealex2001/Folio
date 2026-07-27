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
@Table(name = "user_vault_profile")
@IdClass(UserVaultProfileEntity.Pk.class)
public class UserVaultProfileEntity {
  @Id @Column(name = "user_id", nullable = false) private String userId;
  @Id @Column(name = "vault_id", nullable = false) private String vaultId;
  @Column(name = "rev", nullable = false) private int rev;
  @Column(name = "content_fingerprint", nullable = false) private String contentFingerprint;
  @Column(name = "pack_storage_path", nullable = false) private String packStoragePath;
  @Column(name = "pack_size_bytes", nullable = false) private long packSizeBytes;
  @Column(name = "restore_wrap_b64") private String restoreWrapB64;
  @Column(name = "updated_at", nullable = false) private Instant updatedAt;
  @PrePersist @PreUpdate void touch() { updatedAt = Instant.now(); }
  public static class Pk implements Serializable {
    private String userId; private String vaultId;
    public Pk() {}
    public Pk(String u, String v) { userId = u; vaultId = v; }
    @Override public boolean equals(Object o) { if (this == o) return true; if (!(o instanceof Pk pk)) return false; return Objects.equals(userId, pk.userId) && Objects.equals(vaultId, pk.vaultId); }
    @Override public int hashCode() { return Objects.hash(userId, vaultId); }
  }
  public String getUserId() { return userId; } public void setUserId(String userId) { this.userId = userId; }
  public String getVaultId() { return vaultId; } public void setVaultId(String vaultId) { this.vaultId = vaultId; }
  public int getRev() { return rev; } public void setRev(int rev) { this.rev = rev; }
  public String getContentFingerprint() { return contentFingerprint; } public void setContentFingerprint(String contentFingerprint) { this.contentFingerprint = contentFingerprint; }
  public String getPackStoragePath() { return packStoragePath; } public void setPackStoragePath(String packStoragePath) { this.packStoragePath = packStoragePath; }
  public long getPackSizeBytes() { return packSizeBytes; } public void setPackSizeBytes(long packSizeBytes) { this.packSizeBytes = packSizeBytes; }
  public String getRestoreWrapB64() { return restoreWrapB64; } public void setRestoreWrapB64(String restoreWrapB64) { this.restoreWrapB64 = restoreWrapB64; }
  public Instant getUpdatedAt() { return updatedAt; } public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
