package com.folio.backend.published;

import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.PublishedPageEntity;
import com.folio.backend.persistence.repository.PublishedPageRepository;
import com.folio.backend.storage.FolioCloudFeatureGate;
import com.folio.backend.storage.StoragePathAuthorizer;
import com.folio.backend.storage.StorageService;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PublishedPagesService {

  private final PublishedPageRepository repository;
  private final FolioCloudFeatureGate featureGate;
  private final StoragePathAuthorizer pathAuthorizer;
  private final StorageService storageService;

  public PublishedPagesService(
      PublishedPageRepository repository,
      FolioCloudFeatureGate featureGate,
      StoragePathAuthorizer pathAuthorizer,
      StorageService storageService) {
    this.repository = repository;
    this.featureGate = featureGate;
    this.pathAuthorizer = pathAuthorizer;
    this.storageService = storageService;
  }

  private void requirePublish(String uid) {
    // firestore.rules publishedPages create/update/delete → folioPublishWebOk()
    if (!featureGate.publishWebOk(uid)) {
      throw new ApiException(
          HttpStatus.FORBIDDEN,
          "permission_denied",
          "Web publishing is not enabled for this account.");
    }
  }

  @Transactional
  public Map<String, Object> create(String uid, String storagePath) {
    requirePublish(uid);
    String path = requireOwnerPublishedPath(uid, storagePath);
    pathAuthorizer.assertWrite(uid, path);
    PublishedPageEntity e = new PublishedPageEntity();
    e.setOwnerUid(uid);
    e.setStoragePath(path);
    repository.save(e);
    return toDto(e);
  }

  @Transactional
  public Map<String, Object> update(String uid, UUID id, String storagePath) {
    requirePublish(uid);
    PublishedPageEntity e =
        repository
            .findById(id)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Page not found"));
    // resource.data.ownerUid == request.auth.uid
    if (!e.getOwnerUid().equals(uid)) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "Not the page owner");
    }
    if (storagePath != null && !storagePath.isBlank()) {
      String path = requireOwnerPublishedPath(uid, storagePath);
      pathAuthorizer.assertWrite(uid, path);
      e.setStoragePath(path);
    }
    repository.save(e);
    return toDto(e);
  }

  @Transactional
  public void delete(String uid, UUID id) {
    requirePublish(uid);
    PublishedPageEntity e =
        repository
            .findById(id)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Page not found"));
    if (!e.getOwnerUid().equals(uid)) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "Not the page owner");
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
    // allow read: if true
    PublishedPageEntity e =
        repository
            .findById(id)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Page not found"));
    return toDto(e);
  }

  @Transactional(readOnly = true)
  public List<Map<String, Object>> listMine(String uid) {
    return repository.findByOwnerUidOrderByUpdatedAtDesc(uid).stream().map(this::toDto).toList();
  }

  private String requireOwnerPublishedPath(String uid, String storagePath) {
    String path = storagePath == null ? "" : storagePath.trim();
    String prefix = "published/" + uid + "/";
    if (!path.startsWith(prefix) || path.contains("..")) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "storagePath invalid");
    }
    return path;
  }

  private Map<String, Object> toDto(PublishedPageEntity e) {
    Map<String, Object> m = new LinkedHashMap<>();
    m.put("id", e.getId().toString());
    m.put("ownerUid", e.getOwnerUid());
    m.put("storagePath", e.getStoragePath());
    m.put("createdAt", e.getCreatedAt());
    m.put("updatedAt", e.getUpdatedAt());
    return m;
  }
}
