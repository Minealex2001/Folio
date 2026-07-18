import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'folio_firebase_storage_rest.dart';

export 'folio_firebase_storage_rest.dart' show folioStorageUseRestTransport;

/// Sube bytes usando REST en escritorio o el plugin en el resto de plataformas.
Future<void> folioStoragePutData(
  Reference ref,
  Uint8List data, {
  SettableMetadata? metadata,
}) async {
  if (folioStorageUseRestTransport) {
    await folioFirebaseStorageRestPutData(ref, data, metadata: metadata);
    return;
  }
  await ref.putData(data, metadata);
}

/// Sube un archivo local usando REST resumible en escritorio.
/// Devuelve el tamaño en bytes del archivo subido.
Future<int> folioStoragePutFile(
  Reference ref,
  File file, {
  SettableMetadata? metadata,
}) async {
  if (folioStorageUseRestTransport) {
    await folioFirebaseStorageRestPutFile(ref, file, metadata: metadata);
    return await file.length();
  }
  final snap = await ref.putFile(file, metadata);
  return snap.totalBytes;
}

/// Descarga bytes; en escritorio evita tareas con `taskEvent`.
Future<Uint8List?> folioStorageGetData(Reference ref, int maxBytes) async {
  if (folioStorageUseRestTransport) {
    return folioFirebaseStorageRestGetData(ref, maxBytes);
  }
  return ref.getData(maxBytes);
}

/// true si el objeto existe (HEAD/metadata). false si 404 u otro fallo suave.
Future<bool> folioStorageObjectExists(Reference ref) async {
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

/// Descarga a archivo local sin `writeToFile` en escritorio.
Future<void> folioStorageWriteToFile(Reference ref, File destination) async {
  if (folioStorageUseRestTransport) {
    await folioFirebaseStorageRestWriteToFile(ref, destination);
    return;
  }
  await ref.writeToFile(destination);
}
