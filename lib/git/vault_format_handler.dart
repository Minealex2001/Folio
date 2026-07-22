/// Handler dual v0/v1 para VaultSession (M5).
///
/// Abstracción que permite a vault_session.dart funcionar igual
/// con ambos formatos (viejo monolítico y nuevo árbol).
///
/// En M5, se integra directamente en vault_session.dart en:
/// - _capturePendingRevisionsAndPersist()
/// - persistNow()
/// - revisionsForPage() / versionsForPage()
/// - restorePageRevision() / restoreVersion()

import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/vault_payload.dart';
import '../data/vault_paths.dart';
import '../data/vault_local_storage.dart';
import 'vault_migration_tool.dart';
import 'vault_snapshot_manager.dart';
import 'version_info.dart';

/// Handler que abstrae la diferencia entre formatos v0 y v1.
class VaultFormatHandler {
  VaultFormatHandler({
    required String deviceId,
    this.onMigrationNeeded,
  }) : _deviceId = deviceId;

  final String _deviceId;
  final void Function(String vaultId)? onMigrationNeeded;

  /// Detecta el formato de la libreta actual.
  /// Retorna 0 (viejo) o 1 (nuevo).
  Future<int> detectFormat() async {
    try {
      final formatVersion =
          await VaultMigrationTool.readTreeFormatVersion();
      return formatVersion;
    } catch (_) {
      return 0; // Default: formato viejo
    }
  }

  /// Carga el payload según el formato.
  /// v0: carga desde vault.bin (como siempre)
  /// v1: carga desde árbol en <vault>/repo/
  Future<VaultPayload?> loadPayload(int formatVersion) async {
    if (formatVersion == 0) {
      // Formato viejo: cargar payload monolítico
      // (En vault_session, esto es _loadVaultPayload())
      return null; // Handled by existing code
    } else {
      // Formato nuevo: cargar desde árbol
      return VaultLocalStorage.loadFromTree();
    }
  }

  /// Crea snapshot o revisión según el formato.
  /// v0: agrega a _pageRevisions en memoria
  /// v1: crea snapshot en disco
  Future<void> captureRevisionIfChanged(
    int formatVersion,
    VaultPayload payload, {
    void Function()? onRevisionV0,
  }) async {
    if (formatVersion == 0) {
      // Formato viejo: usar callback para capturar en memoria
      onRevisionV0?.call();
    } else {
      // Formato nuevo: crear snapshot del árbol completo
      try {
        await VaultLocalStorage.saveSnapshot(
          deviceId: _deviceId,
        );
      } catch (e) {
        // Log pero no falla persistence
        print('Failed to create snapshot: $e');
      }
    }
  }

  /// Persiste el payload según el formato.
  /// v0: serializa a vault.bin (como siempre)
  /// v1: serializa a árbol en <vault>/repo/
  Future<void> persistPayload(
    int formatVersion,
    VaultPayload payload, {
    Future<void> Function()? persistV0,
  }) async {
    if (formatVersion == 0) {
      // Formato viejo: usar callback para persistir como siempre
      if (persistV0 != null) {
        await persistV0();
      }
    } else {
      // Formato nuevo: descomponer a árbol
      await VaultLocalStorage.decomposeAndStore(
        payload,
        deviceId: _deviceId,
      );
    }
  }

  /// Obtiene versiones (revisiones o snapshots) para historial.
  /// Retorna VersionInfo abstracto que funciona en ambos formatos.
  Future<List<VersionInfo>> getVersions(
    int formatVersion, {
    List<VersionInfo> Function()? versionsV0,
  }) async {
    if (formatVersion == 0) {
      // Formato viejo: usar callback para obtener de _pageRevisions
      return versionsV0?.call() ?? [];
    } else {
      // Formato nuevo: obtener snapshots
      final snapshots = await VaultLocalStorage.listSnapshots();
      return snapshots
          .map((s) => VersionInfo(
                versionId: s.snapshotId,
                timestamp: s.createdAtMs,
                label: s.displayLabel,
                source: 'snapshot',
                deviceId: s.deviceId,
              ))
          .toList();
    }
  }

  /// Restaura una versión según el formato.
  /// v0: restaura desde pageRevisions en memoria
  /// v1: restaura desde snapshot en disco
  Future<bool> restoreVersion(
    int formatVersion,
    String versionId, {
    Future<bool> Function(String)? restoreV0,
  }) async {
    if (formatVersion == 0) {
      // Formato viejo: usar callback
      return await restoreV0?.call(versionId) ?? false;
    } else {
      // Formato nuevo: restaurar desde snapshot
      // (Placeholder: implementación completa en M2+ con descompresión)
      // Por ahora, retorna false (no soportado en M5 alfa)
      return false;
    }
  }

  /// Intenta migración automática si es necesario.
  /// Retorna true si migró, false si ya era v1 o falla.
  Future<bool> autoMigrateIfNeeded(
    int currentFormat,
    VaultPayload payload,
  ) async {
    if (currentFormat == 1) {
      return false; // Ya migrado
    }

    try {
      // Solicitar confirmación/permiso
      onMigrationNeeded?.call('unknown-vault');

      // Ejecutar migración
      final result = await VaultMigrationTool.migrateVault(
        payload: payload,
        deviceId: _deviceId,
      );

      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene estadísticas de formato para debugging.
  Future<Map<String, dynamic>> formatStats(int formatVersion) async {
    if (formatVersion == 0) {
      return {'format': 'v0-monolithic', 'status': 'legacy'};
    } else {
      try {
        final treeDir = await VaultPaths.vaultTreeDirectory();
        final treeJsonFile = File(p.join(treeDir.path, 'tree.json'));
        final versionsDir = await VaultPaths.vaultVersionsDirectory();

        final snapshots = await VaultLocalStorage.listSnapshots();

        return {
          'format': 'v1-tree',
          'status': 'modern',
          'tree_exists': treeJsonFile.existsSync(),
          'snapshots': snapshots.length,
          'latest_snapshot': snapshots.isNotEmpty ? snapshots[0].displayLabel : 'none',
        };
      } catch (e) {
        return {'format': 'v1-tree', 'error': e.toString()};
      }
    }
  }
}
