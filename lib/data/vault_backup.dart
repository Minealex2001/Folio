import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import '../core/errors/folio_exception.dart';
import '../crypto/vault_crypto.dart';
import '../git/vault_migration_tool.dart' show VaultMigrationTool;
import 'storage/atomic_file_writer.dart';
import 'storage/vault_storage.dart';
import 'vault_local_storage.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';

/// Errores de exportación/importación de copia de la libreta (mensajes para la UI).
class VaultBackupException extends FolioException {
  VaultBackupException(super.message);
}

const int kVaultBackupFormatVersion = 1;

const String kVaultBackupManifestFile = 'manifest.json';

const String _vaultModePlain = 'plain';
const String _vaultModeEncrypted = 'encrypted';

/// Copia de libreta ya materializada en memoria (sin `Directory` / disco).
///
/// Claves posix relativas: `manifest.json`, `vault.bin`, `vault.keys`,
/// `vault.mode`, `attachments/...`.
class ExtractedVaultBackup {
  ExtractedVaultBackup([Map<String, Uint8List>? files])
      : files = files ?? <String, Uint8List>{};

  final Map<String, Uint8List> files;

  void put(String relativePath, Uint8List bytes) {
    final key = relativePath.replaceAll(r'\', '/').replaceFirst(RegExp(r'^/+'), '');
    if (key.isEmpty) return;
    files[key] = bytes;
  }

  Uint8List? operator [](String relativePath) {
    final key = relativePath.replaceAll(r'\', '/');
    return files[key];
  }

  bool contains(String relativePath) =>
      files.containsKey(relativePath.replaceAll(r'\', '/'));

  String? readUtf8(String relativePath) {
    final raw = this[relativePath];
    if (raw == null) return null;
    return utf8.decode(raw);
  }

  Iterable<MapEntry<String, Uint8List>> get attachmentEntries sync* {
    const prefix = '${VaultPaths.attachmentsDirName}/';
    for (final e in files.entries) {
      if (e.key.startsWith(prefix) && e.key.length > prefix.length) {
        yield e;
      }
    }
  }
}

String _hexFromBytes(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

Future<String> _sha256FileHex(File f) async {
  final algo = Sha256();
  final hash = await algo.hash(await f.readAsBytes());
  return _hexFromBytes(hash.bytes);
}

Future<String> _sha256BytesHex(List<int> bytes) async {
  final algo = Sha256();
  final hash = await algo.hash(bytes);
  return _hexFromBytes(hash.bytes);
}

class VaultCloudBackupFingerprint {
  const VaultCloudBackupFingerprint({
    required this.fingerprint,
    required this.vaultBytes,
    required this.attachmentsBytes,
  });

  final String fingerprint;
  final int vaultBytes;
  final int attachmentsBytes;
}

/// Calcula un fingerprint estable del contenido de la libreta activa, pensado para
/// deduplicar copias en la nube. Incluye:
/// - `vault.bin` equivalente (siempre) — [vaultBinBytes] viene del estado en
///   memoria (`VaultSession.vaultBinEquivalentBytes()`), no del archivo en
///   disco: funciona igual en v0 y v1, sin depender de que `vault.bin` siga
///   existiendo tras migrar.
/// - `vault.keys` (si existe)
/// - Resumen rápido de adjuntos: ruta relativa + tamaño + mtime (no hash por archivo).
///
/// También devuelve el desglose aproximado de tamaño (vault vs adjuntos).
Future<VaultCloudBackupFingerprint> computeVaultCloudBackupFingerprint({
  required Uint8List vaultBinBytes,
}) async {
  if (kIsWeb) throw UnsupportedError('Backup not supported on web');
  final wrapped = await VaultPaths.wrappedDekPath();

  final parts = <String>[];
  int vaultBytes = 0;
  int attachmentsBytes = 0;

  final cipherHash = await _sha256BytesHex(vaultBinBytes);
  final cipherLen = vaultBinBytes.length;
  vaultBytes += cipherLen;
  parts.add('vault.bin:$cipherHash:$cipherLen');

  if (wrapped.existsSync()) {
    final keysHash = await _sha256FileHex(wrapped);
    final keysLen = await wrapped.length();
    vaultBytes += keysLen;
    parts.add('vault.keys:$keysHash:$keysLen');
  }

  final vaultDir = await VaultPaths.vaultDirectory();
  final attDir = Directory(
    p.join(vaultDir.path, VaultPaths.attachmentsDirName),
  );
  if (attDir.existsSync()) {
    final attEntries = <String>[];
    await for (final entity in attDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: attDir.path)
          .replaceAll(r'\', '/');
      final stat = await entity.stat();
      final len = stat.size;
      attachmentsBytes += len;
      attEntries.add('$rel:$len:${stat.modified.millisecondsSinceEpoch}');
    }
    attEntries.sort();
    parts.add('attachments:${attEntries.join("|")}');
  } else {
    parts.add('attachments:');
  }

  // Fingerprint final (hash del resumen) para evitar valores enormes.
  final algo = Sha256();
  final sumHash = await algo.hash(utf8.encode(parts.join('\n')));
  final fingerprint = _hexFromBytes(sumHash.bytes);

  return VaultCloudBackupFingerprint(
    fingerprint: fingerprint,
    vaultBytes: vaultBytes,
    attachmentsBytes: attachmentsBytes,
  );
}

/// Fingerprint por **contenido** (SHA-256 de cada archivo) para cloud-packs
/// incrementales; evita falsos positivos con `mtime` al deduplicar blobs.
///
/// [vaultBinBytes] viene del estado en memoria
/// (`VaultSession.vaultBinEquivalentBytes()`), no de leer `vault.bin` del
/// disco: funciona igual en v0 y v1.
Future<String> computeVaultCloudPackContentFingerprint({
  required Uint8List vaultBinBytes,
}) async {
  if (kIsWeb) throw UnsupportedError('Backup not supported on web');
  final wrapped = await VaultPaths.wrappedDekPath();

  final parts = <String>[];
  final cipherHash = await _sha256BytesHex(vaultBinBytes);
  final cipherLen = vaultBinBytes.length;
  parts.add('vault.bin:$cipherHash:$cipherLen');

  if (wrapped.existsSync()) {
    final keysHash = await _sha256FileHex(wrapped);
    final keysLen = await wrapped.length();
    parts.add('vault.keys:$keysHash:$keysLen');
  }

  final modeFile = await VaultPaths.vaultModePath();
  if (modeFile.existsSync()) {
    final modeHash = await _sha256FileHex(modeFile);
    final modeLen = await modeFile.length();
    parts.add('vault.mode:$modeHash:$modeLen');
  }

  final vaultDir = await VaultPaths.vaultDirectory();
  final attDir = Directory(
    p.join(vaultDir.path, VaultPaths.attachmentsDirName),
  );
  if (attDir.existsSync()) {
    final attEntries = <String>[];
    await for (final entity in attDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: attDir.path)
          .replaceAll(r'\', '/');
      final h = await _sha256FileHex(entity);
      final len = await entity.length();
      attEntries.add('$rel:$h:$len');
    }
    attEntries.sort();
    parts.add('attachments:${attEntries.join("|")}');
  } else {
    parts.add('attachments:');
  }

  final algo = Sha256();
  final sumHash = await algo.hash(utf8.encode(parts.join('\n')));
  return _hexFromBytes(sumHash.bytes);
}

bool _modeFileIsPlain(File modeFile) {
  if (!modeFile.existsSync()) return false;
  return modeFile.readAsStringSync().trim().toLowerCase() == _vaultModePlain;
}

bool _extractedDirIsPlainBackup(Directory extractedDir) {
  final f = File(p.join(extractedDir.path, VaultPaths.vaultModeFile));
  return _modeFileIsPlain(f);
}

bool _extractedDirIsEncryptedByMode(Directory extractedDir) {
  final f = File(p.join(extractedDir.path, VaultPaths.vaultModeFile));
  if (!f.existsSync()) return false;
  return f.readAsStringSync().trim().toLowerCase() == _vaultModeEncrypted;
}

/// Libreta sin cifrado: `vault.mode` = plain, o sin `vault.keys` y `vault.bin` decodificable
/// como [VaultPayload] (p. ej. copia antigua sin `vault.mode`).
Future<bool> isPlainExtractedBackupDirectory(Directory extractedDir) =>
    _extractedBackupIsPlain(extractedDir);

Future<bool> _extractedBackupIsPlain(Directory extractedDir) async {
  if (_extractedDirIsPlainBackup(extractedDir)) return true;
  final keysFile = File(p.join(extractedDir.path, VaultPaths.wrappedDekFile));
  if (keysFile.existsSync()) return false;
  if (_extractedDirIsEncryptedByMode(extractedDir)) return false;
  final binFile = File(p.join(extractedDir.path, VaultPaths.cipherPayloadFile));
  if (!binFile.existsSync()) return false;
  try {
    VaultPayload.decodeUtf8(await binFile.readAsBytes());
    return true;
  } catch (_) {
    return false;
  }
}

/// Devuelve true si el ZIP representa una copia **en texto plano** (sin cifrado).
Future<bool> isPlainBackupZip(File zipFile) async {
  return isPlainBackupArchive(zipFile);
}

/// Devuelve true si el archivo representa una copia **en texto plano** (sin cifrado).
/// Soporta ZIP y TAR.GZ (y otros contenedores que `archive` pueda extraer).
Future<bool> isPlainBackupArchive(File archiveFile) async {
  final tmp = Directory.systemTemp.createTempSync('folio_backup_probe_');
  try {
    await extractBackupArchiveToDirectory(archiveFile, tmp);
    return _extractedBackupIsPlain(tmp);
  } finally {
    try {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// Crea una copia ZIP automática antes de operaciones destructivas de importación.
Future<String> createPreImportBackupZip({
  required Uint8List vaultBinBytes,
}) async {
  if (kIsWeb) throw UnsupportedError('Backup not supported on web');
  final vaultDir = await VaultPaths.vaultDirectory();
  final backupsDir = Directory(p.join(vaultDir.path, 'backups'));
  if (!backupsDir.existsSync()) {
    await backupsDir.create(recursive: true);
  }
  final path = p.join(
    backupsDir.path,
    'pre_import_${DateTime.now().millisecondsSinceEpoch}.zip',
  );
  await exportVaultZip(File(path), vaultBinBytes: vaultBinBytes);
  return path;
}

/// Crea un ZIP con `manifest.json`, `vault.bin`, opcionalmente `vault.keys` y `vault.mode`,
/// y `attachments/` (solo lectura en disco). Libretas en texto plano no tienen `vault.keys`.
///
/// [vaultBinBytes] viene del estado en memoria
/// (`VaultSession.vaultBinEquivalentBytes()`), no de leer `vault.bin` del
/// disco: el ZIP exportado refleja el contenido actual sin importar si la
/// libreta está en formato v0 o v1.
Future<void> exportVaultZip(
  File destination, {
  required Uint8List vaultBinBytes,
}) async {
  if (kIsWeb) throw UnsupportedError('Backup not supported on web');
  final wrapped = await VaultPaths.wrappedDekPath();
  final modeFile = await VaultPaths.vaultModePath();
  final plain = _modeFileIsPlain(modeFile);
  if (!plain && !wrapped.existsSync()) {
    throw VaultBackupException('No hay libreta para exportar.');
  }

  final manifest = jsonEncode(<String, Object?>{
    'formatVersion': kVaultBackupFormatVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'appName': 'Folio',
  });

  final encoder = ZipFileEncoder();
  encoder.create(destination.path, level: ZipFileEncoder.store);
  try {
    encoder.addArchiveFile(
      ArchiveFile.bytes(kVaultBackupManifestFile, utf8.encode(manifest)),
    );
    if (!plain) {
      await encoder.addFile(
        wrapped,
        VaultPaths.wrappedDekFile,
        ZipFileEncoder.store,
      );
    }
    encoder.addArchiveFile(
      ArchiveFile.bytes(VaultPaths.cipherPayloadFile, vaultBinBytes),
    );
    if (modeFile.existsSync()) {
      await encoder.addFile(
        modeFile,
        VaultPaths.vaultModeFile,
        ZipFileEncoder.store,
      );
    }

    final vaultDir = await VaultPaths.vaultDirectory();
    final attDir = Directory(
      p.join(vaultDir.path, VaultPaths.attachmentsDirName),
    );
    if (attDir.existsSync()) {
      await for (final entity in attDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: attDir.path);
          final zipName = p.posix.join(
            VaultPaths.attachmentsDirName,
            rel.replaceAll(r'\', '/'),
          );
          await encoder.addFile(entity, zipName, ZipFileEncoder.store);
        }
      }
    }
  } finally {
    await encoder.close();
  }
}

/// Crea un TAR.GZ con el mismo contenido que [exportVaultZip], pensado para copias en la nube.
///
/// [vaultBinBytes] viene del estado en memoria
/// (`VaultSession.vaultBinEquivalentBytes()`), no de leer `vault.bin` del
/// disco: funciona igual en v0 y v1.
Future<void> exportVaultTarGz(
  File destination, {
  required Uint8List vaultBinBytes,
}) async {
  if (kIsWeb) throw UnsupportedError('Backup not supported on web');
  final wrapped = await VaultPaths.wrappedDekPath();
  final modeFile = await VaultPaths.vaultModePath();
  final plain = _modeFileIsPlain(modeFile);
  if (!plain && !wrapped.existsSync()) {
    throw VaultBackupException('No hay libreta para exportar.');
  }

  final manifest = jsonEncode(<String, Object?>{
    'formatVersion': kVaultBackupFormatVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'appName': 'Folio',
  });

  final tmpDir = await Directory.systemTemp.createTemp('folio_backup_tgz_');
  final tarPath = p.join(tmpDir.path, 'vault.tar');
  final manifestFile = File(p.join(tmpDir.path, kVaultBackupManifestFile));
  await manifestFile.writeAsString(manifest, flush: true);
  final cipherFile = File(p.join(tmpDir.path, VaultPaths.cipherPayloadFile));
  await cipherFile.writeAsBytes(vaultBinBytes, flush: true);

  final encoder = TarFileEncoder();
  encoder.create(tarPath);
  try {
    await encoder.addFile(manifestFile, kVaultBackupManifestFile);
    if (!plain) {
      await encoder.addFile(wrapped, VaultPaths.wrappedDekFile);
    }
    await encoder.addFile(cipherFile, VaultPaths.cipherPayloadFile);
    if (modeFile.existsSync()) {
      await encoder.addFile(modeFile, VaultPaths.vaultModeFile);
    }

    final vaultDir = await VaultPaths.vaultDirectory();
    final attDir = Directory(
      p.join(vaultDir.path, VaultPaths.attachmentsDirName),
    );
    if (attDir.existsSync()) {
      await for (final entity in attDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: attDir.path);
          final tarName = p.posix.join(
            VaultPaths.attachmentsDirName,
            rel.replaceAll(r'\', '/'),
          );
          await encoder.addFile(entity, tarName);
        }
      }
    }
  } finally {
    await encoder.close();
  }

  try {
    // GZip del TAR a destino final.
    final input = InputFileStream(tarPath);
    final output = OutputFileStream(destination.path);
    GZipEncoder().encodeStream(input, output, level: 6);
    await input.close();
    await output.close();
  } finally {
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Extrae un ZIP de copia a [outDir] (debe existir o crearse antes).
Future<void> extractBackupZipToDirectory(File zipFile, Directory outDir) async {
  await extractBackupArchiveToDirectory(zipFile, outDir);
}

/// Extrae un archivo de copia (ZIP/TAR.GZ) a [outDir] (debe existir o crearse antes).
Future<void> extractBackupArchiveToDirectory(
  File archiveFile,
  Directory outDir,
) async {
  if (!archiveFile.existsSync()) {
    throw VaultBackupException('No se encontró el archivo de copia.');
  }
  if (!outDir.existsSync()) {
    await outDir.create(recursive: true);
  }
  try {
    await extractFileToDisk(archiveFile.path, outDir.path);
  } on ArgumentError catch (e) {
    throw VaultBackupException('Archivo de copia no válido: $e');
  }
}

/// Comprueba manifest, presencia de archivos y que la [password] abre el
/// payload del extracto. Devuelve el payload decodificado (ya hacía falta
/// descifrarlo/decodificarlo para validar) para que el llamador pueda
/// comprobar, por ejemplo, si la copia está vacía antes de restaurarla.
Future<VaultPayload> validateImportZip(
  Directory extractedDir,
  String password,
) async {
  final manifestFile = File(
    p.join(extractedDir.path, kVaultBackupManifestFile),
  );
  if (!manifestFile.existsSync()) {
    throw VaultBackupException(
      'La copia no contiene manifest.json o está incompleta.',
    );
  }

  Map<String, Object?> map;
  try {
    map = jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
  } catch (_) {
    throw VaultBackupException('El manifest de la copia no es válido.');
  }

  final rawFv = map['formatVersion'];
  final fv = rawFv is int
      ? rawFv
      : rawFv is num
      ? rawFv.toInt()
      : null;
  if (fv != kVaultBackupFormatVersion) {
    throw VaultBackupException(
      'Formato de copia no compatible. Actualiza Folio o exporta de nuevo.',
    );
  }

  final keysFile = File(p.join(extractedDir.path, VaultPaths.wrappedDekFile));
  final binFile = File(p.join(extractedDir.path, VaultPaths.cipherPayloadFile));
  if (!binFile.existsSync()) {
    throw VaultBackupException('Falta vault.bin en la copia.');
  }

  if (await _extractedBackupIsPlain(extractedDir)) {
    try {
      return VaultPayload.decodeUtf8(await binFile.readAsBytes());
    } catch (_) {
      throw VaultBackupException(
        'El contenido de la libreta en la copia no es válido.',
      );
    }
  }

  if (!keysFile.existsSync()) {
    throw VaultBackupException('Falta vault.keys en la copia cifrada.');
  }

  final wrapped = await keysFile.readAsBytes();
  final enc = await binFile.readAsBytes();

  try {
    final dekBytes = await VaultCrypto.unwrapDek(
      wrapped: wrapped,
      password: password,
    );
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final clear = await VaultCrypto.decryptPayload(blob: enc, dek: dek);
    return VaultPayload.decodeUtf8(clear);
  } on VaultCryptoException catch (e) {
    throw VaultBackupException(e.message);
  }
}

/// Libreta sin cifrado en un árbol en memoria.
Future<bool> isPlainExtractedBackup(ExtractedVaultBackup backup) async {
  final mode = backup.readUtf8(VaultPaths.vaultModeFile)?.trim().toLowerCase();
  if (mode == _vaultModePlain) return true;
  if (backup.contains(VaultPaths.wrappedDekFile)) return false;
  if (mode == _vaultModeEncrypted) return false;
  final bin = backup[VaultPaths.cipherPayloadFile];
  if (bin == null) return false;
  try {
    VaultPayload.decodeUtf8(bin);
    return true;
  } catch (_) {
    return false;
  }
}

/// Comprueba manifest y que [password] abre el payload (árbol en memoria).
/// Devuelve el payload decodificado — ver [validateImportZip].
Future<VaultPayload> validateImportBackup(
  ExtractedVaultBackup backup,
  String password,
) async {
  final manifestRaw = backup[kVaultBackupManifestFile];
  if (manifestRaw == null) {
    throw VaultBackupException(
      'La copia no contiene manifest.json o está incompleta.',
    );
  }

  Map<String, Object?> map;
  try {
    map = jsonDecode(utf8.decode(manifestRaw)) as Map<String, Object?>;
  } catch (_) {
    throw VaultBackupException('El manifest de la copia no es válido.');
  }

  final rawFv = map['formatVersion'];
  final fv = rawFv is int
      ? rawFv
      : rawFv is num
      ? rawFv.toInt()
      : null;
  if (fv != kVaultBackupFormatVersion) {
    throw VaultBackupException(
      'Formato de copia no compatible. Actualiza Folio o exporta de nuevo.',
    );
  }

  final bin = backup[VaultPaths.cipherPayloadFile];
  if (bin == null) {
    throw VaultBackupException('Falta vault.bin en la copia.');
  }

  if (await isPlainExtractedBackup(backup)) {
    try {
      return VaultPayload.decodeUtf8(bin);
    } catch (_) {
      throw VaultBackupException(
        'El contenido de la libreta en la copia no es válido.',
      );
    }
  }

  final keys = backup[VaultPaths.wrappedDekFile];
  if (keys == null) {
    throw VaultBackupException('Falta vault.keys en la copia cifrada.');
  }

  try {
    final dekBytes = await VaultCrypto.unwrapDek(
      wrapped: keys,
      password: password,
    );
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final clear = await VaultCrypto.decryptPayload(blob: bin, dek: dek);
    return VaultPayload.decodeUtf8(clear);
  } on VaultCryptoException catch (e) {
    throw VaultBackupException(e.message);
  }
}

/// Escribe una copia en memoria a [vaultId] vía [VaultStorage] (web y nativo).
Future<void> applyImportToVaultIdFromMemory(
  ExtractedVaultBackup backup,
  String vaultId,
) async {
  final id = vaultId.trim();
  if (id.isEmpty) {
    throw VaultBackupException('vaultId vacío.');
  }
  await VaultPaths.initVaultStorage(id);

  final bin = backup[VaultPaths.cipherPayloadFile];
  if (bin == null) {
    throw VaultBackupException('Falta vault.bin en la copia.');
  }

  final modeRaw = backup[VaultPaths.vaultModeFile];
  if (await isPlainExtractedBackup(backup)) {
    await VaultStorage.instance.deleteVaultFile(id, VaultPaths.wrappedDekFile);
    await VaultStorage.instance.writeVaultFile(
      id,
      VaultPaths.cipherPayloadFile,
      bin,
    );
    await VaultStorage.instance.writeVaultFile(
      id,
      VaultPaths.vaultModeFile,
      modeRaw ?? Uint8List.fromList(utf8.encode(_vaultModePlain)),
    );
  } else {
    final keys = backup[VaultPaths.wrappedDekFile];
    if (keys == null) {
      throw VaultBackupException('Falta vault.keys en la copia cifrada.');
    }
    await VaultStorage.instance.writeVaultFile(
      id,
      VaultPaths.wrappedDekFile,
      keys,
    );
    await VaultStorage.instance.writeVaultFile(
      id,
      VaultPaths.cipherPayloadFile,
      bin,
    );
    await VaultStorage.instance.writeVaultFile(
      id,
      VaultPaths.vaultModeFile,
      modeRaw ?? Uint8List.fromList(utf8.encode(_vaultModeEncrypted)),
    );
  }

  await VaultStorage.instance.clearAttachments(id);
  for (final e in backup.attachmentEntries) {
    await VaultStorage.instance.writeVaultFile(id, e.key, e.value);
  }
}

/// Aplica una copia ya extraída a [vaultId] en almacenamiento web (IndexedDB).
Future<void> _applyImportToVaultStorageFromExtractedDir(
  Directory extractedDir,
  String vaultId,
) async {
  final keysSrc = File(p.join(extractedDir.path, VaultPaths.wrappedDekFile));
  final binSrc = File(p.join(extractedDir.path, VaultPaths.cipherPayloadFile));
  final modeSrc = File(p.join(extractedDir.path, VaultPaths.vaultModeFile));
  if (!binSrc.existsSync()) {
    throw VaultBackupException('Falta vault.bin en la copia.');
  }

  if (await _extractedBackupIsPlain(extractedDir)) {
    await VaultStorage.instance.deleteVaultFile(vaultId, VaultPaths.wrappedDekFile);
    await VaultStorage.instance.writeVaultFile(
      vaultId,
      VaultPaths.cipherPayloadFile,
      await binSrc.readAsBytes(),
    );
    if (modeSrc.existsSync()) {
      await VaultStorage.instance.writeVaultFile(
        vaultId,
        VaultPaths.vaultModeFile,
        Uint8List.fromList(utf8.encode(await modeSrc.readAsString())),
      );
    } else {
      await VaultStorage.instance.writeVaultFile(
        vaultId,
        VaultPaths.vaultModeFile,
        Uint8List.fromList(utf8.encode(_vaultModePlain)),
      );
    }
  } else {
    if (!keysSrc.existsSync()) {
      throw VaultBackupException('Falta vault.keys en la copia cifrada.');
    }
    await VaultStorage.instance.writeVaultFile(
      vaultId,
      VaultPaths.wrappedDekFile,
      await keysSrc.readAsBytes(),
    );
    await VaultStorage.instance.writeVaultFile(
      vaultId,
      VaultPaths.cipherPayloadFile,
      await binSrc.readAsBytes(),
    );
    if (modeSrc.existsSync()) {
      await VaultStorage.instance.writeVaultFile(
        vaultId,
        VaultPaths.vaultModeFile,
        Uint8List.fromList(utf8.encode(await modeSrc.readAsString())),
      );
    } else {
      await VaultStorage.instance.writeVaultFile(
        vaultId,
        VaultPaths.vaultModeFile,
        Uint8List.fromList(utf8.encode(_vaultModeEncrypted)),
      );
    }
  }

  await VaultStorage.instance.clearAttachments(vaultId);

  final attachmentsSrc = Directory(
    p.join(extractedDir.path, VaultPaths.attachmentsDirName),
  );
  if (attachmentsSrc.existsSync()) {
    await for (final entity in attachmentsSrc.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final rel = p
            .relative(entity.path, from: attachmentsSrc.path)
            .replaceAll(r'\', '/');
        final vaultRel = p.posix.join(VaultPaths.attachmentsDirName, rel);
        await VaultStorage.instance.writeVaultFile(
          vaultId,
          vaultRel,
          await entity.readAsBytes(),
        );
      }
    }
  }
}

/// Sustituye el material de la libreta **activa** por el del directorio ya
/// validado. [importedPayload] (el resultado ya en mano de
/// `validateImportZip`/`validateImportBackup`) permite rechazar el import si
/// viene vacío y la libreta activa no lo está — ver [applyImportToVaultRoot].
Future<void> applyImportFromDirectory(
  Directory extractedDir, {
  VaultPayload? importedPayload,
}) async {
  if (kIsWeb) {
    final vaultId = VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) {
      throw VaultBackupException('No hay libreta activa.');
    }
    await _applyImportToVaultStorageFromExtractedDir(extractedDir, vaultId);
    return;
  }
  final root = await VaultPaths.vaultDirectory();
  await applyImportToVaultRoot(
    extractedDir,
    root,
    importedPayload: importedPayload,
  );
}

/// Escribe la copia validada en la raíz de una libreta concreta (p. ej.
/// libreta nueva). Si se pasa [importedPayload] y viene sin páginas,
/// rechaza el import cuando la libreta destino ya tiene contenido (árbol
/// v1) — evita restaurar por error una copia vacía/corrupta sobre una
/// libreta con datos reales. Toda la operación va bajo el mismo candado por
/// libreta que usa `VaultLocalStorage`, para no correr a la vez que un sync
/// en segundo plano de esa libreta.
Future<void> applyImportToVaultRoot(
  Directory extractedDir,
  Directory vaultRoot, {
  VaultPayload? importedPayload,
}) async {
  if (kIsWeb) {
    final vaultId = p.basename(vaultRoot.path);
    await _applyImportToVaultStorageFromExtractedDir(extractedDir, vaultId);
    return;
  }
  await VaultLocalStorage.runExclusive(vaultRoot.path, () async {
    if (importedPayload != null && importedPayload.pages.isEmpty) {
      final repoDir = Directory(p.join(vaultRoot.path, 'repo'));
      final existingPages = repoDir.existsSync()
          ? VaultLocalStorage.countPageDirs(repoDir)
          : 0;
      if (existingPages > 0) {
        throw VaultBackupException(
          'La copia a restaurar no tiene páginas y la libreta actual tiene '
          '$existingPages. Por seguridad, no se restaura para evitar '
          'vaciarla — exporta primero la libreta actual si de verdad '
          'quieres continuar.',
        );
      }
    }

    final keysSrc = File(p.join(extractedDir.path, VaultPaths.wrappedDekFile));
    final binSrc = File(p.join(extractedDir.path, VaultPaths.cipherPayloadFile));
    final modeSrc = File(p.join(extractedDir.path, VaultPaths.vaultModeFile));
    if (!binSrc.existsSync()) {
      throw VaultBackupException('Falta vault.bin en la copia.');
    }

    final destWrapped = File(p.join(vaultRoot.path, VaultPaths.wrappedDekFile));
    final destBin = File(p.join(vaultRoot.path, VaultPaths.cipherPayloadFile));
    final destMode = File(p.join(vaultRoot.path, VaultPaths.vaultModeFile));
    final isPlain = await _extractedBackupIsPlain(extractedDir);
    if (!isPlain && !keysSrc.existsSync()) {
      throw VaultBackupException('Falta vault.keys en la copia cifrada.');
    }

    // Escritura atómica (tmp + rename + rotación .bak) en vez de File.copy
    // directo: si el proceso muere a mitad, cada archivo destino queda
    // completo en su estado anterior, nunca a medias.
    await AtomicFileWriter.writeAtomic(destBin, await binSrc.readAsBytes());
    if (isPlain) {
      if (destWrapped.existsSync()) {
        await destWrapped.delete();
      }
    } else {
      await AtomicFileWriter.writeAtomic(
        destWrapped,
        await keysSrc.readAsBytes(),
      );
    }
    final modeBytes = modeSrc.existsSync()
        ? await modeSrc.readAsBytes()
        : Uint8List.fromList(
            utf8.encode(isPlain ? _vaultModePlain : _vaultModeEncrypted),
          );
    await AtomicFileWriter.writeAtomic(destMode, modeBytes);

    // El vault.bin importado es ahora la única fuente de verdad: invalidar
    // cualquier árbol v1 existente para que el próximo bootstrap migre desde
    // el contenido recién importado en vez de seguir leyendo el árbol viejo.
    // Sin esto, restaurar un backup sobre una libreta ya migrada a v1 no tenía
    // ningún efecto visible: el marker `vault.format` seguía diciendo 1 y el
    // bootstrap ignoraba en silencio el vault.bin recién importado.
    await _invalidateStaleV1TreeAfterImport(vaultRoot);

    final attDir = Directory(
      p.join(vaultRoot.path, VaultPaths.attachmentsDirName),
    );
    final attachmentsSrc = Directory(
      p.join(extractedDir.path, VaultPaths.attachmentsDirName),
    );
    final stagingAtt = Directory(
      p.join(vaultRoot.path, '${VaultPaths.attachmentsDirName}.importing'),
    );
    if (stagingAtt.existsSync()) {
      await stagingAtt.delete(recursive: true);
    }
    await stagingAtt.create(recursive: true);
    if (attachmentsSrc.existsSync()) {
      await for (final entity in attachmentsSrc.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: attachmentsSrc.path);
          final destPath = p.join(stagingAtt.path, rel);
          await Directory(p.dirname(destPath)).create(recursive: true);
          await entity.copy(destPath);
        }
      }
    }
    // Swap: la carpeta de adjuntos anterior se renombra aparte (no se borra)
    // por si el import resulta equivocado y hay que recuperarla a mano.
    if (attDir.existsSync()) {
      final oldAtt = Directory(
        p.join(vaultRoot.path, '${VaultPaths.attachmentsDirName}.pre-import'),
      );
      if (oldAtt.existsSync()) {
        await oldAtt.delete(recursive: true);
      }
      await attDir.rename(oldAtt.path);
    }
    await stagingAtt.rename(attDir.path);
  });
}

/// Renombra aparte (no borra) `repo/`, `versions/` y los markers de formato
/// v1 tras un import de `vault.bin`, para que el próximo `bootstrap()` trate
/// la libreta como v0 recién importada y migre desde el contenido correcto.
Future<void> _invalidateStaleV1TreeAfterImport(Directory vaultRoot) async {
  final repoDir = Directory(p.join(vaultRoot.path, 'repo'));
  if (repoDir.existsSync()) {
    final backup = Directory(p.join(vaultRoot.path, 'repo.pre-import'));
    if (backup.existsSync()) await backup.delete(recursive: true);
    await repoDir.rename(backup.path);
  }
  final versionsDir = Directory(p.join(vaultRoot.path, 'versions'));
  if (versionsDir.existsSync()) {
    final backup = Directory(p.join(vaultRoot.path, 'versions.pre-import'));
    if (backup.existsSync()) await backup.delete(recursive: true);
    await versionsDir.rename(backup.path);
  }
  final formatMarker = File(p.join(vaultRoot.path, 'vault.format'));
  if (formatMarker.existsSync()) await formatMarker.delete();
  final verifiedMarker = File(
    p.join(vaultRoot.path, VaultMigrationTool.v1VerifiedFile),
  );
  if (verifiedMarker.existsSync()) await verifiedMarker.delete();
}

/// Importa a un [vaultId] concreto (web y nativo) sin depender de rutas nativas.
Future<void> applyImportToVaultId(
  Directory extractedDir,
  String vaultId,
) async {
  final id = vaultId.trim();
  if (id.isEmpty) {
    throw VaultBackupException('vaultId vacío.');
  }
  await VaultPaths.initVaultStorage(id);
  if (kIsWeb) {
    await _applyImportToVaultStorageFromExtractedDir(extractedDir, id);
    return;
  }
  final root = await VaultPaths.vaultDirectoryForId(id);
  await applyImportToVaultRoot(extractedDir, root);
}
