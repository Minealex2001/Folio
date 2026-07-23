/// Handler dual v0/v1 para VaultSession (M5).
///
/// Abstracción que permite a vault_session.dart detectar y cargar la
/// libreta activa sin importar si sigue en el formato viejo (monolítico)
/// o ya está en el nuevo (árbol de archivos). La migración, persistencia
/// y restauración de versiones se implementan directamente en
/// vault_session.dart (bootstrap, _ensureV1AndLoad, persistNow,
/// versionsForPage, restoreVersion), no aquí.

import '../data/vault_payload.dart';
import '../data/vault_paths.dart';
import '../data/vault_local_storage.dart';
import 'vault_migration_tool.dart';

/// Handler que abstrae la diferencia entre formatos v0 y v1.
class VaultFormatHandler {
  VaultFormatHandler({
    required String deviceId,
    this.onMigrationNeeded,
  }) : _deviceId = deviceId;

  // ignore: unused_field
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
  /// v0: retorna null (el llamador usa la carga monolítica existente)
  /// v1: carga desde árbol en <vault>/repo/
  Future<VaultPayload?> loadPayload(int formatVersion) async {
    if (formatVersion == 0) {
      return null;
    }
    return VaultLocalStorage.loadFromTree();
  }

  /// Obtiene estadísticas de formato para debugging.
  Future<Map<String, dynamic>> formatStats(int formatVersion) async {
    if (formatVersion == 0) {
      return {'format': 'v0-monolithic', 'status': 'legacy'};
    } else {
      try {
        final versionsDir = await VaultPaths.vaultVersionsDirectory();
        final snapshots = await VaultLocalStorage.listSnapshots();

        return {
          'format': 'v1-tree',
          'status': 'modern',
          'versions_dir_exists': versionsDir.existsSync(),
          'snapshots': snapshots.length,
          'latest_snapshot':
              snapshots.isNotEmpty ? snapshots[0].displayLabel : 'none',
        };
      } catch (e) {
        return {'format': 'v1-tree', 'error': e.toString()};
      }
    }
  }
}
