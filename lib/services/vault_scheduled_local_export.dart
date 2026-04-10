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

/// Exporta la libreta **abierta** al directorio configurado en [AppSettings.scheduledVaultBackupDirectory].
/// Opcionalmente sube a Folio Cloud si el usuario lo tiene activado.
Future<void> runScheduledFolderVaultExport({
  required VaultSession session,
  required AppSettings appSettings,
  FolioCloudEntitlementsController? folioEntitlements,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException('La libreta debe estar desbloqueada.');
  }

  final dir = appSettings.scheduledVaultBackupDirectory.trim();
  final canCloud = folioEntitlements != null &&
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null &&
      folioEntitlements.snapshot.canUseCloudBackup;
  final wantCloud =
      appSettings.scheduledVaultBackupAlsoUploadCloud && canCloud;
  final now = DateTime.now().millisecondsSinceEpoch;

  if (dir.isEmpty) {
    if (!wantCloud) {
      throw VaultBackupException('Carpeta de copias no configurada.');
    }
    final vaultId = session.activeVaultId;
    if (vaultId == null || vaultId.trim().isEmpty) {
      throw VaultBackupException('No hay libreta activa.');
    }
    await uploadOpenVaultEncryptedToCloud(
      session: session,
      vaultId: vaultId,
      entitlementSnapshot: folioEntitlements.snapshot,
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
    await appSettings.setLastScheduledVaultBackupMs(now);
    return;
  }

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
  final path = p.join(dir, 'folio-scheduled-$base.zip');
  await session.exportVaultBackup(path);
  await appSettings.setLastScheduledVaultBackupMs(now);
  if (wantCloud) {
    try {
      final vaultId = session.activeVaultId;
      if (vaultId == null || vaultId.trim().isEmpty) {
        throw VaultBackupException('No hay libreta activa.');
      }
      await uploadEncryptedBackupFile(
        File(path),
        vaultId: vaultId,
        entitlementSnapshot: folioEntitlements.snapshot,
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
    } catch (e) {
      debugPrint('Folio scheduled backup cloud upload: $e');
    }
  }
}
