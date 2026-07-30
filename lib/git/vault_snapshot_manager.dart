/// Gestor de snapshots locales (M1).
///
/// Almacena/recupera snapshots del árbol de archivos bajo <vault>/versions/.
/// Reemplaza las revisiones de página almacenadas en memoria (pageRevisions).

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';

import 'vault_snapshot.dart';
import 'p2p_sync_packager.dart';
import 'vault_payload_converters.dart';
import '../data/vault_payload.dart';

/// Recorre [treeDirPath] y calcula SHA-256 de cada archivo. Top-level para
/// poder correr en un isolate (`compute`) — recorrer + hashear el árbol
/// entero es la operación de CPU más pesada del ciclo de sync y, sin
/// aislarla, bloquea el hilo de UI en cada snapshot (tras cada push/pull).
Future<List<Map<String, dynamic>>> _hashVaultTreeIsolate(
  String treeDirPath,
) async {
  final entries = <Map<String, dynamic>>[];
  final baseDir = Directory(treeDirPath);

  Future<void> walk(Directory currentDir) async {
    final items = currentDir.listSync();
    for (final item in items) {
      if (item is File) {
        final relativePath =
            p.relative(item.path, from: baseDir.path).replaceAll('\\', '/');
        final bytes = await item.readAsBytes();
        final digest = await Sha256().hash(bytes);
        final sha256Hex =
            digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        entries.add({
          'path': relativePath,
          'sha256': sha256Hex,
          'sizeBytes': bytes.length,
        });
      } else if (item is Directory) {
        await walk(item);
      }
    }
  }

  await walk(baseDir);
  return entries;
}

/// Comprime [args] = [treeDirPath, vaultId, deviceId] a ZIP. Top-level para
/// poder correr en isolate — la compresión de todo el árbol es el otro pico
/// de CPU del ciclo de snapshot.
Future<Uint8List> _compressTreeToZipIsolate(List<String> args) async {
  final treeDirPath = args[0];
  final vaultId = args[1];
  final deviceId = args[2];
  final packager = P2PSyncPackager(vaultId: vaultId, sourceDeviceId: deviceId);
  final zipBytes = await packager.compressTreeToZip(Directory(treeDirPath));
  return Uint8List.fromList(zipBytes);
}

class VaultSnapshotManager {
  final Directory vaultDir;
  final String deviceId;
  late final Directory _versionsDir;

  VaultSnapshotManager({
    required this.vaultDir,
    required this.deviceId,
  }) {
    _versionsDir = Directory(p.join(vaultDir.path, 'versions'));
  }

  /// Inicializa el directorio de versiones si no existe.
  Future<void> init() async {
    if (!_versionsDir.existsSync()) {
      await _versionsDir.create(recursive: true);
    }
  }

  /// Crea un snapshot del estado actual del árbol.
  /// Requiere que el árbol esté descompuesto en [treeDir].
  Future<VaultSnapshot> createSnapshot({
    required Directory treeDir,
    String? label,
    String? parentSnapshotId,
  }) async {
    await init();

    final snapshotId = const Uuid().v4();
    final createdAtMs = DateTime.now().millisecondsSinceEpoch;
    final manifest = await _buildFileManifest(treeDir);
    // Encadenar automáticamente al snapshot más reciente si el llamador no
    // especifica uno explícito, para que el historial sea navegable como un
    // log en vez de una bolsa plana ordenada solo por fecha.
    String? resolvedParentId = parentSnapshotId;
    if (resolvedParentId == null) {
      final priorSnapshots = await listSnapshots();
      resolvedParentId =
          priorSnapshots.isNotEmpty ? priorSnapshots.first.snapshotId : null;
    }

    final snapshot = VaultSnapshot(
      snapshotId: snapshotId,
      createdAtMs: createdAtMs,
      deviceId: deviceId,
      treeFormatVersion: 1,
      fileManifest: manifest,
      label: label,
      parentSnapshotId: resolvedParentId,
    );

    // Guardar metadatos del snapshot
    final metadataFile = File(p.join(_versionsDir.path, '$snapshotId.json'));
    await metadataFile.writeAsString(
      jsonEncode(snapshot.toJson()),
      flush: true,
    );

    // Guardar copia comprimida del árbol (para restore rápido)
    await _compressAndStoreTreeSnapshot(snapshotId, treeDir);

    return snapshot;
  }

  /// Obtiene la lista de snapshots más recientes primero.
  Future<List<VaultSnapshot>> listSnapshots() async {
    await init();

    final files = _versionsDir
        .listSync()
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final snapshots = <VaultSnapshot>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        snapshots.add(VaultSnapshot.fromJson(json));
      } catch (e) {
        // Log y continúa (snapshot corrupto)
        continue;
      }
    }

    // Ordenar por timestamp descendente (más recientes primero)
    snapshots.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return snapshots;
  }

  /// Obtiene un snapshot específico por ID.
  Future<VaultSnapshot?> getSnapshot(String snapshotId) async {
    await init();

    final file = File(p.join(_versionsDir.path, '$snapshotId.json'));
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return VaultSnapshot.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Extrae únicamente [relativePaths] (rutas dentro del árbol, p. ej.
  /// `pages/ab/abc123/meta.json`) desde el .zip de un snapshot, sin
  /// descomprimir el árbol completo. Usado para restaurar/comparar una sola
  /// página en vez de la libreta entera (estilo `git show <rev>:<path>`).
  Future<Map<String, List<int>>> extractFilesFromSnapshot(
    String snapshotId,
    Set<String> relativePaths,
  ) async {
    final zipFile = File(p.join(_versionsDir.path, '$snapshotId.zip'));
    if (!zipFile.existsSync()) return {};
    final zipBytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final result = <String, List<int>>{};
    for (final file in archive) {
      if (!file.isFile) continue;
      if (relativePaths.contains(file.name)) {
        result[file.name] = file.content as List<int>;
      }
    }
    return result;
  }

  /// Restaura un snapshot anterior a [targetTreeDir].
  /// Descomprime el .zip del snapshot a una carpeta de staging y solo
  /// reemplaza [targetTreeDir] mediante un swap atómico (rename) una vez que
  /// la copia completa tuvo éxito — si la copia falla a mitad (disco lleno,
  /// permiso denegado), [targetTreeDir] queda intacto en vez de a medias.
  Future<bool> restoreSnapshot(
    String snapshotId,
    Directory targetTreeDir,
  ) async {
    await init();

    final zipFile = File(p.join(_versionsDir.path, '$snapshotId.zip'));
    if (!zipFile.existsSync()) return false;

    Directory? extractedDir;
    Directory? stagingDir;
    final stagingPath = p.join(
      targetTreeDir.parent.path,
      '${p.basename(targetTreeDir.path)}.restore-tmp',
    );
    final oldPath = p.join(
      targetTreeDir.parent.path,
      '${p.basename(targetTreeDir.path)}.restore-old',
    );
    try {
      final zipBytes = await zipFile.readAsBytes();
      final packager = P2PSyncPackager(
        vaultId: p.basename(vaultDir.path),
        sourceDeviceId: deviceId,
      );
      extractedDir = await packager.decompressZip(
        zipBytes,
        'folio_snapshot_restore_',
      );

      // Copiar a staging en el mismo volumen que targetTreeDir (no el temp
      // del sistema, que puede estar en otra unidad) para que el swap final
      // por rename funcione y no toque targetTreeDir hasta tener éxito.
      stagingDir = Directory(stagingPath);
      if (stagingDir.existsSync()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);
      await for (final entity in extractedDir.list(recursive: true)) {
        final relativePath = p.relative(entity.path, from: extractedDir.path);
        final destPath = p.join(stagingDir.path, relativePath);
        if (entity is Directory) {
          await Directory(destPath).create(recursive: true);
        } else if (entity is File) {
          await Directory(p.dirname(destPath)).create(recursive: true);
          await entity.copy(destPath);
        }
      }

      final oldDir = Directory(oldPath);
      if (oldDir.existsSync()) {
        await oldDir.delete(recursive: true);
      }
      if (targetTreeDir.existsSync()) {
        await targetTreeDir.rename(oldDir.path);
      }
      await stagingDir.rename(targetTreeDir.path);
      stagingDir = null;
      if (oldDir.existsSync()) {
        await oldDir.delete(recursive: true);
      }
      return true;
    } catch (_) {
      // La copia a staging falló a mitad: targetTreeDir no se tocó todavía.
      if (stagingDir != null && stagingDir.existsSync()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (_) {}
      }
      return false;
    } finally {
      if (extractedDir != null && extractedDir.existsSync()) {
        try {
          await extractedDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Reconstruye el VaultPayload íntegro de un snapshot, restaurándolo a un
  /// directorio temporal (sin tocar el árbol en vivo `treeDir`) y
  /// decodificándolo desde ahí. Usado por el sync para recuperar el baseline
  /// persistido (el "ancestro común" de la última sync exitosa).
  Future<VaultPayload?> loadPayload(String snapshotId) async {
    final tmpPath = p.join(vaultDir.path, 'baseline.tmp-$snapshotId');
    final tmpDir = Directory(tmpPath);
    final leftoverOld = Directory('$tmpPath.restore-old');
    final leftoverStaging = Directory('$tmpPath.restore-tmp');
    try {
      final ok = await restoreSnapshot(snapshotId, tmpDir);
      if (!ok) return null;
      final treeJsonFile = File(p.join(tmpDir.path, 'tree.json'));
      if (!treeJsonFile.existsSync()) return null;
      return await TreeToVaultPayload.compose(tmpDir);
    } finally {
      for (final d in [tmpDir, leftoverOld, leftoverStaging]) {
        if (d.existsSync()) {
          try {
            await d.delete(recursive: true);
          } catch (_) {}
        }
      }
    }
  }

  /// Elimina un snapshot (metadatos + archivo comprimido).
  Future<void> deleteSnapshot(String snapshotId) async {
    await init();

    final metadataFile = File(p.join(_versionsDir.path, '$snapshotId.json'));
    final treeFile = File(p.join(_versionsDir.path, '$snapshotId.zip'));

    if (metadataFile.existsSync()) await metadataFile.delete();
    if (treeFile.existsSync()) await treeFile.delete();
  }

  /// True si el árbol actual coincide (path→sha256) con el snapshot más reciente.
  Future<bool> isTreeIdenticalToLatest(Directory treeDir) async {
    final snapshots = await listSnapshots();
    if (snapshots.isEmpty) return false;
    final latest = snapshots.first;
    final current = await _buildFileManifest(treeDir);
    if (current.length != latest.fileManifest.length) return false;
    final latestByPath = {
      for (final e in latest.fileManifest) e.path: e.sha256,
    };
    for (final e in current) {
      if (latestByPath[e.path] != e.sha256) return false;
    }
    return true;
  }

  /// Compara el árbol actual contra el manifiesto de [baseline] (no
  /// necesariamente el más reciente — el baseline de sync persistido) y
  /// devuelve qué páginas cambiaron (por id) desde entonces, más si algo
  /// fuera de `pages/` (metadatos de libreta, ACL, integraciones, orden de
  /// páginas) también cambió. No descarga ni sube nada — solo hashes locales.
  Future<ChangedPagesSinceBaseline> changedPageIds(
    Directory treeDir,
    VaultSnapshot baseline,
  ) async {
    final baselineByPath = {
      for (final e in baseline.fileManifest) e.path: e.sha256,
    };
    final current = await _buildFileManifest(treeDir);
    final currentByPath = {for (final e in current) e.path: e.sha256};

    String? pageIdOf(String path) {
      final parts = path.split('/');
      // pages/<prefix>/<pageId>/<file>
      if (parts.length >= 4 && parts[0] == 'pages') return parts[2];
      return null;
    }

    final changedPages = <String>{};
    var restChanged = false;
    final allPaths = {...baselineByPath.keys, ...currentByPath.keys};
    for (final path in allPaths) {
      if (baselineByPath[path] == currentByPath[path]) continue;
      final pageId = pageIdOf(path);
      if (pageId != null) {
        changedPages.add(pageId);
      } else {
        restChanged = true;
      }
    }
    return ChangedPagesSinceBaseline(
      pageIds: changedPages,
      restChanged: restChanged,
    );
  }

  /// True si los [relativePaths] del árbol coinciden con el snapshot más reciente.
  Future<bool> arePathsIdenticalToLatest(
    Directory treeDir,
    Set<String> relativePaths,
  ) async {
    if (relativePaths.isEmpty) return true;
    final snapshots = await listSnapshots();
    if (snapshots.isEmpty) return false;
    final latest = snapshots.first;
    final latestByPath = {
      for (final e in latest.fileManifest) e.path: e.sha256,
    };
    for (final path in relativePaths) {
      final file = File(p.join(treeDir.path, path));
      if (!file.existsSync()) {
        if (latestByPath.containsKey(path)) return false;
        continue;
      }
      final bytes = await file.readAsBytes();
      final sha = await _computeSha256(bytes);
      if (latestByPath[path] != sha) return false;
    }
    return true;
  }

  /// Construye el manifest de archivos recursivamente desde [treeDir].
  /// Recorrido + hash corren en un isolate aparte (`compute`) — es la
  /// operación de CPU más cara del ciclo de sync y no debe bloquear la UI.
  Future<List<FileManifestEntry>> _buildFileManifest(Directory treeDir) async {
    final raw = await compute(_hashVaultTreeIsolate, treeDir.path);
    return raw.map(FileManifestEntry.fromJson).toList();
  }

  /// Computa el SHA-256 real de [bytes] (hex, 64 caracteres).
  Future<String> _computeSha256(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Comprime el árbol a ZIP y lo guarda en <versions>/<snapshotId>.zip.
  /// La compresión corre en isolate aparte (`compute`) por el mismo motivo
  /// que [_buildFileManifest]: es CPU-intensiva y no debe bloquear la UI.
  Future<void> _compressAndStoreTreeSnapshot(
    String snapshotId,
    Directory treeDir,
  ) async {
    final zipBytes = await compute(_compressTreeToZipIsolate, [
      treeDir.path,
      p.basename(vaultDir.path),
      deviceId,
    ]);
    final zipFile = File(p.join(_versionsDir.path, '$snapshotId.zip'));
    await zipFile.writeAsBytes(zipBytes, flush: true);
  }
}

/// Resultado de [VaultSnapshotManager.changedPageIds].
class ChangedPagesSinceBaseline {
  const ChangedPagesSinceBaseline({
    required this.pageIds,
    required this.restChanged,
  });

  final Set<String> pageIds;
  final bool restChanged;

  bool get isEmpty => pageIds.isEmpty && !restChanged;
}
