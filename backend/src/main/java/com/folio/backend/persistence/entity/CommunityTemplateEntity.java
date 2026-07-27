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
@Table(name = "community_templates")
public class CommunityTemplateEntity {
  @Id @Column(name = "id", nullable = false) private UUID id;
  @Column(name = "owner_uid", nullable = false) private String ownerUid;
  @Column(name = "name", nullable = false) private String name;
  @Column(name = "description") private String description;
  @Column(name = "category") private String category;
  @Column(name = "emoji") private String emoji;
  @Column(name = "block_count", nullable = false) private int blockCount;
  @Column(name = "storage_path", nullable = false) private String storagePath;
  @Column(name = "storage_download_url", nullable = false) private String storageDownloadUrl;
  @Column(name = "created_at", nullable = false) private Instant createdAt;
  @Column(name = "updated_at", nullable = false) private Instant updatedAt;
  @PrePersist void onCreate() { if (id == null) id = UUID.randomUUID(); Instant now = Instant.now(); if (createdAt == null) createdAt = now; updatedAt = now; }
  @PreUpdate void onUpdate() { updatedAt = Instant.now(); }
  public UUID getId() { return id; } public void setId(UUID id) { this.id = id; }
  public String getOwnerUid() { return ownerUid; } public void setOwnerUid(String ownerUid) { this.ownerUid = ownerUid; }
  public String getName() { return name; } public void setName(String name) { this.name = name; }
  public String getDescription() { return description; } public void setDescription(String description) { this.description = description; }
  public String getCategory() { return category; } public void setCategory(String category) { this.category = category; }
  public String getEmoji() { return emoji; } public void setEmoji(String emoji) { this.emoji = emoji; }
  public int getBlockCount() { return blockCount; } public void setBlockCount(int blockCount) { this.blockCount = blockCount; }
  public String getStoragePath() { return storagePath; } public void setStoragePath(String storagePath) { this.storagePath = storagePath; }
  public String getStorageDownloadUrl() { return storageDownloadUrl; } public void setStorageDownloadUrl(String storageDownloadUrl) { this.storageDownloadUrl = storageDownloadUrl; }
  public Instant getCreatedAt() { return createdAt; } public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
  public Instant getUpdatedAt() { return updatedAt; } public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
