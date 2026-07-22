/// Constructor de cloud packs para sync en la nube (M3).
///
/// Responsabilidades:
/// - Leer árbol de archivos
/// - Calcular SHA-256 de cada archivo
/// - Crear manifest con información de deduplicación
/// - Preparar archivos cifrados para upload

import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:cryptography/cryptography.dart';

import 'cloud_pack.dart';

class CloudPackBuilder {
  CloudPackBuilder({
    required this.vaultId,
    required this.deviceId,
  });

  final String vaultId;
  final String deviceId;

  /// Construye un manifest desde un árbol de archivos.
  /// Para M3, incluye solo metadatos (SHA-256, sizes).
  /// Los bytes cifrados se agregan después en el upload.
  Future<CloudPackManifest> buildManifest({
    required Directory treeDir,
    String? snapshotId,
    String? parentSnapshotId,
  }) async {
    final files = <CloudPackFile>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Recorrer árbol y calcular hashes
    await _walkTreeAndHash(treeDir, treeDir, files);

    return CloudPackManifest(
      vaultId: vaultId,
      timestamp: timestamp,
      deviceId: deviceId,
      treeFormatVersion: 1,
      files: files,
      snapshotId: snapshotId,
      parentSnapshotId: parentSnapshotId,
    );
  }

  /// Calcula SHA-256 para un archivo específico.
  Future<String> calculateFileSha256(File file) async {
    final bytes = await file.readAsBytes();
    final algorithm = Sha256();
    final digest = await algorithm.hash(bytes);
    return digest.toString();
  }

  /// Recorre recursivamente el árbol y calcula hashes.
  Future<void> _walkTreeAndHash(
    Directory baseDir,
    Directory currentDir,
    List<CloudPackFile> files,
  ) async {
    final items = currentDir.listSync();

    for (final item in items) {
      if (item is File) {
        final relativePath =
            p.relative(item.path, from: baseDir.path).replaceAll('\\', '/');
        final bytes = await item.readAsBytes();
        final sha256 = await _hashBytes(bytes);

        files.add(CloudPackFile(
          path: relativePath,
          sha256: sha256,
          sizeBytes: bytes.length,
          contentEncrypted: null, // Se agregarán después
        ));
      } else if (item is Directory) {
        await _walkTreeAndHash(baseDir, item, files);
      }
    }
  }

  /// Calcula SHA-256 para bytes.
  Future<String> _hashBytes(List<int> bytes) async {
    final algorithm = Sha256();
    final digest = await algorithm.hash(bytes);
    return digest.toString();
  }
}

/// Comparador de manifests para detectar cambios.
class ManifestDiff {
  ManifestDiff({
    required this.newFiles,
    required this.modifiedFiles,
    required this.deletedFiles,
    required this.unchangedFiles,
  });

  /// Archivos nuevos (no en manifest anterior)
  final List<CloudPackFile> newFiles;

  /// Archivos modificados (SHA-256 cambió)
  final List<CloudPackFile> modifiedFiles;

  /// Archivos eliminados (en anterior pero no en nuevo)
  final List<CloudPackFile> deletedFiles;

  /// Archivos sin cambios (mismo SHA-256)
  final List<CloudPackFile> unchangedFiles;

  /// Total de archivos a subir (nuevos + modificados)
  int get toUpload => newFiles.length + modifiedFiles.length;

  /// Total de bytes a subir
  int get bytesToUpload =>
      newFiles.fold(0, (s, f) => s + f.sizeBytes) +
      modifiedFiles.fold(0, (s, f) => s + f.sizeBytes);
}

/// Compara dos manifests y detecta cambios.
ManifestDiff compareManifests(
  CloudPackManifest? oldManifest,
  CloudPackManifest newManifest,
) {
  if (oldManifest == null) {
    // Primer upload: todo es nuevo
    return ManifestDiff(
      newFiles: newManifest.files,
      modifiedFiles: [],
      deletedFiles: [],
      unchangedFiles: [],
    );
  }

  final oldByPath = {for (var f in oldManifest.files) f.path: f};
  final newByPath = {for (var f in newManifest.files) f.path: f};

  final newFiles = <CloudPackFile>[];
  final modifiedFiles = <CloudPackFile>[];
  final unchangedFiles = <CloudPackFile>[];

  // Detectar nuevos y modificados
  for (final file in newManifest.files) {
    final oldFile = oldByPath[file.path];
    if (oldFile == null) {
      newFiles.add(file);
    } else if (oldFile.sha256 != file.sha256) {
      modifiedFiles.add(file);
    } else {
      unchangedFiles.add(file);
    }
  }

  // Detectar eliminados
  final deletedFiles = <CloudPackFile>[];
  for (final oldFile in oldManifest.files) {
    if (!newByPath.containsKey(oldFile.path)) {
      deletedFiles.add(oldFile);
    }
  }

  return ManifestDiff(
    newFiles: newFiles,
    modifiedFiles: modifiedFiles,
    deletedFiles: deletedFiles,
    unchangedFiles: unchangedFiles,
  );
}
