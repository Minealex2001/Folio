import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../app/app_settings.dart';
import '../data/vault_backup.dart';
import '../session/vault_session.dart';
import 'backup_destinations/backup_export_runner.dart';
import 'folio_cloud/folio_cloud_backup.dart';
import 'folio_cloud/folio_cloud_pack_sync.dart';
import 'folio_cloud/folio_cloud_entitlements.dart';
import 'secure_credential_storage.dart';

/// Escribe un ZIP de copia programada en los destinos de red configurados.
Future<void> exportScheduledVaultZipToConfiguredFolder({
  required VaultSession session,
  required VaultBackupPrefs prefs,
  required String vaultId,
  SecureCredentialStorage? credentials,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException('La libreta debe estar desbloqueada.');
  }
  if (!prefs.hasNetworkDestination) return;

  await BackupExportRunner(credentials: credentials).exportToDestinations(
    session: session,
    prefs: prefs,
    vaultId: vaultId,
  );
}

/// Exporta la libreta **abierta** según las opciones configuradas en [AppSettings]
/// para la libreta identificada por [vaultId]:
/// - Backup a carpeta local/red (ZIP) si está activo.
/// - Backup WebDAV si está activo.
/// - Backup a la nube si [VaultBackupPrefs.alsoCloud] y hay entitlement.
Future<void> runScheduledFolderVaultExport({
  required VaultSession session,
  required AppSettings appSettings,
  String? vaultId,
  FolioCloudEntitlementsController? folioEntitlements,
  SecureCredentialStorage? credentials,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException('La libreta debe estar desbloqueada.');
  }

  final vid = (vaultId ?? session.activeVaultId ?? '').trim();
  final prefs = await appSettings.getVaultBackupPrefs(vid.isEmpty ? null : vid);
  final wantFolder = prefs.hasFolderDestination;
  final wantWebdav = prefs.hasWebDavDestination;
  final canCloud =
      folioEntitlements != null &&
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null &&
      folioEntitlements.snapshot.canUseCloudBackup;
  final wantCloud = prefs.alsoCloud && canCloud;

  if (!wantFolder && !wantWebdav && !wantCloud) {
    throw VaultBackupException('No hay destino de copia configurado.');
  }

  final runner = BackupExportRunner(credentials: credentials);
  if (wantFolder || wantWebdav) {
    await runner.exportToDestinations(
      session: session,
      prefs: prefs,
      vaultId: vid,
    );
  }

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

/// Indica si hay algún destino de copia programada activo (red o nube).
bool scheduledVaultBackupHasDestination(
  VaultBackupPrefs prefs, {
  required bool canCloud,
}) {
  return prefs.hasNetworkDestination || (prefs.alsoCloud && canCloud);
}
