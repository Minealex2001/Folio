package com.folio.backend.vault;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.folio.backend.common.ApiException;
import com.folio.backend.storage.CollabMembershipLookup;
import com.folio.backend.storage.FolioCloudFeatureGate;
import com.folio.backend.storage.StoragePathAuthorizer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.beans.factory.ObjectProvider;

import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ProfilePathValidationTest {

  @Mock FolioCloudFeatureGate featureGate;
  @Mock ObjectProvider<CollabMembershipLookup> membershipProvider;

  StoragePathAuthorizer authorizer;

  @BeforeEach
  void setUp() {
    authorizer = new StoragePathAuthorizer(featureGate, membershipProvider);
    when(featureGate.backupOk("u1")).thenReturn(true);
  }

  @Test
  void rejectsDotDotWrongPrefixAndExtension() {
    assertThatThrownBy(
            () -> authorizer.requireAppProfilePackPath("u1", "users/u1/app-profile/packs/../x.bin"))
        .isInstanceOf(ApiException.class);
    assertThatThrownBy(
            () -> authorizer.requireVaultProfilePackPath("u1", "v1", "users/u1/wrong/v1/packs/a.bin"))
        .isInstanceOf(ApiException.class);
    assertThatThrownBy(
            () -> authorizer.requireAppProfilePackPath("u1", "users/u1/app-profile/packs/a.txt"))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void acceptsValidPaths() {
    authorizer.requireAppProfilePackPath("u1", "users/u1/app-profile/packs/ok.bin");
    authorizer.requireVaultProfilePackPath("u1", "v1", "users/u1/vault-profiles/v1/packs/ok.bin");
  }
}
