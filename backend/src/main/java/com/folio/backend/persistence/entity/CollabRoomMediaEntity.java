package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "collab_room_media")
public class CollabRoomMediaEntity {
  @Id @Column(name = "id", nullable = false) private UUID id;
  @Column(name = "room_id", nullable = false) private UUID roomId;
  @Column(name = "block_id", nullable = false) private String blockId;
  @Column(name = "storage_path", nullable = false) private String storagePath;
  @Column(name = "media_kind", nullable = false) private String mediaKind;
  @Column(name = "size_bytes", nullable = false) private long sizeBytes;
  @Column(name = "e2e_v", nullable = false) private short e2eV = 1;
  @Column(name = "created_at", nullable = false) private Instant createdAt;
  @PrePersist void onCreate() { if (id == null) id = UUID.randomUUID(); if (createdAt == null) createdAt = Instant.now(); }
  public UUID getId() { return id; } public void setId(UUID id) { this.id = id; }
  public UUID getRoomId() { return roomId; } public void setRoomId(UUID roomId) { this.roomId = roomId; }
  public String getBlockId() { return blockId; } public void setBlockId(String blockId) { this.blockId = blockId; }
  public String getStoragePath() { return storagePath; } public void setStoragePath(String storagePath) { this.storagePath = storagePath; }
  public String getMediaKind() { return mediaKind; } public void setMediaKind(String mediaKind) { this.mediaKind = mediaKind; }
  public long getSizeBytes() { return sizeBytes; } public void setSizeBytes(long sizeBytes) { this.sizeBytes = sizeBytes; }
  public short getE2eV() { return e2eV; } public void setE2eV(short e2eV) { this.e2eV = e2eV; }
  public Instant getCreatedAt() { return createdAt; } public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
