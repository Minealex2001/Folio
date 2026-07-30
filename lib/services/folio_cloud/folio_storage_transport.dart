import 'dart:io';
import 'dart:typed_data';

import 'folio_spring_storage.dart';

/// Tope por objeto en el proxy Spring (debe coincidir con el backend).
const int kFolioStorageMaxObjectBytes = 256 * 1024 * 1024;

/// Sube bytes al proxy Spring `/api/v1/storage/objects`.
Future<void> folioStoragePutData(String path, Uint8List data) async {
  if (data.length > kFolioStorageMaxObjectBytes) {
    throw FolioSpringStorageException(
      400,
      'Object too large (max ${kFolioStorageMaxObjectBytes ~/ (1024 * 1024)} MiB, got ${data.length})',
    );
  }
  await folioSpringStoragePutData(path, data);
}

/// Sube un archivo local. Devuelve el tamaño en bytes del archivo subido.
Future<int> folioStoragePutFile(String path, File file) async {
  final bytes = await file.readAsBytes();
  await folioStoragePutData(path, bytes);
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
  final data = await folioSpringStorageGetData(path, kFolioStorageMaxObjectBytes);
  if (data == null) {
    throw FolioSpringStorageException(404, 'Object not found');
  }
  await destination.writeAsBytes(data, flush: true);
}

/// Borra un objeto (best-effort; 404 = ok).
Future<void> folioStorageDelete(String path) async {
  await folioSpringStorageDelete(path);
}
