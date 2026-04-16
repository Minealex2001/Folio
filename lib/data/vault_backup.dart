import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../crypto/vault_crypto.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';

/// Errores de exportación/importación de copia de la libreta (mensajes para la UI).
class VaultBackupException implements Exception {
  VaultBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

const int kVaultBackupFormatVersion = 1;

const String kVaultBackupManifestFile = 'manifest.json';

const String _vaultModePlain = 'plain';
const String _vaultModeEncrypted = 'encrypted';

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
/// - `vault.bin` (siempre)
/// - `vault.keys` (si existe)
/// - Resumen rápido de adjuntos: ruta relativa + tamaño + mtime (no hash por archivo).
///
/// También devuelve el desglose aproximado de tamaño (vault vs adjuntos).
Future<VaultCloudBackupFingerprint> computeVaultCloudBackupFingerprint() async {
  final wrapped = await VaultPaths.wrappedDekPath();
  final cipher = await VaultPaths.cipherPayloadPath();
  if (!cipher.existsSync()) {
    throw VaultBackupException('No hay libreta para exportar.');
  }

  final parts = <String>[];
  int vaultBytes = 0;
  int attachmentsBytes = 0;

  final cipherHash = await _sha256FileHex(cipher);
  final cipherLen = await cipher.length();
  vaultBytes += cipherLen;
  parts.add('vault.bin:$cipherHash:$cipherLen');

  if (wrapped.existsSync()) {
    final keysHash = await _sha256FileHex(wrapped);
    final keysLen = await wrapped.length();
    vaultBytes += keysLen;
    parts.add('vault.keys:$keysHash:$keysLen');
  }

  final vaultDir = await VaultPaths.vaultDirectory();
  final attDir = Directory(p.join(vaultDir.path, VaultPaths.attachmentsDirName));
  if (attDir.existsSync()) {
    final attEntries = <String>[];
    await for (final entity in attDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p.relative(entity.path, from: attDir.path).replaceAll(r'\', '/');
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

/// Crea un ZIP con `manifest.json`, `vault.bin`, opcionalmente `vault.keys` y `vault.mode`,
/// y `attachments/` (solo lectura en disco). Libretas en texto plano no tienen `vault.keys`.
Future<void> exportVaultZip(File destination) async {
  final wrapped = await VaultPaths.wrappedDekPath();
  final cipher = await VaultPaths.cipherPayloadPath();
  final modeFile = await VaultPaths.vaultModePath();
  final plain = _modeFileIsPlain(modeFile);
  if (!cipher.existsSync()) {
    throw VaultBackupException('No hay libreta para exportar.');
  }
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
    await encoder.addFile(
      cipher,
      VaultPaths.cipherPayloadFile,
      ZipFileEncoder.store,
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
/// Se genera sin cargar el vault completo en memoria (streaming desde disco).
Future<void> exportVaultTarGz(File destination) async {
  final wrapped = await VaultPaths.wrappedDekPath();
  final cipher = await VaultPaths.cipherPayloadPath();
  final modeFile = await VaultPaths.vaultModePath();
  final plain = _modeFileIsPlain(modeFile);
  if (!cipher.existsSync()) {
    throw VaultBackupException('No hay libreta para exportar.');
  }
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

  final encoder = TarFileEncoder();
  encoder.create(tarPath);
  try {
    await encoder.addFile(manifestFile, kVaultBackupManifestFile);
    if (!plain) {
      await encoder.addFile(wrapped, VaultPaths.wrappedDekFile);
    }
    await encoder.addFile(cipher, VaultPaths.cipherPayloadFile);
    if (modeFile.existsSync()) {
      await encoder.addFile(modeFile, VaultPaths.vaultModeFile);
    }

    final vaultDir = await VaultPaths.vaultDirectory();
    final attDir = Directory(p.join(vaultDir.path, VaultPaths.attachmentsDirName));
    if (attDir.existsSync()) {
      await for (final entity in attDir.list(recursive: true, followLinks: false)) {
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

/// Comprueba manifest, presencia de archivos y que la [password] abre el payload del extracto.
Future<void> validateImportZip(Directory extractedDir, String password) async {
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
      VaultPayload.decodeUtf8(await binFile.readAsBytes());
    } catch (_) {
      throw VaultBackupException('El contenido de la libreta en la copia no es válido.');
    }
    return;
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
    VaultPayload.decodeUtf8(clear);
  } on VaultCryptoException catch (e) {
    throw VaultBackupException(e.message);
  }
}

/// Sustituye el material de la libreta **activa** por el del directorio ya validado.
Future<void> applyImportFromDirectory(Directory extractedDir) async {
  final root = await VaultPaths.vaultDirectory();
  await applyImportToVaultRoot(extractedDir, root);
}

/// Escribe la copia validada en la raíz de una libreta concreta (p. ej. libreta nueva).
Future<void> applyImportToVaultRoot(
  Directory extractedDir,
  Directory vaultRoot,
) async {
  final keysSrc = File(p.join(extractedDir.path, VaultPaths.wrappedDekFile));
  final binSrc = File(p.join(extractedDir.path, VaultPaths.cipherPayloadFile));
  final modeSrc = File(p.join(extractedDir.path, VaultPaths.vaultModeFile));
  if (!binSrc.existsSync()) {
    throw VaultBackupException('Falta vault.bin en la copia.');
  }

  final destWrapped = File(p.join(vaultRoot.path, VaultPaths.wrappedDekFile));
  final destBin = File(p.join(vaultRoot.path, VaultPaths.cipherPayloadFile));
  final destMode = File(p.join(vaultRoot.path, VaultPaths.vaultModeFile));

  if (await _extractedBackupIsPlain(extractedDir)) {
    if (destWrapped.existsSync()) {
      await destWrapped.delete();
    }
    await binSrc.copy(destBin.path);
    if (modeSrc.existsSync()) {
      await modeSrc.copy(destMode.path);
    } else {
      await destMode.writeAsString(_vaultModePlain, flush: true);
    }
  } else {
    if (!keysSrc.existsSync()) {
      throw VaultBackupException('Falta vault.keys en la copia cifrada.');
    }
    await keysSrc.copy(destWrapped.path);
    await binSrc.copy(destBin.path);
    if (modeSrc.existsSync()) {
      await modeSrc.copy(destMode.path);
    } else {
      await destMode.writeAsString(_vaultModeEncrypted, flush: true);
    }
  }

  final attDir = Directory(
    p.join(vaultRoot.path, VaultPaths.attachmentsDirName),
  );
  if (attDir.existsSync()) {
    await attDir.delete(recursive: true);
  }
  await attDir.create(recursive: true);

  final attachmentsSrc = Directory(
    p.join(extractedDir.path, VaultPaths.attachmentsDirName),
  );
  if (attachmentsSrc.existsSync()) {
    await for (final entity in attachmentsSrc.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final rel = p.relative(entity.path, from: attachmentsSrc.path);
        final destPath = p.join(attDir.path, rel);
        await Directory(p.dirname(destPath)).create(recursive: true);
        await entity.copy(destPath);
      }
    }
  }
}
