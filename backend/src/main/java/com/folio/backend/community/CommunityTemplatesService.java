package com.folio.backend.community;

import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.CommunityTemplateEntity;
import com.folio.backend.persistence.repository.CommunityTemplateRepository;
import com.folio.backend.storage.StoragePathAuthorizer;
import com.folio.backend.storage.StorageService;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Ports communityTemplates + {@code communityTemplateCreateOk()} from firestore.rules:96-119
 * (app-level validation with clear 400s; DB CHECKs remain as backstop).
 */
@Service
public class CommunityTemplatesService {

  private final CommunityTemplateRepository repository;
  private final StoragePathAuthorizer pathAuthorizer;
  private final StorageService storageService;

  public CommunityTemplatesService(
      CommunityTemplateRepository repository,
      StoragePathAuthorizer pathAuthorizer,
      StorageService storageService) {
    this.repository = repository;
    this.pathAuthorizer = pathAuthorizer;
    this.storageService = storageService;
  }

  @Transactional
  public Map<String, Object> create(String uid, CommunityTemplateWrite write) {
    UUID id = write.id() == null ? UUID.randomUUID() : write.id();
    validateCreate(uid, id, write);
    String expectedPath = "community-templates/" + uid + "/" + id + ".folio-template";
    pathAuthorizer.assertWrite(uid, expectedPath, write.sizeBytes() == null ? 0 : write.sizeBytes());
    CommunityTemplateEntity e = new CommunityTemplateEntity();
    e.setId(id);
    e.setOwnerUid(uid);
    e.setName(write.name().trim());
    e.setDescription(write.description());
    e.setCategory(write.category());
    e.setEmoji(write.emoji());
    e.setBlockCount(write.blockCount());
    e.setStoragePath(expectedPath);
    e.setStorageDownloadUrl(write.storageDownloadUrl().trim());
    repository.save(e);
    return toDto(e);
  }

  @Transactional
  public Map<String, Object> update(String uid, UUID id, CommunityTemplateWrite write) {
    CommunityTemplateEntity e =
        repository
            .findById(id)
            .orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Template not found"));
    // update: ownerUid immutable, storagePath/url/blockCount immutable
    if (!e.getOwnerUid().equals(uid)) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "Not the template owner");
    }
    if (write.name() != null) {
      if (write.name().isBlank() || write.name().length() > 280) {
        fieldError("name", "name must be 1..280 chars");
      }
      e.setName(write.name().trim());
    }
    if (write.description() != null) {
      if (write.description().length() > 4000) {
        fieldError("description", "description too long");
      }
      e.setDescription(write.description());
    }
    if (write.category() != null) {
      if (write.category().length() > 120) {
        fieldError("category", "category too long");
      }
      e.setCategory(write.category());
    }
    if (write.emoji() != null) {
      if (write.emoji().length() > 32) {
        fieldError("emoji", "emoji too long");
      }
      e.setEmoji(write.emoji());
    }
    repository.save(e);
    return toDto(e);
  }

  @Transactional
  public void delete(String uid, UUID id) {
    CommunityTemplateEntity e =
        repository
            .findById(id)
            .orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Template not found"));
    if (!e.getOwnerUid().equals(uid)) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "Not the template owner");
    }
    pathAuthorizer.assertDelete(uid, e.getStoragePath());
    try {
      storageService.delete(e.getStoragePath());
    } catch (Exception ignored) {
    }
    repository.delete(e);
  }

  @Transactional(readOnly = true)
  public Map<String, Object> get(UUID id) {
    return toDto(
        repository
            .findById(id)
            .orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Template not found")));
  }

  @Transactional(readOnly = true)
  public List<Map<String, Object>> list() {
    return repository.findAllByOrderByUpdatedAtDesc().stream().map(this::toDto).toList();
  }

  private void validateCreate(String uid, UUID id, CommunityTemplateWrite write) {
    // communityTemplateCreateOk()
    if (write.name() == null || write.name().isBlank() || write.name().length() > 280) {
      fieldError("name", "name must be 1..280 chars");
    }
    if (write.blockCount() < 0 || write.blockCount() > 50_000) {
      fieldError("blockCount", "blockCount must be 0..50000");
    }
    String expectedPath = "community-templates/" + uid + "/" + id + ".folio-template";
    if (write.storagePath() != null
        && !write.storagePath().isBlank()
        && !expectedPath.equals(write.storagePath().trim())) {
      fieldError("storagePath", "storagePath must be " + expectedPath);
    }
    if (write.storageDownloadUrl() == null
        || write.storageDownloadUrl().isBlank()
        || write.storageDownloadUrl().length() > 2048) {
      fieldError("storageDownloadUrl", "storageDownloadUrl invalid");
    }
    if (write.description() != null && write.description().length() > 4000) {
      fieldError("description", "description too long");
    }
    if (write.category() != null && write.category().length() > 120) {
      fieldError("category", "category too long");
    }
    if (write.emoji() != null && write.emoji().length() > 32) {
      fieldError("emoji", "emoji too long");
    }
    if (write.sizeBytes() != null
        && write.sizeBytes() >= StoragePathAuthorizer.COMMUNITY_TEMPLATE_MAX_BYTES) {
      fieldError("sizeBytes", "community template exceeds 1 MiB limit");
    }
  }

  private static void fieldError(String field, String message) {
    throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_" + field, message);
  }

  private Map<String, Object> toDto(CommunityTemplateEntity e) {
    Map<String, Object> m = new LinkedHashMap<>();
    m.put("id", e.getId().toString());
    m.put("ownerUid", e.getOwnerUid());
    m.put("name", e.getName());
    m.put("description", e.getDescription());
    m.put("category", e.getCategory());
    m.put("emoji", e.getEmoji());
    m.put("blockCount", e.getBlockCount());
    m.put("storagePath", e.getStoragePath());
    m.put("storageDownloadUrl", e.getStorageDownloadUrl());
    m.put("createdAt", e.getCreatedAt());
    m.put("updatedAt", e.getUpdatedAt());
    return m;
  }

  public record CommunityTemplateWrite(
      UUID id,
      String name,
      String description,
      String category,
      String emoji,
      int blockCount,
      String storagePath,
      String storageDownloadUrl,
      Long sizeBytes) {}
}
