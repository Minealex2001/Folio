/// Gestor de almacenamiento local con el nuevo formato de árbol (M1).
///
/// Persiste de forma atómica vía `repo.tmp` → swap a `repo/`.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'vault_paths.dart';
import 'vault_payload.dart';
import '../core/errors/vault_corruption_exception.dart';
import '../git/vault_payload_converters.dart';
import '../git/vault_snapshot_manager.dart';
import '../models/folio_page.dart';
import '../models/local_collab.dart';
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

  /// Serializa lecturas/escrituras del árbol por libreta (clave = ruta del
  /// directorio de la libreta). Sin esto, la sesión activa (autosave/pull)
  /// y el sync headless de la misma libreta pueden tocar `repo/`/`repo.tmp`
  /// a la vez — un `loadFromTreeAt` puede leer el árbol a medio mover (0
  /// páginas) justo cuando otro `decomposeAndStoreAt` está en el rename, y
  /// dos escrituras concurrentes pueden pisarse el `repo.tmp` la una a la
  /// otra. Cada vault tiene su propia cola; libretas distintas no se
  /// bloquean entre sí.
  static final Map<String, Future<void>> _vaultLocks = {};

  /// Serializa cualquier operación sobre el árbol de una libreta (clave =
  /// ruta de su directorio) frente a las demás operaciones de
  /// `VaultLocalStorage` para esa MISMA libreta. Público para que otros
  /// módulos que también tocan `repo/`/`vault.bin` de una libreta (import de
  /// backups, migración v0→v1, el formato v0 legado) se unan al mismo
  /// candado — si no, quedan invisibles a esta protección.
  static Future<T> runExclusive<T>(
    String vaultDirPath,
    Future<T> Function() action,
  ) async {
    final previous = _vaultLocks[vaultDirPath];
    final completer = Completer<void>();
    _vaultLocks[vaultDirPath] = completer.future;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // El error pertenece a esa operación; aquí solo esperamos turno.
      }
    }
    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_vaultLocks[vaultDirPath], completer.future)) {
        _vaultLocks.remove(vaultDirPath);
      }
    }
  }

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

  /// Umbral bajo el cual un payload entrante se considera "sospechosamente
  /// parcial" frente al árbol ya en disco, en vez de un borrado real: por
  /// debajo del 40% de las páginas existentes, con un mínimo de 4 páginas
  /// existentes (evita falsos positivos en libretas pequeñas). Réplica local
  /// del mismo criterio que `VaultSyncMergeEngine.looksSuspiciouslyPartial`
  /// — no se importa ese servicio aquí a propósito, para no crear una
  /// dependencia data -> services por un simple chequeo de conteos.
  static bool looksLikePartialOverwrite({
    required int existingPages,
    required int incomingPages,
  }) {
    if (existingPages < 4) return false;
    if (incomingPages == 0) return false; // cubierto por el guard de vaciado total
    return incomingPages <= (existingPages * 0.4).ceil();
  }

  /// Igual que [decomposeAndStore] pero para un directorio de libreta concreto
  /// (p. ej. sync headless sin cambiar la libreta activa).
  ///
  /// Por defecto rechaza sustituir un árbol con páginas por un payload vacío
  /// (evita wipe por sync/persist corrupto). [allowEmptyOverwrite] solo para
  /// wipe explícito del usuario. [guardAgainstPartialOverwrite] añade además
  /// el rechazo de un payload que no está vacío pero sí muy por debajo de lo
  /// que ya hay en disco (manifiesto de sync parcial) — solo lo activan los
  /// llamadores que escriben contenido remoto, no el guardado local del
  /// usuario (que puede borrar páginas legítimamente en bloque).
  static Future<void> decomposeAndStoreAt(
    Directory vaultDir,
    VaultPayload payload, {
    bool allowEmptyOverwrite = false,
    bool guardAgainstPartialOverwrite = false,
  }) {
    return runExclusive(vaultDir.path, () async {
      final treeDir = Directory(p.join(vaultDir.path, 'repo'));
      final existingPages = treeDir.existsSync() ? countPageDirs(treeDir) : 0;
      final incomingPages = payload.pages.length;
      if (!allowEmptyOverwrite &&
          existingPages > 0 &&
          incomingPages == 0) {
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
      if (guardAgainstPartialOverwrite &&
          looksLikePartialOverwrite(
            existingPages: existingPages,
            incomingPages: incomingPages,
          )) {
        AppLogger.error(
          'Blocked partial overwrite of vault tree',
          tag: 'vault',
          context: {
            'vaultDir': vaultDir.path,
            'existingPages': existingPages,
            'incomingPages': incomingPages,
          },
        );
        throw VaultEmptyOverwriteException(
          'Refusing to replace repo/ ($existingPages pages) with a '
          'suspiciously small payload ($incomingPages pages) — looks like a '
          'partial sync manifest, not a real delete',
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
    });
  }

  /// Lee una sola página (y sus comentarios) de `<vaultDir>/repo/pages/...`
  /// sin recomponer la libreta entera — para aplicar un pull/merge
  /// incremental que solo tocó unas pocas páginas.
  static Future<FolioPage?> loadPageFromTreeAt(
    Directory vaultDir,
    String pageId,
  ) async {
    final treeDir = Directory(p.join(vaultDir.path, 'repo'));
    return runExclusive(vaultDir.path, () {
      return TreeToVaultPayload.composePage(treeDir, pageId);
    });
  }

  static Future<List<LocalPageComment>> loadPageCommentsFromTreeAt(
    Directory vaultDir,
    String pageId,
  ) async {
    final treeDir = Directory(p.join(vaultDir.path, 'repo'));
    return runExclusive(vaultDir.path, () {
      return TreeToVaultPayload.composePageComments(treeDir, pageId);
    });
  }

  /// Escribe atómicamente solo la carpeta de una página en
  /// `<vaultDir>/repo/pages/...`, sin tocar el resto del árbol — la
  /// contraparte de escritura de [loadPageFromTreeAt]. Requiere que `repo/`
  /// ya exista (creado por un `decomposeAndStoreAt` previo).
  static Future<void> storePageAt(
    Directory vaultDir,
    FolioPage page,
    List<LocalPageComment> allComments,
  ) async {
    final treeDir = Directory(p.join(vaultDir.path, 'repo'));
    return runExclusive(vaultDir.path, () async {
      if (!treeDir.existsSync()) {
        throw StateError(
          'Árbol no descompuesto; ejecuta decomposeAndStoreAt primero',
        );
      }
      await VaultPayloadToTree.decomposePage(treeDir, page, allComments);
    });
  }

  /// Carga el árbol de archivos desde <vault>/repo/ y lo recompone en VaultPayload.
  /// Si el árbol no existe o está incompleto (falta tree.json), retorna null.
  static Future<VaultPayload?> loadFromTree() async {
    final treeDir = await VaultPaths.vaultTreeDirectory();
    final vaultDir = await VaultPaths.vaultDirectory();
    return _loadFromTreeDirChecked(treeDir, vaultDir);
  }

  /// Carga desde `<vaultDir>/repo/` (sync headless / vaultId arbitrario).
  static Future<VaultPayload?> loadFromTreeAt(Directory vaultDir) async {
    final treeDir = Directory(p.join(vaultDir.path, 'repo'));
    return _loadFromTreeDirChecked(treeDir, vaultDir);
  }

  static Future<VaultPayload?> loadFromTreeDir(Directory treeDir) async {
    final treeJsonFile = File(p.join(treeDir.path, 'tree.json'));
    if (!treeJsonFile.existsSync()) {
      return null;
    }
    return TreeToVaultPayload.compose(treeDir);
  }

  /// Segunda barrera de lectura: si el árbol carga 0 páginas pero el último
  /// snapshot conocido (`versions/`) tenía páginas, no lo aceptamos como
  /// "libreta vacía" legítima — la app no tiene ningún flujo que lleve una
  /// libreta con contenido a 0 páginas (el guard de trash bloquea vaciar
  /// hasta 0 páginas activas, y no existe un "vaciar libreta" explícito que
  /// llame a `decomposeAndStoreAt(allowEmptyOverwrite: true)`). Esto cubre el
  /// caso en que la escritura sí pasó los guards (p. ej. herramienta externa,
  /// recuperación manual incompleta) pero el resultado en disco no es de
  /// fiar. Una libreta genuinamente nueva sin snapshots todavía no dispara
  /// esto (no hay snapshot previo con el que comparar).
  static Future<VaultPayload?> _loadFromTreeDirChecked(
    Directory treeDir,
    Directory vaultDir,
  ) {
    return runExclusive(vaultDir.path, () async {
      final payload = await loadFromTreeDir(treeDir);
      if (payload == null || payload.pages.isNotEmpty) return payload;
      if (await _latestSnapshotHadPages(vaultDir)) {
        AppLogger.error(
          'Refusing empty tree load: latest known snapshot had pages',
          tag: 'vault',
          context: {'vaultDir': vaultDir.path},
        );
        throw VaultCorruptionException(
          'El árbol describe 0 páginas pero el último snapshot conocido '
          'tenía contenido; no se acepta como libreta vacía legítima.',
        );
      }
      return payload;
    });
  }

  static Future<bool> _latestSnapshotHadPages(Directory vaultDir) async {
    try {
      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'read-check',
      );
      final snapshots = await manager.listSnapshots();
      if (snapshots.isEmpty) return false;
      return snapshots.first.fileManifest.any((entry) {
        final path = entry.path.replaceAll('\\', '/');
        return path.startsWith('pages/') && path.endsWith('meta.json');
      });
    } catch (_) {
      // Fail-closed: si no podemos verificar el histórico de snapshots (p.
      // ej. un error de E/S transitorio en `versions/`), no asumamos que la
      // libreta vacía es legítima — mejor un falso positivo de corrupción
      // que aceptar un vaciado que no pudimos descartar. Una libreta
      // genuinamente nueva sin snapshots no llega aquí (sale antes por
      // `snapshots.isEmpty`).
      return true;
    }
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

    return runExclusive(vaultDir.path, () async {
      if (!treeDir.existsSync()) {
        throw StateError(
          'Árbol no descompuesto; ejecuta decomposeAndStore primero',
        );
      }

      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: deviceId!,
      );

      await manager.createSnapshot(
        treeDir: treeDir,
        label: label,
        parentSnapshotId: parentSnapshotId,
      );
    });
  }

  /// Obtiene lista de snapshots para el historial de versiones.
  static Future<List<SnapshotInfo>> listSnapshots() async {
    final vaultDir = await VaultPaths.vaultDirectory();
    return runExclusive(vaultDir.path, () async {
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
    });
  }

  // TODO: cuando se implemente de verdad, debe unirse al mismo
  // runExclusive(vaultDir.path, ...) que el resto de operaciones sobre el
  // árbol de esta libreta.
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
