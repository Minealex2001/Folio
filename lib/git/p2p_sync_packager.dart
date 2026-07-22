/// Empaquetador de sync P2P (M4).
///
/// Responsabilidades:
/// - Comprimir árbol de archivos en ZIP
/// - Crear header de pack
/// - Calcular estadísticas de compresión
/// - Encriptar pack completo (en sync controller)

import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'p2p_sync_pack.dart';

class P2PSyncPackager {
  P2PSyncPackager({
    required this.vaultId,
    required this.sourceDeviceId,
  });

  final String vaultId;
  final String sourceDeviceId;

  /// Crea un pack de sync P2P desde un árbol de archivos.
  Future<P2PSyncPackHeader> createPackHeader({
    required Directory treeDir,
    String? snapshotId,
    String? snapshotLabel,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Recorrer árbol y contar archivos + tamaño
    int fileCount = 0;
    int uncompressedSize = 0;

    await for (final entity in treeDir.list(recursive: true)) {
      if (entity is File) {
        fileCount++;
        uncompressedSize += await entity.length();
      }
    }

    // Calcular tamaño comprimido (estimación)
    // En la práctica, se calcularía después de comprimir
    final compressedSize = await _estimateCompressedSize(treeDir);

    return P2PSyncPackHeader(
      vaultId: vaultId,
      formatVersion: 1,
      timestamp: now,
      sourceDeviceId: sourceDeviceId,
      treeFormatVersion: 1,
      fileCount: fileCount,
      compressedSizeBytes: compressedSize,
      uncompressedSizeBytes: uncompressedSize,
      snapshotId: snapshotId,
      snapshotLabel: snapshotLabel,
    );
  }

  /// Comprime el árbol a ZIP y retorna los bytes.
  /// Para M4: ZIP sin cifrado (el cifrado ocurre en el transporte).
  Future<List<int>> compressTreeToZip(Directory treeDir) async {
    final archive = Archive();

    await _addFilesToArchive(treeDir, treeDir, archive);

    // Crear ZIP con compresión máxima
    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive) ?? [];
  }

  /// Descomprime ZIP a un directorio temporal.
  Future<Directory> decompressZip(
    List<int> zipBytes,
    String tempDirName,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(tempDirName);

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive) {
        final filePath = p.join(tempDir.path, file.name);
        final dir = Directory(p.dirname(filePath));

        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }

        if (!file.isFile) continue;

        final outputFile = File(filePath);
        await outputFile.writeAsBytes(file.content as List<int>);
      }

      return tempDir;
    } catch (e) {
      // Cleanup on error
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  /// Agrega archivos del árbol al archivo ZIP.
  Future<void> _addFilesToArchive(
    Directory baseDir,
    Directory currentDir,
    Archive archive,
  ) async {
    final items = currentDir.listSync();

    for (final item in items) {
      if (item is File) {
        final relativePath =
            p.relative(item.path, from: baseDir.path).replaceAll('\\', '/');
        final bytes = await item.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      } else if (item is Directory) {
        await _addFilesToArchive(baseDir, item, archive);
      }
    }
  }

  /// Estima el tamaño comprimido del árbol.
  /// (En la práctica, comprimir y medir es más preciso pero costoso).
  Future<int> _estimateCompressedSize(Directory treeDir) async {
    int totalSize = 0;

    await for (final entity in treeDir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    // Heurística: JSON/text comprime a ~30-40% del original
    // JSONL (bloques) comprime muy bien (~20%)
    // Asumimos ratio promedio de 0.35 (35% del original)
    return (totalSize * 0.35).toInt();
  }
}

/// Calcula estadísticas de un sync P2P.
P2PSyncStats calculateSyncStats({
  required int uncompressedBytes,
  required int compressedBytes,
  required int fileCount,
  required int durationMs,
}) {
  return P2PSyncStats(
    uncompressed: uncompressedBytes,
    compressed: compressedBytes,
    fileCount: fileCount,
    duration: durationMs,
  );
}
