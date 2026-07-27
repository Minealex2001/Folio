package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "collab_rooms")
public class CollabRoomEntity {
  @Id @Column(name = "id", nullable = false) private UUID id;
  @Column(name = "owner_uid", nullable = false) private String ownerUid;
  @Column(name = "vault_page_id", nullable = false) private String vaultPageId;
  @Column(name = "join_code_key", nullable = false, unique = true) private String joinCodeKey;
  @Column(name = "join_code") private String joinCode;
  @Column(name = "e2e_v", nullable = false) private short e2eV = 1;
  @Column(name = "content_version", nullable = false) private int contentVersion;
  @Column(name = "title") private String title;
  @JdbcTypeCode(SqlTypes.JSON) @Column(name = "blocks", columnDefinition = "jsonb") private String blocks;
  @Column(name = "wrapped_room_key") private String wrappedRoomKey;
  @Column(name = "content_cipher") private String contentCipher;
  @Column(name = "updated_by") private String updatedBy;
  @Column(name = "created_at", nullable = false) private Instant createdAt;
  @Column(name = "updated_at", nullable = false) private Instant updatedAt;

  @PrePersist void onCreate() {
    if (id == null) id = UUID.randomUUID();
    Instant now = Instant.now();
    if (createdAt == null) createdAt = now;
    updatedAt = now;
  }
  @PreUpdate void onUpdate() { updatedAt = Instant.now(); }

  public UUID getId() { return id; } public void setId(UUID id) { this.id = id; }
  public String getOwnerUid() { return ownerUid; } public void setOwnerUid(String ownerUid) { this.ownerUid = ownerUid; }
  public String getVaultPageId() { return vaultPageId; } public void setVaultPageId(String vaultPageId) { this.vaultPageId = vaultPageId; }
  public String getJoinCodeKey() { return joinCodeKey; } public void setJoinCodeKey(String joinCodeKey) { this.joinCodeKey = joinCodeKey; }
  public String getJoinCode() { return joinCode; } public void setJoinCode(String joinCode) { this.joinCode = joinCode; }
  public short getE2eV() { return e2eV; } public void setE2eV(short e2eV) { this.e2eV = e2eV; }
  public int getContentVersion() { return contentVersion; } public void setContentVersion(int contentVersion) { this.contentVersion = contentVersion; }
  public String getTitle() { return title; } public void setTitle(String title) { this.title = title; }
  public String getBlocks() { return blocks; } public void setBlocks(String blocks) { this.blocks = blocks; }
  public String getWrappedRoomKey() { return wrappedRoomKey; } public void setWrappedRoomKey(String wrappedRoomKey) { this.wrappedRoomKey = wrappedRoomKey; }
  public String getContentCipher() { return contentCipher; } public void setContentCipher(String contentCipher) { this.contentCipher = contentCipher; }
  public String getUpdatedBy() { return updatedBy; } public void setUpdatedBy(String updatedBy) { this.updatedBy = updatedBy; }
  public Instant getCreatedAt() { return createdAt; } public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
  public Instant getUpdatedAt() { return updatedAt; } public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
