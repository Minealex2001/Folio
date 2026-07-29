import 'dart:io';
import 'dart:typed_data';

import 'folio_spring_storage.dart';

/// Sube bytes al proxy Spring `/api/v1/storage/objects`.
Future<void> folioStoragePutData(String path, Uint8List data) async {
  await folioSpringStoragePutData(path, data);
}

/// Sube un archivo local. Devuelve el tamaño en bytes del archivo subido.
Future<int> folioStoragePutFile(String path, File file) async {
  final bytes = await file.readAsBytes();
  await folioSpringStoragePutData(path, bytes);
  return bytes.length;
}

/// Descarga bytes vía proxy Spring.
Future<Uint8List?> folioStorageGetData(String path, int maxBytes) async {
  return folioSpringStorageGetData(path, maxBytes);
}

/// true si el objeto existe (HEAD). false si 404 u otro fallo suave.
Future<bool> folioStorageObjectExists(String path) async {
  try {
    return await folioSpringStorageObjectExists(path);
  } catch (_) {
    return false;
  }
}

/// Descarga a archivo local.
Future<void> folioStorageWriteToFile(String path, File destination) async {
  final data = await folioSpringStorageGetData(path, 80 * 1024 * 1024);
  if (data == null) {
    throw FolioSpringStorageException(404, 'Object not found');
  }
  await destination.writeAsBytes(data, flush: true);
}

/// Borra un objeto (best-effort; 404 = ok).
Future<void> folioStorageDelete(String path) async {
  await folioSpringStorageDelete(path);
}
