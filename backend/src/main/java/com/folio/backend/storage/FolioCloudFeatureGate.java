package com.folio.backend.storage;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * Feature gates mirroring firestore/storage rules helpers ({@code folioCloudBackupOk},
 * {@code folioCloudPublishOk}, {@code folioRealtimeCollabOk}).
 */
@Component
public class FolioCloudFeatureGate {

  private final UserRepository userRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final ObjectMapper objectMapper;

  public FolioCloudFeatureGate(
      UserRepository userRepository,
      UserFolioCloudRepository folioCloudRepository,
      ObjectMapper objectMapper) {
    this.userRepository = userRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.objectMapper = objectMapper;
  }

  public boolean isStaff(String uid) {
    return userRepository.findById(uid).map(UserEntity::isFolioStaff).orElse(false);
  }

  public boolean backupOk(String uid) {
    if (isStaff(uid)) {
      return true;
    }
    return featureActive(uid, "backup");
  }

  public boolean publishWebOk(String uid) {
    if (isStaff(uid)) {
      return true;
    }
    return featureActive(uid, "publishWeb");
  }

  public boolean realtimeCollabOk(String uid) {
    if (isStaff(uid)) {
      return true;
    }
    return featureActive(uid, "realtimeCollab");
  }

  private boolean featureActive(String uid, String feature) {
    Optional<UserFolioCloudEntity> cloud = folioCloudRepository.findById(uid);
    if (cloud.isEmpty() || !cloud.get().isActive()) {
      return false;
    }
    try {
      JsonNode node = objectMapper.readTree(cloud.get().getFeatures());
      return node.path(feature).asBoolean(false);
    } catch (Exception e) {
      return false;
    }
  }
}
