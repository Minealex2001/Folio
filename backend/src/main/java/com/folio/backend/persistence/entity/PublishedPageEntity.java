package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "published_pages")
public class PublishedPageEntity {
  @Id @Column(name = "id", nullable = false) private UUID id;
  @Column(name = "owner_uid", nullable = false) private String ownerUid;
  @Column(name = "storage_path", nullable = false) private String storagePath;
  @Column(name = "created_at", nullable = false) private Instant createdAt;
  @Column(name = "updated_at", nullable = false) private Instant updatedAt;
  @PrePersist void onCreate() { if (id == null) id = UUID.randomUUID(); Instant now = Instant.now(); if (createdAt == null) createdAt = now; updatedAt = now; }
  @PreUpdate void onUpdate() { updatedAt = Instant.now(); }
  public UUID getId() { return id; } public void setId(UUID id) { this.id = id; }
  public String getOwnerUid() { return ownerUid; } public void setOwnerUid(String ownerUid) { this.ownerUid = ownerUid; }
  public String getStoragePath() { return storagePath; } public void setStoragePath(String storagePath) { this.storagePath = storagePath; }
  public Instant getCreatedAt() { return createdAt; } public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
  public Instant getUpdatedAt() { return updatedAt; } public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
