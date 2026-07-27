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
@Table(name = "user_plain_vault_sync_secret")
@IdClass(UserPlainVaultSyncSecretEntity.Pk.class)
public class UserPlainVaultSyncSecretEntity {
  @Id @Column(name = "user_id", nullable = false) private String userId;
  @Id @Column(name = "vault_id", nullable = false) private String vaultId;
  @Column(name = "secret_b64", nullable = false) private String secretB64;
  @Column(name = "created_at", nullable = false) private Instant createdAt;
  @PrePersist void onCreate() { if (createdAt == null) createdAt = Instant.now(); }
  public static class Pk implements Serializable {
    private String userId; private String vaultId;
    public Pk() {}
    public Pk(String u, String v) { userId = u; vaultId = v; }
    @Override public boolean equals(Object o) { if (this == o) return true; if (!(o instanceof Pk pk)) return false; return Objects.equals(userId, pk.userId) && Objects.equals(vaultId, pk.vaultId); }
    @Override public int hashCode() { return Objects.hash(userId, vaultId); }
  }
  public String getUserId() { return userId; } public void setUserId(String userId) { this.userId = userId; }
  public String getVaultId() { return vaultId; } public void setVaultId(String vaultId) { this.vaultId = vaultId; }
  public String getSecretB64() { return secretB64; } public void setSecretB64(String secretB64) { this.secretB64 = secretB64; }
  public Instant getCreatedAt() { return createdAt; } public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
