/// Gestor de snapshots locales (M1).
///
/// Almacena/recupera snapshots del árbol de archivos bajo <vault>/versions/.
/// Reemplaza las revisiones de página almacenadas en memoria (pageRevisions).

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'vault_snapshot.dart';
import 'vault_payload_converters.dart';
import '../data/vault_payload.dart';

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

  /// Restaura un snapshot anterior a un directorio de árbol.
  /// Esto extrae el snapshot comprimido y lo devuelve como árbol.
  Future<bool> restoreSnapshot(String snapshotId, Directory targetTreeDir) async {
    await init();

    // Por ahora, retorna false (implementación completa en M2+)
    // Placeholder para futuro: descomprimir y copiar el árbol.
    return false;
  }

  /// Elimina un snapshot (metadatos + archivo comprimido).
  Future<void> deleteSnapshot(String snapshotId) async {
    await init();

    final metadataFile = File(p.join(_versionsDir.path, '$snapshotId.json'));
    final treeFile = File(p.join(_versionsDir.path, '$snapshotId.zip'));

    if (metadataFile.existsSync()) await metadataFile.delete();
    if (treeFile.existsSync()) await treeFile.delete();
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
        final sha256 = _computeSha256(bytes);

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

  /// Placeholder: computa SHA-256 de bytes.
  /// (Usar cryptography package en impl final)
  String _computeSha256(List<int> bytes) {
    // TODO: implementar SHA-256 real usando cryptography package
    // Por ahora, retorna placeholder
    return 'sha256_placeholder_${bytes.length}';
  }

  /// Placeholder: comprime y almacena el árbol como ZIP.
  Future<void> _compressAndStoreTreeSnapshot(
    String snapshotId,
    Directory treeDir,
  ) async {
    // TODO: implementar compresión ZIP del árbol
    // Por ahora, es un no-op
  }
}
