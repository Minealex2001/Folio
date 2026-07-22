/// Gestor de almacenamiento local con el nuevo formato de árbol (M1).
///
/// Responsabilidades:
/// - Descomponer VaultPayload en árbol bajo <vault>/repo/
/// - Cargar árbol y recomponerlo en VaultPayload
/// - Crear/gestionar snapshots bajo <vault>/versions/
///
/// En M1, esto funciona SIN sync multi-dispositivo.
/// M2+ agregará coordinación y migración.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'vault_paths.dart';
import 'vault_payload.dart';
import '../git/vault_payload_converters.dart';
import '../git/vault_snapshot_manager.dart';

class VaultLocalStorage {
  VaultLocalStorage._();

  /// Descompone un VaultPayload al árbol de archivos en <vault>/repo/.
  /// Crea snapshots iniciales si no existen.
  static Future<void> decomposeAndStore(
    VaultPayload payload, {
    String? deviceId,
  }) async {
    final treeDir = await VaultPaths.vaultTreeDirectory();

    // Descomponer payload al árbol
    await VaultPayloadToTree.decompose(payload, treeDir);

    // Crear snapshot inicial si [deviceId] se proporciona
    if (deviceId != null && deviceId.isNotEmpty) {
      final vaultDir = await VaultPaths.vaultDirectory();
      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: deviceId,
      );
      await manager.createSnapshot(
        treeDir: treeDir,
        label: 'Initial snapshot from payload',
      );
    }
  }

  /// Carga el árbol de archivos desde <vault>/repo/ y lo recompone en VaultPayload.
  /// Si el árbol no existe, retorna null.
  static Future<VaultPayload?> loadFromTree() async {
    final treeDir = await VaultPaths.vaultTreeDirectory();

    if (!treeDir.existsSync()) {
      return null;
    }

    return TreeToVaultPayload.compose(treeDir);
  }

  /// Guarda un snapshot del estado actual del árbol.
  /// Requiere que el árbol esté ya descompuesto en <vault>/repo/.
  static Future<void> saveSnapshot({
    String? label,
    String? deviceId,
    String? parentSnapshotId,
  }) async {
    deviceId ??= 'unknown-device';

    final vaultDir = await VaultPaths.vaultDirectory();
    final treeDir = await VaultPaths.vaultTreeDirectory();

    if (!treeDir.existsSync()) {
      throw StateError('Árbol no descompuesto; ejecuta decomposeAndStore primero');
    }

    final manager = VaultSnapshotManager(
      vaultDir: vaultDir,
      deviceId: deviceId,
    );

    await manager.createSnapshot(
      treeDir: treeDir,
      label: label,
      parentSnapshotId: parentSnapshotId,
    );
  }

  /// Obtiene lista de snapshots para el historial de versiones.
  static Future<List<SnapshotInfo>> listSnapshots() async {
    final vaultDir = await VaultPaths.vaultDirectory();
    final manager = VaultSnapshotManager(
      vaultDir: vaultDir,
      deviceId: 'unknown-device', // no se usa en list
    );

    final snapshots = await manager.listSnapshots();
    return snapshots
        .map((s) => SnapshotInfo(
              snapshotId: s.snapshotId,
              createdAtMs: s.createdAtMs,
              label: s.label,
              deviceId: s.deviceId,
            ))
        .toList();
  }

  /// Restaura un snapshot anterior (implementado en M2+).
  static Future<bool> restoreSnapshot(String snapshotId) async {
    // TODO(M2): Implementar restauración desde snapshot comprimido
    return false;
  }
}

/// Información comprimida de un snapshot para mostrar en UI.
class SnapshotInfo {
  SnapshotInfo({
    required this.snapshotId,
    required this.createdAtMs,
    required this.label,
    required this.deviceId,
  });

  final String snapshotId;
  final int createdAtMs;
  final String? label;
  final String deviceId;

  String get displayLabel =>
      label ?? 'Snapshot at ${DateTime.fromMillisecondsSinceEpoch(createdAtMs)}';
}
