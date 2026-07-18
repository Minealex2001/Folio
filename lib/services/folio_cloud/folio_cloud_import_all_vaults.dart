import '../../app/app_settings.dart';
import '../../crypto/vault_crypto.dart';
import '../../data/vault_backup.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import 'folio_cloud_backup.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_pack_sync.dart';

/// Resultado de importar todas las libretas de Folio Cloud.
class FolioCloudImportAllResult {
  const FolioCloudImportAllResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.errors,
    this.firstImportedVaultId,
    this.firstRestorePassword,
  });

  final int imported;
  final int skipped;
  final int failed;
  final List<String> errors;

  /// Id de la primera libreta importada (para desbloquear en onboarding).
  final String? firstImportedVaultId;

  /// Contraseña que funcionó al restaurar la primera (cuenta o master de libreta).
  final String? firstRestorePassword;

  bool get hasImports => imported > 0;
}

typedef FolioCloudVaultPasswordPrompt =
    Future<String?> Function({
      required String vaultId,
      required String displayName,
    });

/// Descarga e importa todas las libretas con copia en la nube.
///
/// Usa [accountPassword] solo como `restorePassword` del cloud-pack.
/// No cambia la master de cada libreta ni desbloquea de forma permanente.
///
/// En todas las plataformas descarga a memoria (sin `Directory.systemTemp`),
/// para que web (IndexedDB) funcione igual que desktop.
Future<FolioCloudImportAllResult> importAllFolioCloudVaults({
  required VaultSession session,
  required String accountPassword,
  required FolioCloudSnapshot entitlements,
  FolioCloudVaultPasswordPrompt? onNeedVaultPassword,
  void Function(int current, int total, String label)? onProgress,
  AppSettings? telemetrySettings,
}) async {
  final vaults = await listFolioCloudBackupVaults(
    entitlementSnapshot: entitlements,
  );
  AppLogger.info(
    'importAllFolioCloudVaults start',
    tag: 'cloud-pack',
    context: {'vaultCount': vaults.length},
  );
  if (vaults.isEmpty) {
    return const FolioCloudImportAllResult(
      imported: 0,
      skipped: 0,
      failed: 0,
      errors: [],
    );
  }

  final localEmpty = await session.isLocalVaultEmptyForCloudImport();
  var imported = 0;
  var skipped = 0;
  var failed = 0;
  final errors = <String>[];
  String? firstId;
  String? firstPwd;

  for (var i = 0; i < vaults.length; i++) {
    final entry = vaults[i];
    final label = entry.displayName.trim().isNotEmpty
        ? entry.displayName.trim()
        : entry.vaultId;
    onProgress?.call(i + 1, vaults.length, label);

    // Ya materializada localmente con el mismo id → no volver a importar.
    if (await session.containsVault(entry.vaultId)) {
      skipped++;
      AppLogger.debug(
        'import vault skipped: already local',
        tag: 'cloud-pack',
        context: {'vaultId': entry.vaultId},
      );
      continue;
    }

    final backups = await listFolioCloudBackups(
      vaultId: entry.vaultId,
      entitlementSnapshot: entitlements,
    );
    final hasCloudPack = backups.any((b) => b.isCloudPack);
    if (!hasCloudPack) {
      skipped++;
      errors.add('$label: no cloud-pack');
      AppLogger.debug(
        'import vault skipped: no cloud-pack',
        tag: 'cloud-pack',
        context: {'vaultId': entry.vaultId},
      );
      continue;
    }

    bool? isPlain;
    try {
      isPlain = await cloudPackRestoreIsPlainVault(vaultId: entry.vaultId);
    } catch (_) {
      isPlain = null;
    }

    var restorePassword = (isPlain == true) ? '' : accountPassword;
    try {
      ExtractedVaultBackup? backup;
      try {
        backup = await downloadCloudPackToMemoryForRestore(
          vaultId: entry.vaultId,
          restorePassword: restorePassword,
          entitlementSnapshot: entitlements,
          telemetrySettings: telemetrySettings,
        );
      } on VaultCryptoException {
        if (isPlain == true) rethrow;
        final fallback = onNeedVaultPassword == null
            ? null
            : await onNeedVaultPassword(
                vaultId: entry.vaultId,
                displayName: label,
              );
        if (fallback == null || fallback.isEmpty) {
          failed++;
          errors.add('$label: password');
          AppLogger.warn(
            'import vault failed: password needed',
            tag: 'cloud-pack',
            context: {'vaultId': entry.vaultId},
          );
          continue;
        }
        restorePassword = fallback;
        backup = await downloadCloudPackToMemoryForRestore(
          vaultId: entry.vaultId,
          restorePassword: restorePassword,
          entitlementSnapshot: entitlements,
          telemetrySettings: telemetrySettings,
        );
      }

      final isFirst = imported == 0 && localEmpty;
      await session.importCloudVaultAsLocalFromMemory(
        cloudVaultId: entry.vaultId,
        backup: backup,
        password: restorePassword,
        displayName: entry.displayName.trim().isEmpty ? null : entry.displayName,
        overwriteIfExists: isFirst,
        setActive:
            isFirst ||
            (imported == 0 && !localEmpty && session.activeVaultId == null),
      );

      if (firstId == null) {
        firstId = entry.vaultId;
        firstPwd = restorePassword;
      }
      imported++;
      AppLogger.info(
        'import vault ok',
        tag: 'cloud-pack',
        context: {
          'vaultId': entry.vaultId,
          'plain': isPlain == true,
        },
      );
    } catch (e) {
      failed++;
      errors.add('$label: $e');
      AppLogger.error(
        'import vault failed',
        tag: 'cloud-pack',
        error: e,
        context: {'vaultId': entry.vaultId},
      );
    }
  }

  AppLogger.info(
    'importAllFolioCloudVaults done',
    tag: 'cloud-pack',
    context: {
      'imported': imported,
      'skipped': skipped,
      'failed': failed,
    },
  );

  return FolioCloudImportAllResult(
    imported: imported,
    skipped: skipped,
    failed: failed,
    errors: errors,
    firstImportedVaultId: firstId,
    firstRestorePassword: firstPwd,
  );
}
