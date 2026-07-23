/// Gestor de snapshots locales (M1).
///
/// Almacena/recupera snapshots del árbol de archivos bajo <vault>/versions/.
/// Reemplaza las revisiones de página almacenadas en memoria (pageRevisions).

import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';

import 'vault_snapshot.dart';
import 'p2p_sync_packager.dart';

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

    final snapshot = VaultSnapshot(
      snapshotId: snapshotId,
      createdAtMs: createdAtMs,
      deviceId: deviceId,
      treeFormatVersion: 1,
      fileManifest: manifest,
      label: label,
      parentSnapshotId: parentSnapshotId,
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
  /// Descomprime el .zip del snapshot y reemplaza el contenido de
  /// [targetTreeDir] con el árbol restaurado.
  Future<bool> restoreSnapshot(
    String snapshotId,
    Directory targetTreeDir,
  ) async {
    await init();

    final zipFile = File(p.join(_versionsDir.path, '$snapshotId.zip'));
    if (!zipFile.existsSync()) return false;

    try {
      final zipBytes = await zipFile.readAsBytes();
      final packager = P2PSyncPackager(
        vaultId: p.basename(vaultDir.path),
        sourceDeviceId: deviceId,
      );
      final extractedDir = await packager.decompressZip(
        zipBytes,
        'folio_snapshot_restore_',
      );

      try {
        if (targetTreeDir.existsSync()) {
          await targetTreeDir.delete(recursive: true);
        }
        await targetTreeDir.create(recursive: true);
        await for (final entity in extractedDir.list(recursive: true)) {
          final relativePath =
              p.relative(entity.path, from: extractedDir.path);
          final destPath = p.join(targetTreeDir.path, relativePath);
          if (entity is Directory) {
            await Directory(destPath).create(recursive: true);
          } else if (entity is File) {
            await Directory(p.dirname(destPath)).create(recursive: true);
            await entity.copy(destPath);
          }
        }
        return true;
      } finally {
        if (extractedDir.existsSync()) {
          await extractedDir.delete(recursive: true);
        }
      }
    } catch (_) {
      return false;
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
  Future<List<FileManifestEntry>> _buildFileManifest(Directory treeDir) async {
    final entries = <FileManifestEntry>[];

    await _walkTree(treeDir, treeDir, entries);

    return entries;
  }

  /// Recorre recursivamente el árbol y calcula SHA-256 para cada archivo.
  Future<void> _walkTree(
    Directory baseDir,
    Directory currentDir,
    List<FileManifestEntry> entries,
  ) async {
    final items = currentDir.listSync();

    for (final item in items) {
      if (item is File) {
        final relativePath =
            p.relative(item.path, from: baseDir.path).replaceAll('\\', '/');
        final bytes = await item.readAsBytes();
        final sha256 = await _computeSha256(bytes);

        entries.add(FileManifestEntry(
          path: relativePath,
          sha256: sha256,
          sizeBytes: bytes.length,
        ));
      } else if (item is Directory) {
        await _walkTree(baseDir, item, entries);
      }
    }
  }

  /// Computa el SHA-256 real de [bytes] (hex, 64 caracteres).
  Future<String> _computeSha256(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Comprime el árbol a ZIP y lo guarda en <versions>/<snapshotId>.zip.
  Future<void> _compressAndStoreTreeSnapshot(
    String snapshotId,
    Directory treeDir,
  ) async {
    final packager = P2PSyncPackager(
      vaultId: p.basename(vaultDir.path),
      sourceDeviceId: deviceId,
    );
    final zipBytes = await packager.compressTreeToZip(treeDir);
    final zipFile = File(p.join(_versionsDir.path, '$snapshotId.zip'));
    await zipFile.writeAsBytes(zipBytes, flush: true);
  }
}
