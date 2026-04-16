import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../app/app_settings.dart';
import '../data/vault_backup.dart';
import '../session/vault_session.dart';
import 'folio_cloud/folio_cloud_backup.dart';
import 'folio_cloud/folio_cloud_entitlements.dart';

/// Exporta la libreta **abierta** según las opciones configuradas en [AppSettings]:
/// - Backup a carpeta local (ZIP) si [AppSettings.scheduledVaultBackupFolderEnabled] y hay directorio.
/// - Backup a la nube si [AppSettings.scheduledVaultBackupAlsoUploadCloud] y hay entitlement.
/// Ambas opciones son independientes y pueden estar activas al mismo tiempo.
Future<void> runScheduledFolderVaultExport({
  required VaultSession session,
  required AppSettings appSettings,
  FolioCloudEntitlementsController? folioEntitlements,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException('La libreta debe estar desbloqueada.');
  }

  final dir = appSettings.scheduledVaultBackupDirectory.trim();
  final wantFolder =
      appSettings.scheduledVaultBackupFolderEnabled && dir.isNotEmpty;
  final canCloud =
      folioEntitlements != null &&
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null &&
      folioEntitlements.snapshot.canUseCloudBackup;
  final wantCloud = appSettings.scheduledVaultBackupAlsoUploadCloud && canCloud;

  if (!wantFolder && !wantCloud) {
    throw VaultBackupException('No hay destino de copia configurado.');
  }

  final now = DateTime.now().millisecondsSinceEpoch;

  // — Backup local —
  if (wantFolder) {
    final destDir = Directory(dir);
    if (!destDir.existsSync()) {
      try {
        await destDir.create(recursive: true);
      } catch (e) {
        throw VaultBackupException('No se pudo crear la carpeta: $e');
      }
    }
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final base = stamp.contains('.') ? stamp.split('.').first : stamp;
    final backupPath = p.join(dir, 'folio-scheduled-$base.zip');
    await session.exportVaultBackup(backupPath);
  }

  // — Backup en la nube —
  if (wantCloud) {
    final vaultId = session.activeVaultId;
    if (vaultId == null || vaultId.trim().isEmpty) {
      throw VaultBackupException('No hay libreta activa.');
    }
    await uploadOpenVaultEncryptedToCloud(
      session: session,
      vaultId: vaultId,
      entitlementSnapshot: folioEntitlements!.snapshot,
    );
    try {
      final label = await session.getActiveVaultDisplayLabel();
      await upsertFolioCloudBackupVaultIndex(
        vaultId: vaultId,
        displayName: label,
        entitlementSnapshot: folioEntitlements.snapshot,
      );
    } catch (e) {
      debugPrint('Folio scheduled backup cloud index: $e');
    }
    try {
      await trimFolioCloudBackups(
        vaultId: vaultId,
        maxCount: 10,
        entitlementSnapshot: folioEntitlements.snapshot,
      );
    } catch (e) {
      debugPrint('Folio scheduled backup cloud trim: $e');
    }
    try {
      await trimFolioCloudBackupsByBytes(
        vaultId: vaultId,
        maxBytes: 5 * 1024 * 1024 * 1024, // 5 GB
        entitlementSnapshot: folioEntitlements.snapshot,
      );
    } catch (e) {
      debugPrint('Folio scheduled backup cloud trim-bytes: $e');
    }
  }

  await appSettings.setLastScheduledVaultBackupMs(now);
}
