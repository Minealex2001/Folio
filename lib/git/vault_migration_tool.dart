/// Herramienta de migración: convierte vaults del formato viejo al nuevo.
///
/// Invariantes de seguridad:
/// - Backup real `vault.bin.pre-migration` antes de tocar el árbol
/// - Escritura en `repo.tmp/` + verificación round-trip antes del swap
/// - Marker `vault.format` sin tragarse errores
/// - No borra `vault.bin` (lo hace la sesión tras sync/verificación)

import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/errors/vault_corruption_exception.dart';
import '../data/vault_payload.dart';
import '../data/vault_paths.dart';
import '../models/folio_page.dart';
import '../models/folio_page_revision.dart';
import 'vault_integrity.dart';
import 'vault_payload_converters.dart';
import 'vault_snapshot_manager.dart';

class VaultMigrationResult {
  VaultMigrationResult({
    required this.success,
    required this.vaultId,
    required this.message,
    required this.filesCreated,
    required this.snapshotsCreated,
    this.error,
    this.contentFingerprint,
  });

  final bool success;
  final String vaultId;
  final String message;
  final int filesCreated;
  final int snapshotsCreated;
  final String? error;
  final String? contentFingerprint;
}

class VaultMigrationTool {
  VaultMigrationTool._();

  static const String preMigrationBinSuffix = '.pre-migration';
  static const String v1VerifiedFile = 'vault.v1-verified';

  /// Detecta si una libreta está migrada (tiene árbol).
  static Future<bool> isMigrated() async {
    try {
      final treeDir = await VaultPaths.vaultTreeDirectory();
      final treeJsonFile = File(p.join(treeDir.path, 'tree.json'));
      return treeJsonFile.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Migra una libreta del formato viejo al nuevo.
  static Future<VaultMigrationResult> migrateVault({
    required VaultPayload payload,
    required String deviceId,
  }) async {
    Directory? tmpDir;
    try {
      final vaultId = VaultPaths.activeVaultId;
      if (vaultId == null || vaultId.isEmpty) {
        return VaultMigrationResult(
          success: false,
          vaultId: 'unknown',
          message: 'No vault active',
          filesCreated: 0,
          snapshotsCreated: 0,
          error: 'No active vault ID',
        );
      }

      final vaultDir = await VaultPaths.vaultDirectory();
      await _createPreMigrationBackup(vaultDir);

      tmpDir = Directory(p.join(vaultDir.path, 'repo.tmp'));
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
      await tmpDir.create(recursive: true);

      // Estado actual → tmp + verificación obligatoria
      await VaultPayloadToTree.decompose(payload, tmpDir);
      await _verifyRoundTrip(payload, tmpDir);

      final snapshotManager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: deviceId,
      );
      await snapshotManager.init();

      var snapshotsCreated = 0;
      String? parentSnapshotId;

      final pagesById = {for (final page in payload.pages) page.id: page};
      for (final entry in payload.pageRevisions.entries) {
        final currentPage = pagesById[entry.key];
        if (currentPage == null) continue;

        final revisions = List<FolioPageRevision>.from(entry.value)
          ..sort((a, b) => a.savedAtMs.compareTo(b.savedAtMs));
        for (final revision in revisions) {
          final pageAtRevision = FolioPage(
            id: currentPage.id,
            title: revision.title,
            emoji: currentPage.emoji,
            parentId: currentPage.parentId,
            isFolder: currentPage.isFolder,
            trashedAt: currentPage.trashedAt,
            collabRoomId: currentPage.collabRoomId,
            lastImportInfo: currentPage.lastImportInfo,
            blocks: revision.decodeBlocks(),
            properties: List.from(currentPage.properties),
            tags: List.from(currentPage.tags),
          );
          await VaultPayloadToTree.writePageFiles(tmpDir, pageAtRevision);
          final snap = await snapshotManager.createSnapshot(
            treeDir: tmpDir,
            label: revision.title.isNotEmpty ? revision.title : null,
            parentSnapshotId: parentSnapshotId,
          );
          parentSnapshotId = snap.snapshotId;
          snapshotsCreated++;
        }
      }

      // Restaurar estado actual y verificar de nuevo
      await VaultPayloadToTree.decompose(payload, tmpDir);
      await _verifyRoundTrip(payload, tmpDir);

      await snapshotManager.createSnapshot(
        treeDir: tmpDir,
        label: null,
        parentSnapshotId: parentSnapshotId,
      );
      snapshotsCreated += 1;

      final filesCreated = await _countFilesInDirectory(tmpDir);
      final fingerprint = VaultIntegrity.fingerprintPages(payload);

      // Swap atómico repo.tmp → repo
      await _swapTmpToRepo(vaultDir, tmpDir);
      tmpDir = null;

      await writeTreeFormatVersion(1);
      await writeV1VerifiedMarker(fingerprint);

      return VaultMigrationResult(
        success: true,
        vaultId: vaultId,
        message: 'Vault migrated successfully to new format',
        filesCreated: filesCreated,
        snapshotsCreated: snapshotsCreated,
        contentFingerprint: fingerprint,
      );
    } catch (e) {
      if (tmpDir != null && tmpDir.existsSync()) {
        try {
          await tmpDir.delete(recursive: true);
        } catch (_) {}
      }
      return VaultMigrationResult(
        success: false,
        vaultId: VaultPaths.activeVaultId ?? 'unknown',
        message: 'Migration failed',
        filesCreated: 0,
        snapshotsCreated: 0,
        error: e.toString(),
      );
    }
  }

  static Future<void> _verifyRoundTrip(
    VaultPayload expected,
    Directory treeDir,
  ) async {
    final composed = await TreeToVaultPayload.compose(treeDir);
    try {
      VaultIntegrity.assertPagesMatch(expected, composed);
    } on VaultIntegrityMismatch catch (e) {
      throw VaultCorruptionException(
        'Migration round-trip verification failed: $e',
        cause: e,
      );
    }
  }

  static Future<void> _swapTmpToRepo(
    Directory vaultDir,
    Directory tmpDir,
  ) async {
    final repoDir = Directory(p.join(vaultDir.path, 'repo'));
    final oldDir = Directory(p.join(vaultDir.path, 'repo.old'));
    if (oldDir.existsSync()) {
      await oldDir.delete(recursive: true);
    }
    if (repoDir.existsSync()) {
      await repoDir.rename(oldDir.path);
    }
    await tmpDir.rename(repoDir.path);
    if (oldDir.existsSync()) {
      await oldDir.delete(recursive: true);
    }
  }

  /// Rollback de migración (restaura desde backup).
  static Future<bool> rollbackMigration() async {
    try {
      final vaultId = VaultPaths.activeVaultId;
      if (vaultId == null || vaultId.isEmpty) return false;

      final vaultDir = await VaultPaths.vaultDirectory();
      final preBin = File(
        p.join(vaultDir.path, 'vault.bin$preMigrationBinSuffix'),
      );
      final liveBin = File(p.join(vaultDir.path, 'vault.bin'));
      if (preBin.existsSync()) {
        if (liveBin.existsSync()) await liveBin.delete();
        await preBin.copy(liveBin.path);
      } else {
        final restored = await VaultPaths.restoreCipherPayloadFromBackup();
        if (!restored) return false;
      }

      final preKeys = File(
        p.join(vaultDir.path, 'vault.keys$preMigrationBinSuffix'),
      );
      final liveKeys = File(p.join(vaultDir.path, 'vault.keys'));
      if (preKeys.existsSync()) {
        if (liveKeys.existsSync()) await liveKeys.delete();
        await preKeys.copy(liveKeys.path);
      } else {
        await VaultPaths.restoreWrappedDekFromBackup();
      }

      await VaultPaths.restoreVaultModeFromBackup();

      final treeDir = await VaultPaths.vaultTreeDirectory();
      if (treeDir.existsSync()) {
        await treeDir.delete(recursive: true);
      }
      final tmp = Directory(p.join(vaultDir.path, 'repo.tmp'));
      if (tmp.existsSync()) await tmp.delete(recursive: true);

      await writeTreeFormatVersion(0);
      final verified = File(p.join(vaultDir.path, v1VerifiedFile));
      if (verified.existsSync()) await verified.delete();

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<int> _countFilesInDirectory(Directory dir) async {
    var count = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) count++;
    }
    return count;
  }

  /// Copia atómica de vault.bin / vault.keys a `.pre-migration`.
  static Future<void> _createPreMigrationBackup(Directory vaultDir) async {
    final bin = File(p.join(vaultDir.path, 'vault.bin'));
    if (!bin.existsSync()) {
      // Libreta nueva solo-árbol o ya sin blob: no hay nada que respaldar.
      return;
    }
    final dest = File(p.join(vaultDir.path, 'vault.bin$preMigrationBinSuffix'));
    await bin.copy(dest.path);

    final keys = File(p.join(vaultDir.path, 'vault.keys'));
    if (keys.existsSync()) {
      await keys.copy(
        p.join(vaultDir.path, 'vault.keys$preMigrationBinSuffix'),
      );
    }
  }

  /// True si existe `vault.bin.pre-migration` en la libreta activa.
  static Future<bool> hasPreMigrationBackup() async {
    try {
      final vaultDir = await VaultPaths.vaultDirectory();
      return File(
        p.join(vaultDir.path, 'vault.bin$preMigrationBinSuffix'),
      ).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Escribe el marker de versión de formato. Falla si no puede escribirse.
  static Future<void> writeTreeFormatVersion(int version) async {
    final vaultDir = await VaultPaths.vaultDirectory();
    final markerFile = File(p.join(vaultDir.path, 'vault.format'));
    await markerFile.writeAsString(version.toString(), flush: true);
    final readBack = await markerFile.readAsString();
    if (int.tryParse(readBack.trim()) != version) {
      throw StateError('Failed to persist vault.format=$version');
    }
  }

  static Future<void> writeV1VerifiedMarker(String fingerprint) async {
    final vaultDir = await VaultPaths.vaultDirectory();
    final file = File(p.join(vaultDir.path, v1VerifiedFile));
    await file.writeAsString(
      canonicalJson({
        'fingerprint': fingerprint,
        'verifiedAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
      flush: true,
    );
  }

  static Future<bool> isV1Verified() async {
    try {
      final vaultDir = await VaultPaths.vaultDirectory();
      return File(p.join(vaultDir.path, v1VerifiedFile)).existsSync();
    } catch (_) {
      return false;
    }
  }

  static Future<int> readTreeFormatVersion() async {
    try {
      final vaultDir = await VaultPaths.vaultDirectory();
      final markerFile = File(p.join(vaultDir.path, 'vault.format'));
      if (!markerFile.existsSync()) {
        return _inferFormatFromTree(vaultDir);
      }
      final content = await markerFile.readAsString();
      final parsed = int.tryParse(content.trim());
      if (parsed != null) return parsed;
      return _inferFormatFromTree(vaultDir);
    } catch (_) {
      return 0;
    }
  }

  /// Marker ausente/ilegible: si ya hay árbol v1, no tratarlo como v0 (mismo
  /// fallback que `HeadlessDeviceSyncVault._formatVersion` — evita que la
  /// sesión UI trate una libreta ya migrada como legacy tras un crash entre
  /// el swap atómico y la escritura del marker).
  static int _inferFormatFromTree(Directory vaultDir) {
    final treeJson = File(p.join(vaultDir.path, 'repo', 'tree.json'));
    return treeJson.existsSync() ? 1 : 0;
  }
}
