package com.folio.backend.storage;

import com.folio.backend.common.ApiException;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Port of {@code storage.rules} ownership / feature checks (lines 7–134). Call before issuing
 * presigned URLs. One method family per Storage path tree.
 */
@Component
public class StoragePathAuthorizer {

  public static final long COMMUNITY_TEMPLATE_MAX_BYTES = 1L * 1024 * 1024;
  public static final long COLLAB_MEDIA_MAX_BYTES = 80L * 1024 * 1024;

  private static final Pattern USERS_BACKUPS =
      Pattern.compile("^users/([^/]+)/backups(?:/.*)?$");
  private static final Pattern USERS_VAULT_BACKUPS =
      Pattern.compile("^users/([^/]+)/vaults/([^/]+)/backups(?:/.*)?$");
  private static final Pattern USERS_CLOUD_PACKS =
      Pattern.compile("^users/([^/]+)/vaults/([^/]+)/cloud-packs(?:/.*)?$");
  private static final Pattern USERS_DEVICE_SYNC =
      Pattern.compile("^users/([^/]+)/vaults/([^/]+)/device-sync(?:/.*)?$");
  private static final Pattern USERS_APP_PROFILE =
      Pattern.compile("^users/([^/]+)/app-profile(?:/.*)?$");
  private static final Pattern USERS_VAULT_PROFILES =
      Pattern.compile("^users/([^/]+)/vault-profiles/([^/]+)(?:/.*)?$");
  private static final Pattern PUBLISHED = Pattern.compile("^published/([^/]+)(?:/.*)?$");
  private static final Pattern COMMUNITY_TEMPLATE =
      Pattern.compile("^community-templates/([^/]+)/([^/]+\\.folio-template)$");
  private static final Pattern COLLAB_MEDIA =
      Pattern.compile("^collab-media-e2e/([^/]+)/([^/]+)$");

  private final FolioCloudFeatureGate featureGate;
  private final ObjectProvider<CollabMembershipLookup> collabMembershipLookup;

  public StoragePathAuthorizer(
      FolioCloudFeatureGate featureGate,
      ObjectProvider<CollabMembershipLookup> collabMembershipLookup) {
    this.featureGate = featureGate;
    this.collabMembershipLookup = collabMembershipLookup;
  }

  public void assertRead(String uid, String path) {
    authorize(uid, path, Access.READ, -1);
  }

  public void assertWrite(String uid, String path) {
    authorize(uid, path, Access.WRITE, -1);
  }

  public void assertWrite(String uid, String path, long sizeBytes) {
    authorize(uid, path, Access.WRITE, sizeBytes);
  }

  public void assertDelete(String uid, String path) {
    authorize(uid, path, Access.DELETE, -1);
  }

  /** Validates app-profile pack path (Fase 18): prefix, no {@code ..}, ends with {@code .bin}. */
  public String requireAppProfilePackPath(String uid, String raw) {
    String path = trimPath(raw);
    String prefix = "users/" + uid + "/app-profile/packs/";
    if (!path.startsWith(prefix) || path.contains("..") || !path.endsWith(".bin") || path.length() > 512) {
      throw deny("packStoragePath invalid");
    }
    assertWrite(uid, path);
    return path;
  }

  /** Validates vault-profile pack path (Fase 18). */
  public String requireVaultProfilePackPath(String uid, String vaultId, String raw) {
    String path = trimPath(raw);
    String prefix = "users/" + uid + "/vault-profiles/" + vaultId + "/packs/";
    if (!path.startsWith(prefix) || path.contains("..") || !path.endsWith(".bin") || path.length() > 512) {
      throw deny("packStoragePath invalid");
    }
    assertWrite(uid, path);
    return path;
  }

  public String requireCloudPackSnapshotPath(String uid, String vaultId, String raw) {
    String path = trimPath(raw);
    String prefix = "users/" + uid + "/vaults/" + vaultId + "/cloud-packs/snapshots/";
    if (!path.startsWith(prefix) || path.contains("..")) {
      throw deny("Invalid snapshot storage path");
    }
    assertWrite(uid, path);
    return path;
  }

  public String requireDeviceSyncPackPath(String uid, String vaultId, String raw) {
    String path = trimPath(raw);
    String prefix = "users/" + uid + "/vaults/" + vaultId + "/device-sync/packs/";
    if (!path.startsWith(prefix) || path.contains("..") || !path.endsWith(".bin") || path.length() > 512) {
      throw deny("packStoragePath invalid");
    }
    assertWrite(uid, path);
    return path;
  }

  public String requireDeviceSyncManifestPath(String uid, String vaultId, String raw) {
    String path = trimPath(raw);
    String prefix = "users/" + uid + "/vaults/" + vaultId + "/device-sync/manifests/";
    if (!path.startsWith(prefix) || path.contains("..") || !path.endsWith(".bin") || path.length() > 512) {
      throw deny("manifestStoragePath invalid");
    }
    assertWrite(uid, path);
    return path;
  }

  private void authorize(String uid, String path, Access access, long sizeBytes) {
    String p = trimPath(path);
    if (p.contains("..")) {
      throw deny("Path must not contain '..'");
    }

    Matcher m;
    if ((m = USERS_BACKUPS.matcher(p)).matches()
        || (m = USERS_VAULT_BACKUPS.matcher(p)).matches()
        || (m = USERS_CLOUD_PACKS.matcher(p)).matches()
        || (m = USERS_DEVICE_SYNC.matcher(p)).matches()
        || (m = USERS_APP_PROFILE.matcher(p)).matches()
        || (m = USERS_VAULT_PROFILES.matcher(p)).matches()) {
      String owner = m.group(1);
      requireOwner(uid, owner);
      requireBackup(uid);
      return;
    }

    if ((m = PUBLISHED.matcher(p)).matches()) {
      String owner = m.group(1);
      if (access == Access.READ) {
        return; // public read
      }
      requireOwner(uid, owner);
      requirePublish(uid);
      return;
    }

    if ((m = COMMUNITY_TEMPLATE.matcher(p)).matches()) {
      String owner = m.group(1);
      if (access == Access.READ) {
        return;
      }
      requireOwner(uid, owner);
      if (access == Access.WRITE && sizeBytes >= 0 && sizeBytes >= COMMUNITY_TEMPLATE_MAX_BYTES) {
        throw new ApiException(
            HttpStatus.BAD_REQUEST,
            "invalid_argument",
            "community template exceeds 1 MiB limit");
      }
      return;
    }

    if ((m = COLLAB_MEDIA.matcher(p)).matches()) {
      String roomId = m.group(1);
      if (access == Access.DELETE) {
        throw new ApiException(
            HttpStatus.FORBIDDEN, "permission_denied", "collab media delete is not allowed");
      }
      if (access == Access.WRITE) {
        if (sizeBytes == 0 || (sizeBytes > 0 && sizeBytes > COLLAB_MEDIA_MAX_BYTES)) {
          throw new ApiException(
              HttpStatus.BAD_REQUEST, "invalid_argument", "sizeBytes invalid (max 80 MiB)");
        }
      }
      requireCollabMember(roomId, uid);
      return;
    }

    throw deny("Unknown storage path family");
  }

  private void requireCollabMember(String roomId, String uid) {
    CollabMembershipLookup lookup = collabMembershipLookup.getIfAvailable();
    if (lookup == null || !lookup.isMember(roomId, uid)) {
      throw new ApiException(
          HttpStatus.FORBIDDEN, "permission_denied", "Not a collab room member");
    }
  }

  private void requireOwner(String uid, String owner) {
    if (uid == null || !uid.equals(owner)) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "Not the object owner");
    }
  }

  private void requireBackup(String uid) {
    if (!featureGate.backupOk(uid)) {
      throw new ApiException(
          HttpStatus.FORBIDDEN,
          "permission_denied",
          "Folio Cloud backup is not active for this account.");
    }
  }

  private void requirePublish(String uid) {
    if (!featureGate.publishWebOk(uid)) {
      throw new ApiException(
          HttpStatus.FORBIDDEN,
          "permission_denied",
          "Web publishing is not enabled for this account.");
    }
  }

  private static String trimPath(String path) {
    if (path == null) {
      return "";
    }
    String p = path.trim();
    while (p.startsWith("/")) {
      p = p.substring(1);
    }
    return p;
  }

  private static ApiException deny(String message) {
    return new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", message);
  }

  private enum Access {
    READ,
    WRITE,
    DELETE
  }

  public Optional<PathFamily> classify(String path) {
    String p = trimPath(path);
    if (USERS_BACKUPS.matcher(p).matches()) return Optional.of(PathFamily.USER_BACKUPS);
    if (USERS_VAULT_BACKUPS.matcher(p).matches()) return Optional.of(PathFamily.VAULT_BACKUPS);
    if (USERS_CLOUD_PACKS.matcher(p).matches()) return Optional.of(PathFamily.CLOUD_PACKS);
    if (USERS_DEVICE_SYNC.matcher(p).matches()) return Optional.of(PathFamily.DEVICE_SYNC);
    if (USERS_APP_PROFILE.matcher(p).matches()) return Optional.of(PathFamily.APP_PROFILE);
    if (USERS_VAULT_PROFILES.matcher(p).matches()) return Optional.of(PathFamily.VAULT_PROFILES);
    if (PUBLISHED.matcher(p).matches()) return Optional.of(PathFamily.PUBLISHED);
    if (COMMUNITY_TEMPLATE.matcher(p).matches()) return Optional.of(PathFamily.COMMUNITY_TEMPLATE);
    if (COLLAB_MEDIA.matcher(p).matches()) return Optional.of(PathFamily.COLLAB_MEDIA);
    return Optional.empty();
  }

  public enum PathFamily {
    USER_BACKUPS,
    VAULT_BACKUPS,
    CLOUD_PACKS,
    DEVICE_SYNC,
    APP_PROFILE,
    VAULT_PROFILES,
    PUBLISHED,
    COMMUNITY_TEMPLATE,
    COLLAB_MEDIA
  }
}
