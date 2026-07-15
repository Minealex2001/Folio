import 'dart:typed_data';

import 'vault_pack_meta.dart';

/// Transporte abstracto para pack incremental (carpeta/UNC o WebDAV).
abstract class VaultPackTransport {
  /// Etiqueta legible (ruta o URL).
  String get label;

  Future<VaultPackMeta?> readMeta();

  Future<void> writeMeta(VaultPackMeta meta);

  Future<bool> blobExists(String blobId);

  Future<void> putBlob(String blobId, Uint8List bytes);

  Future<Uint8List?> getBlob(String blobId);

  Future<void> deleteBlob(String blobId);

  Future<void> putSnapshot(String relativePath, Uint8List bytes);

  Future<Uint8List?> getSnapshot(String relativePath);

  Future<void> deleteSnapshot(String relativePath);

  Future<void> putRestoreWrap(Uint8List bytes);

  Future<Uint8List?> getRestoreWrap();

  /// Lista rutas relativas de snapshots (`snapshots/snap-….bin`).
  Future<List<String>> listSnapshotPaths();

  /// Lista blobIds presentes en `blobs/`.
  Future<List<String>> listBlobIds();
}
