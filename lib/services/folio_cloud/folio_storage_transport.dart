import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../config/folio_backend_config.dart';
import 'folio_firebase_storage_rest.dart';
import 'folio_spring_storage.dart';

export 'folio_firebase_storage_rest.dart' show folioStorageUseRestTransport;

String _storageObjectPath(Reference ref) => ref.fullPath;

/// Sube bytes usando REST en escritorio, proxy Spring en modo Spring, o el plugin.
Future<void> folioStoragePutData(
  Reference ref,
  Uint8List data, {
  SettableMetadata? metadata,
}) async {
  if (FolioBackendConfig.useSpring) {
    await folioSpringStoragePutData(_storageObjectPath(ref), data);
    return;
  }
  if (folioStorageUseRestTransport) {
    await folioFirebaseStorageRestPutData(ref, data, metadata: metadata);
    return;
  }
  await ref.putData(data, metadata);
}

/// Sube un archivo local. Devuelve el tamaño en bytes del archivo subido.
Future<int> folioStoragePutFile(
  Reference ref,
  File file, {
  SettableMetadata? metadata,
}) async {
  if (FolioBackendConfig.useSpring) {
    final bytes = await file.readAsBytes();
    await folioSpringStoragePutData(_storageObjectPath(ref), bytes);
    return bytes.length;
  }
  if (folioStorageUseRestTransport) {
    await folioFirebaseStorageRestPutFile(ref, file, metadata: metadata);
    return await file.length();
  }
  final snap = await ref.putFile(file, metadata);
  return snap.totalBytes;
}

/// Descarga bytes; en escritorio / Spring evita el plugin nativo.
Future<Uint8List?> folioStorageGetData(Reference ref, int maxBytes) async {
  if (FolioBackendConfig.useSpring) {
    return folioSpringStorageGetData(_storageObjectPath(ref), maxBytes);
  }
  if (folioStorageUseRestTransport) {
    return folioFirebaseStorageRestGetData(ref, maxBytes);
  }
  return ref.getData(maxBytes);
}

/// true si el objeto existe (HEAD/metadata). false si 404 u otro fallo suave.
Future<bool> folioStorageObjectExists(Reference ref) async {
  if (FolioBackendConfig.useSpring) {
    return folioSpringStorageObjectExists(_storageObjectPath(ref));
  }
  if (folioStorageUseRestTransport) {
    return folioFirebaseStorageRestObjectExists(ref);
  }
  try {
    await ref.getMetadata();
    return true;
  } on FirebaseException catch (e) {
    if (e.code == 'object-not-found') return false;
    return false;
  } catch (_) {
    return false;
  }
}

/// Descarga a archivo local.
Future<void> folioStorageWriteToFile(Reference ref, File destination) async {
  if (FolioBackendConfig.useSpring) {
    final data = await folioSpringStorageGetData(
      _storageObjectPath(ref),
      80 * 1024 * 1024,
    );
    if (data == null) {
      throw FolioSpringStorageException(404, 'Object not found');
    }
    await destination.writeAsBytes(data, flush: true);
    return;
  }
  if (folioStorageUseRestTransport) {
    await folioFirebaseStorageRestWriteToFile(ref, destination);
    return;
  }
  await ref.writeToFile(destination);
}
