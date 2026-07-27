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
@Table(name = "user_vault_sync")
@IdClass(UserVaultSyncEntity.Pk.class)
public class UserVaultSyncEntity {
  @Id @Column(name = "user_id", nullable = false) private String userId;
  @Id @Column(name = "vault_id", nullable = false) private String vaultId;
  @Column(name = "rev", nullable = false) private int rev;
  @Column(name = "content_fingerprint", nullable = false) private String contentFingerprint = "";
  @Column(name = "sync_format_version", nullable = false) private short syncFormatVersion = 1;
  @Column(name = "pack_storage_path") private String packStoragePath;
  @Column(name = "pack_size_bytes", nullable = false) private long packSizeBytes;
  @Column(name = "manifest_storage_path") private String manifestStoragePath;
  @Column(name = "manifest_size_bytes", nullable = false) private long manifestSizeBytes;
  @Column(name = "device_id") private String deviceId;
  @Column(name = "device_name") private String deviceName;
  @Column(name = "vault_mode") private String vaultMode;
  @Column(name = "pack_key_kind") private String packKeyKind;
  @Column(name = "dek_account_wrap_b64") private String dekAccountWrapB64;
  @Column(name = "updated_at", nullable = false) private Instant updatedAt;

  @PrePersist @PreUpdate void touch() { updatedAt = Instant.now(); if (contentFingerprint == null) contentFingerprint = ""; }

  public static class Pk implements Serializable {
    private String userId; private String vaultId;
    public Pk() {}
    public Pk(String userId, String vaultId) { this.userId = userId; this.vaultId = vaultId; }
    @Override public boolean equals(Object o) { if (this == o) return true; if (!(o instanceof Pk pk)) return false; return Objects.equals(userId, pk.userId) && Objects.equals(vaultId, pk.vaultId); }
    @Override public int hashCode() { return Objects.hash(userId, vaultId); }
  }
  public String getUserId() { return userId; } public void setUserId(String userId) { this.userId = userId; }
  public String getVaultId() { return vaultId; } public void setVaultId(String vaultId) { this.vaultId = vaultId; }
  public int getRev() { return rev; } public void setRev(int rev) { this.rev = rev; }
  public String getContentFingerprint() { return contentFingerprint; } public void setContentFingerprint(String contentFingerprint) { this.contentFingerprint = contentFingerprint; }
  public short getSyncFormatVersion() { return syncFormatVersion; } public void setSyncFormatVersion(short syncFormatVersion) { this.syncFormatVersion = syncFormatVersion; }
  public String getPackStoragePath() { return packStoragePath; } public void setPackStoragePath(String packStoragePath) { this.packStoragePath = packStoragePath; }
  public long getPackSizeBytes() { return packSizeBytes; } public void setPackSizeBytes(long packSizeBytes) { this.packSizeBytes = packSizeBytes; }
  public String getManifestStoragePath() { return manifestStoragePath; } public void setManifestStoragePath(String manifestStoragePath) { this.manifestStoragePath = manifestStoragePath; }
  public long getManifestSizeBytes() { return manifestSizeBytes; } public void setManifestSizeBytes(long manifestSizeBytes) { this.manifestSizeBytes = manifestSizeBytes; }
  public String getDeviceId() { return deviceId; } public void setDeviceId(String deviceId) { this.deviceId = deviceId; }
  public String getDeviceName() { return deviceName; } public void setDeviceName(String deviceName) { this.deviceName = deviceName; }
  public String getVaultMode() { return vaultMode; } public void setVaultMode(String vaultMode) { this.vaultMode = vaultMode; }
  public String getPackKeyKind() { return packKeyKind; } public void setPackKeyKind(String packKeyKind) { this.packKeyKind = packKeyKind; }
  public String getDekAccountWrapB64() { return dekAccountWrapB64; } public void setDekAccountWrapB64(String dekAccountWrapB64) { this.dekAccountWrapB64 = dekAccountWrapB64; }
  public Instant getUpdatedAt() { return updatedAt; } public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
