/// Gestor de almacenamiento local con el nuevo formato de árbol (M1).
///
/// Persiste de forma atómica vía `repo.tmp` → swap a `repo/`.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'vault_paths.dart';
import 'vault_payload.dart';
import '../git/vault_payload_converters.dart';
import '../git/vault_snapshot_manager.dart';
import '../services/app_logger.dart';

/// Se lanza si un persist intentaría sustituir un árbol con páginas por uno vacío.
class VaultEmptyOverwriteException implements Exception {
  VaultEmptyOverwriteException(this.message);
  final String message;
  @override
  String toString() => 'VaultEmptyOverwriteException: $message';
}

class VaultLocalStorage {
  VaultLocalStorage._();

  /// Cuentas aproximadas de páginas en `repo/pages` (meta.json).
  static int countPageDirs(Directory treeDir) {
    final pagesDir = Directory(p.join(treeDir.path, 'pages'));
    if (!pagesDir.existsSync()) return 0;
    var n = 0;
    for (final prefix in pagesDir.listSync()) {
      if (prefix is! Directory) continue;
      for (final pageDir in prefix.listSync()) {
        if (pageDir is! Directory) continue;
        if (File(p.join(pageDir.path, 'meta.json')).existsSync()) n++;
      }
    }
    return n;
  }

  /// Descompone un VaultPayload al árbol de archivos en <vault>/repo/.
  /// Usa staging `repo.tmp` y swap atómico para no dejar el árbol a medias.
  static Future<void> decomposeAndStore(VaultPayload payload) async {
    final vaultDir = await VaultPaths.vaultDirectory();
    await decomposeAndStoreAt(vaultDir, payload);
  }

  /// Igual que [decomposeAndStore] pero para un directorio de libreta concreto
  /// (p. ej. sync headless sin cambiar la libreta activa).
  ///
  /// Por defecto rechaza sustituir un árbol con páginas por un payload vacío
  /// (evita wipe por sync/persist corrupto). [allowEmptyOverwrite] solo para
  /// wipe explícito del usuario.
  static Future<void> decomposeAndStoreAt(
    Directory vaultDir,
    VaultPayload payload, {
    bool allowEmptyOverwrite = false,
  }) async {
    final treeDir = Directory(p.join(vaultDir.path, 'repo'));
    final existingPages = treeDir.existsSync() ? countPageDirs(treeDir) : 0;
    if (!allowEmptyOverwrite &&
        existingPages > 0 &&
        payload.pages.isEmpty) {
      AppLogger.error(
        'Blocked empty overwrite of vault tree',
        tag: 'vault',
        context: {
          'vaultDir': vaultDir.path,
          'existingPages': existingPages,
          'incomingPages': 0,
        },
      );
      throw VaultEmptyOverwriteException(
        'Refusing to replace repo/ with $existingPages pages by empty payload',
      );
    }

    final tmpDir = Directory(p.join(vaultDir.path, 'repo.tmp'));

    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
    await tmpDir.create(recursive: true);
    await VaultPayloadToTree.decompose(payload, tmpDir);

    final oldDir = Directory(p.join(vaultDir.path, 'repo.old'));
    if (oldDir.existsSync()) {
      await oldDir.delete(recursive: true);
    }
    if (treeDir.existsSync()) {
      await treeDir.rename(oldDir.path);
    }
    await tmpDir.rename(treeDir.path);
    if (oldDir.existsSync()) {
      await oldDir.delete(recursive: true);
    }
  }

  /// Carga el árbol de archivos desde <vault>/repo/ y lo recompone en VaultPayload.
  /// Si el árbol no existe o está incompleto (falta tree.json), retorna null.
  static Future<VaultPayload?> loadFromTree() async {
    final treeDir = await VaultPaths.vaultTreeDirectory();
    return loadFromTreeDir(treeDir);
  }

  /// Carga desde `<vaultDir>/repo/` (sync headless / vaultId arbitrario).
  static Future<VaultPayload?> loadFromTreeAt(Directory vaultDir) async {
    final treeDir = Directory(p.join(vaultDir.path, 'repo'));
    return loadFromTreeDir(treeDir);
  }

  static Future<VaultPayload?> loadFromTreeDir(Directory treeDir) async {
    final treeJsonFile = File(p.join(treeDir.path, 'tree.json'));
    if (!treeJsonFile.existsSync()) {
      return null;
    }
    return TreeToVaultPayload.compose(treeDir);
  }

  /// Guarda un snapshot del estado actual del árbol.
  static Future<void> saveSnapshot({
    String? label,
    String? deviceId,
    String? parentSnapshotId,
  }) async {
    deviceId ??= 'unknown-device';

    final vaultDir = await VaultPaths.vaultDirectory();
    final treeDir = await VaultPaths.vaultTreeDirectory();

    if (!treeDir.existsSync()) {
      throw StateError(
        'Árbol no descompuesto; ejecuta decomposeAndStore primero',
      );
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
      deviceId: 'unknown-device',
    );

    final snapshots = await manager.listSnapshots();
    return snapshots
        .map(
          (s) => SnapshotInfo(
            snapshotId: s.snapshotId,
            createdAtMs: s.createdAtMs,
            label: s.label,
            deviceId: s.deviceId,
          ),
        )
        .toList();
  }

  static Future<bool> restoreSnapshot(String snapshotId) async {
    return false;
  }
}

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
      label ??
      'Snapshot at ${DateTime.fromMillisecondsSinceEpoch(createdAtMs)}';
}
