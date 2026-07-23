import 'dart:io';

import 'package:path/path.dart' as p;

import '../../app/app_settings.dart';
import '../../data/vault_backup.dart';
import '../../session/vault_session.dart';
import '../secure_credential_storage.dart';
import 'backup_destination.dart';
import 'local_folder_destination.dart';
import 'webdav_destination.dart';

/// Destinos de copia activos según preferencias.
class VaultBackupDestinations {
  VaultBackupDestinations._();

  static Future<List<BackupDestination>> fromPrefs({
    required VaultBackupPrefs prefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
    bool folder = true,
    bool webdav = true,
  }) async {
    final out = <BackupDestination>[];
    final dir = prefs.directory.trim();
    if (folder && prefs.folderEnabled && dir.isNotEmpty) {
      final folderPassword =
          await credentials.readPassword(vaultId, BackupCredentialScope.folder) ??
          '';
      out.add(
        LocalFolderDestination(
          directoryPath: dir,
          folderRequiresAuth: prefs.folderRequiresAuth,
          username: prefs.folderUsername,
          password: folderPassword,
          domain: prefs.folderDomain,
        ),
      );
    }
    if (webdav && prefs.webdavEnabled && prefs.webdavBaseUrl.trim().isNotEmpty) {
      final webdavPassword =
          await credentials.readPassword(vaultId, BackupCredentialScope.webdav) ??
          '';
      out.add(
        WebDavDestination(
          baseUrl: prefs.webdavBaseUrl,
          remotePath: prefs.webdavRemotePath,
          username: prefs.webdavUsername,
          password: webdavPassword,
        ),
      );
    }
    return out;
  }

  /// Destinos configurados para restaurar o exportar manual (sin exigir copia programada).
  static Future<BackupDestination?> configuredFolder({
    required VaultBackupPrefs prefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
  }) async {
    final dir = prefs.directory.trim();
    if (dir.isEmpty) return null;
    final folderPassword =
        await credentials.readPassword(vaultId, BackupCredentialScope.folder) ??
        '';
    return LocalFolderDestination(
      directoryPath: dir,
      folderRequiresAuth: prefs.folderRequiresAuth,
      username: prefs.folderUsername,
      password: folderPassword,
      domain: prefs.folderDomain,
    );
  }

  static Future<BackupDestination?> configuredWebDav({
    required VaultBackupPrefs prefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
  }) async {
    if (prefs.webdavBaseUrl.trim().isEmpty) return null;
    final webdavPassword =
        await credentials.readPassword(vaultId, BackupCredentialScope.webdav) ??
        '';
    return WebDavDestination(
      baseUrl: prefs.webdavBaseUrl,
      remotePath: prefs.webdavRemotePath,
      username: prefs.webdavUsername,
      password: webdavPassword,
    );
  }

  static bool hasNetworkDestination(VaultBackupPrefs prefs) {
    final dir = prefs.directory.trim();
    final folder = prefs.folderEnabled && dir.isNotEmpty;
    final wd =
        prefs.webdavEnabled && prefs.webdavBaseUrl.trim().isNotEmpty;
    return folder || wd;
  }
}

/// Genera un ZIP y lo envía a los destinos configurados.
class BackupExportRunner {
  BackupExportRunner({
    SecureCredentialStorage? credentials,
  }) : _credentials = credentials ?? SecureCredentialStorage();

  final SecureCredentialStorage _credentials;

  Future<File> createVaultBackupZip(VaultSession session) async {
    if (!session.isUnlocked) {
      throw VaultBackupException('La libreta debe estar desbloqueada.');
    }
    await session.persistNow();
    final vaultBinBytes = await session.vaultBinEquivalentBytes();
    final tempDir = await Directory.systemTemp.createTemp('folio_backup_');
    final fileName = scheduledVaultBackupFileName();
    final zipPath = p.join(tempDir.path, fileName);
    await exportVaultZip(File(zipPath), vaultBinBytes: vaultBinBytes);
    return File(zipPath);
  }

  Future<String> exportToDestinations({
    required VaultSession session,
    required VaultBackupPrefs prefs,
    required String vaultId,
    List<BackupDestination>? onlyDestinations,
  }) async {
    final destinations =
        onlyDestinations ??
        await VaultBackupDestinations.fromPrefs(
          prefs: prefs,
          vaultId: vaultId,
          credentials: _credentials,
        );
    if (destinations.isEmpty) {
      throw VaultBackupException('No hay destino de copia configurado.');
    }

    final zipFile = await createVaultBackupZip(session);
    final fileName = p.basename(zipFile.path);
    try {
      for (final dest in destinations) {
        await dest.uploadZip(zipFile, fileName);
        await dest.pruneOld(prefs.retentionCount);
      }
    } finally {
      try {
        final parent = zipFile.parent;
        if (zipFile.existsSync()) await zipFile.delete();
        if (parent.existsSync()) await parent.delete(recursive: true);
      } catch (_) {}
    }
    return fileName;
  }
}
