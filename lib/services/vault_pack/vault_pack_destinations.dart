import '../../app/app_settings.dart';
import '../backup_destinations/backup_destination.dart';
import '../secure_credential_storage.dart';
import 'folder_vault_pack_transport.dart';
import 'vault_pack_meta.dart';
import 'vault_pack_sync.dart';
import 'vault_pack_transport.dart';
import 'webdav_vault_pack_transport.dart';

/// Construye transportes pack según preferencias de copia.
class VaultPackDestinations {
  VaultPackDestinations._();

  static Future<List<VaultPackTransport>> fromPrefs({
    required VaultBackupPrefs prefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
  }) async {
    final vid = vaultId.trim();
    final out = <VaultPackTransport>[];
    if (prefs.hasFolderDestination) {
      final folderPassword =
          await credentials.readPassword(vid, BackupCredentialScope.folder) ??
              '';
      out.add(
        FolderVaultPackTransport(
          rootDirectoryPath: prefs.directory,
          vaultId: vid,
          folderRequiresAuth: prefs.folderRequiresAuth,
          username: prefs.folderUsername,
          password: folderPassword,
          domain: prefs.folderDomain,
        ),
      );
    }
    if (prefs.hasWebDavDestination) {
      final webdavPassword =
          await credentials.readPassword(vid, BackupCredentialScope.webdav) ??
              '';
      out.add(
        WebDavVaultPackTransport(
          baseUrl: prefs.webdavBaseUrl,
          remotePath: prefs.webdavRemotePath,
          username: prefs.webdavUsername,
          password: webdavPassword,
          vaultId: vid,
        ),
      );
    }
    return out;
  }

  static Future<VaultPackTransport?> folderTransport({
    required VaultBackupPrefs prefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
  }) async {
    final dir = prefs.directory.trim();
    if (dir.isEmpty) return null;
    final folderPassword =
        await credentials.readPassword(
              vaultId,
              BackupCredentialScope.folder,
            ) ??
            '';
    return FolderVaultPackTransport(
      rootDirectoryPath: dir,
      vaultId: vaultId,
      folderRequiresAuth: prefs.folderRequiresAuth,
      username: prefs.folderUsername,
      password: folderPassword,
      domain: prefs.folderDomain,
    );
  }

  static Future<VaultPackTransport?> webdavTransport({
    required VaultBackupPrefs prefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
  }) async {
    if (prefs.webdavBaseUrl.trim().isEmpty) return null;
    final webdavPassword =
        await credentials.readPassword(
              vaultId,
              BackupCredentialScope.webdav,
            ) ??
            '';
    return WebDavVaultPackTransport(
      baseUrl: prefs.webdavBaseUrl,
      remotePath: prefs.webdavRemotePath,
      username: prefs.webdavUsername,
      password: webdavPassword,
      vaultId: vaultId,
    );
  }
}

/// Lista packs incrementales en carpeta configurada.
Future<List<RemoteBackupEntry>> listFolderPackBackupEntries({
  required VaultBackupPrefs prefs,
  required String vaultId,
  required SecureCredentialStorage credentials,
}) async {
  final dir = prefs.directory.trim();
  if (dir.isEmpty) return const [];
  final folderPassword =
      await credentials.readPassword(vaultId, BackupCredentialScope.folder) ??
          '';
  final ids = await FolderVaultPackTransport.listVaultIds(
    rootDirectoryPath: dir,
    folderRequiresAuth: prefs.folderRequiresAuth,
    username: prefs.folderUsername,
    password: folderPassword,
    domain: prefs.folderDomain,
  );
  final out = <RemoteBackupEntry>[];
  for (final id in ids) {
    final t = FolderVaultPackTransport(
      rootDirectoryPath: dir,
      vaultId: id,
      folderRequiresAuth: prefs.folderRequiresAuth,
      username: prefs.folderUsername,
      password: folderPassword,
      domain: prefs.folderDomain,
    );
    final meta = await t.readMeta();
    if (meta == null) continue;
    out.add(_entryFromMeta(id, meta));
  }
  return out;
}

/// Lista packs incrementales en WebDAV configurado.
Future<List<RemoteBackupEntry>> listWebDavPackBackupEntries({
  required VaultBackupPrefs prefs,
  required String vaultId,
  required SecureCredentialStorage credentials,
}) async {
  if (prefs.webdavBaseUrl.trim().isEmpty) return const [];
  final webdavPassword =
      await credentials.readPassword(vaultId, BackupCredentialScope.webdav) ??
          '';
  final ids = await WebDavVaultPackTransport.listVaultIds(
    baseUrl: prefs.webdavBaseUrl,
    remotePath: prefs.webdavRemotePath,
    username: prefs.webdavUsername,
    password: webdavPassword,
  );
  final out = <RemoteBackupEntry>[];
  for (final id in ids) {
    final t = WebDavVaultPackTransport(
      baseUrl: prefs.webdavBaseUrl,
      remotePath: prefs.webdavRemotePath,
      username: prefs.webdavUsername,
      password: webdavPassword,
      vaultId: id,
    );
    final meta = await t.readMeta();
    if (meta == null) continue;
    out.add(_entryFromMeta(id, meta));
  }
  return out;
}

RemoteBackupEntry _entryFromMeta(String vaultId, VaultPackMeta meta) {
  DateTime? modified;
  try {
    modified = DateTime.parse(meta.updatedAtUtc);
  } catch (_) {}
  return RemoteBackupEntry(
    name: vaultPackListEntryName(vaultId: vaultId),
    modifiedAt: modified,
    sizeBytes: meta.snapshotSizeBytes > 0 ? meta.snapshotSizeBytes : null,
    isIncrementalPack: true,
    packVaultId: vaultId,
  );
}
