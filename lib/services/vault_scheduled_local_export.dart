import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../app/app_settings.dart';
import '../data/vault_backup.dart';
import '../session/vault_session.dart';
import 'folio_cloud/folio_cloud_backup.dart';
import 'folio_cloud/folio_cloud_pack_sync.dart';
import 'folio_cloud/folio_cloud_entitlements.dart';

/// Escribe un ZIP de copia programada en [prefs.directory] si la carpeta está activa y configurada.
Future<void> exportScheduledVaultZipToConfiguredFolder({
  required VaultSession session,
  required VaultBackupPrefs prefs,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException('La libreta debe estar desbloqueada.');
  }
  final dir = prefs.directory.trim();
  if (!prefs.folderEnabled || dir.isEmpty) return;

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

/// Exporta la libreta **abierta** según las opciones configuradas en [AppSettings]
/// para la libreta identificada por [vaultId]:
/// - Backup a carpeta local (ZIP) si [VaultBackupPrefs.folderEnabled] y hay directorio.
/// - Backup a la nube si [VaultBackupPrefs.alsoCloud] y hay entitlement.
/// Ambas opciones son independientes y pueden estar activas al mismo tiempo.
Future<void> runScheduledFolderVaultExport({
  required VaultSession session,
  required AppSettings appSettings,
  String? vaultId,
  FolioCloudEntitlementsController? folioEntitlements,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException('La libreta debe estar desbloqueada.');
  }

  final vid = (vaultId ?? session.activeVaultId ?? '').trim();
  final prefs = await appSettings.getVaultBackupPrefs(vid.isEmpty ? null : vid);
  final dir = prefs.directory.trim();
  final wantFolder = prefs.folderEnabled && dir.isNotEmpty;
  final canCloud =
      folioEntitlements != null &&
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null &&
      folioEntitlements.snapshot.canUseCloudBackup;
  final wantCloud = prefs.alsoCloud && canCloud;

  if (!wantFolder && !wantCloud) {
    throw VaultBackupException('No hay destino de copia configurado.');
  }

  // — Backup local —
  if (wantFolder) {
    await exportScheduledVaultZipToConfiguredFolder(session: session, prefs: prefs);
  }

  // — Backup en la nube —
  if (wantCloud) {
    final activeVaultId = vid.isEmpty ? session.activeVaultId : vid;
    if (activeVaultId == null || activeVaultId.trim().isEmpty) {
      throw VaultBackupException('No hay libreta activa.');
    }
    await uploadOpenVaultCloudPack(
      session: session,
      vaultId: activeVaultId,
      entitlementSnapshot: folioEntitlements.snapshot,
      telemetrySettings: appSettings,
    );
    try {
      final label = await session.getActiveVaultDisplayLabel();
      await upsertFolioCloudBackupVaultIndex(
        vaultId: activeVaultId,
        displayName: label,
        entitlementSnapshot: folioEntitlements.snapshot,
      );
    } catch (e) {
      debugPrint('Folio scheduled backup cloud index: $e');
    }
  }

  await appSettings.setVaultBackupLastMs(
    vid.isEmpty ? null : vid,
    DateTime.now().millisecondsSinceEpoch,
  );
}
