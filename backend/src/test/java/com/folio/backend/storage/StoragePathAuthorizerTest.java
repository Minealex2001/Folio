package com.folio.backend.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.folio.backend.common.ApiException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.beans.factory.ObjectProvider;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class StoragePathAuthorizerTest {

  @Mock FolioCloudFeatureGate featureGate;
  @Mock ObjectProvider<CollabMembershipLookup> membershipProvider;
  @Mock CollabMembershipLookup membership;

  StoragePathAuthorizer authorizer;

  @BeforeEach
  void setUp() {
    authorizer = new StoragePathAuthorizer(featureGate, membershipProvider);
  }

  @Test
  void ownerWithBackupCanWriteCloudPack() {
    when(featureGate.backupOk("u1")).thenReturn(true);
    authorizer.assertWrite("u1", "users/u1/vaults/v1/cloud-packs/blobs/abc");
  }

  @Test
  void nonOwnerDeniedOnBackups() {
    assertThatThrownBy(() -> authorizer.assertWrite("u2", "users/u1/backups/x.zip"))
        .isInstanceOf(ApiException.class)
        .hasMessageContaining("owner");
  }

  @Test
  void publishedWriteRequiresPublishFeature() {
    when(featureGate.publishWebOk("u1")).thenReturn(false);
    assertThatThrownBy(() -> authorizer.assertWrite("u1", "published/u1/page.html"))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void publishedReadIsPublic() {
    authorizer.assertRead("anyone", "published/u1/page.html");
  }

  @Test
  void communityTemplateOver1MiBRejected() {
    assertThatThrownBy(
            () ->
                authorizer.assertWrite(
                    "u1",
                    "community-templates/u1/x.folio-template",
                    StoragePathAuthorizer.COMMUNITY_TEMPLATE_MAX_BYTES))
        .isInstanceOf(ApiException.class)
        .hasMessageContaining("1 MiB");
  }

  @Test
  void collabMediaRequiresMembershipAndSize() {
    when(membershipProvider.getIfAvailable()).thenReturn(membership);
    when(membership.isMember("room1", "u1")).thenReturn(true);
    authorizer.assertWrite("u1", "collab-media-e2e/room1/m1", 1024);
    assertThatThrownBy(() -> authorizer.assertWrite("u1", "collab-media-e2e/room1/m1", 0))
        .isInstanceOf(ApiException.class);
    assertThatThrownBy(
            () ->
                authorizer.assertWrite(
                    "u1", "collab-media-e2e/room1/m1", StoragePathAuthorizer.COLLAB_MEDIA_MAX_BYTES + 1))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void collabMediaNonMemberDenied() {
    when(membershipProvider.getIfAvailable()).thenReturn(membership);
    when(membership.isMember(anyString(), anyString())).thenReturn(false);
    assertThatThrownBy(() -> authorizer.assertWrite("u1", "collab-media-e2e/room1/m1", 10))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void appProfilePackPathValidation() {
    when(featureGate.backupOk("u1")).thenReturn(true);
    assertThat(authorizer.requireAppProfilePackPath("u1", "users/u1/app-profile/packs/a.bin"))
        .endsWith(".bin");
    assertThatThrownBy(() -> authorizer.requireAppProfilePackPath("u1", "users/u1/app-profile/packs/../x.bin"))
        .isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> authorizer.requireAppProfilePackPath("u1", "users/u1/other/a.bin"))
        .isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> authorizer.requireAppProfilePackPath("u1", "users/u1/app-profile/packs/a.txt"))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void classifiesPathFamilies() {
    assertThat(authorizer.classify("users/u/backups/a").orElseThrow())
        .isEqualTo(StoragePathAuthorizer.PathFamily.USER_BACKUPS);
    assertThat(authorizer.classify("users/u/vaults/v/device-sync/packs/a.bin").orElseThrow())
        .isEqualTo(StoragePathAuthorizer.PathFamily.DEVICE_SYNC);
  }
}
