package com.folio.backend;

import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import org.springframework.stereotype.Component;

@Component
public class TestEntitlements {

  private final UserFolioCloudRepository folioCloudRepository;

  public TestEntitlements(UserFolioCloudRepository folioCloudRepository) {
    this.folioCloudRepository = folioCloudRepository;
  }

  public void enableBackup(String uid) {
    enableFeatures(uid, "{\"backup\":true}");
  }

  public void enablePublish(String uid) {
    enableFeatures(uid, "{\"publishWeb\":true}");
  }

  public void enableCollab(String uid) {
    enableFeatures(uid, "{\"realtimeCollab\":true}");
  }

  public void enableAll(String uid) {
    enableFeatures(uid, "{\"backup\":true,\"publishWeb\":true,\"realtimeCollab\":true}");
  }

  private void enableFeatures(String uid, String featuresJson) {
    UserFolioCloudEntity cloud =
        folioCloudRepository.findById(uid).orElseGet(() -> UserFolioCloudEntity.defaultsFor(uid));
    cloud.setUserId(uid);
    cloud.setActive(true);
    cloud.setFeatures(featuresJson);
    folioCloudRepository.save(cloud);
  }
}
