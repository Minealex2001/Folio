import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../crypto/vault_crypto.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';

/// Errores de exportación/importación de copia del cofre (mensajes para la UI).
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

bool _modeFileIsPlain(File modeFile) {
  if (!modeFile.existsSync()) return false;
  return modeFile.readAsStringSync().trim().toLowerCase() == _vaultModePlain;
}

bool _extractedDirIsPlainBackup(Directory extractedDir) {
  final f = File(p.join(extractedDir.path, VaultPaths.vaultModeFile));
  return _modeFileIsPlain(f);
}

/// Crea un ZIP con `manifest.json`, `vault.bin`, opcionalmente `vault.keys` y `vault.mode`,
/// y `attachments/` (solo lectura en disco). Cofres en texto plano no tienen `vault.keys`.
Future<void> exportVaultZip(File destination) async {
  final wrapped = await VaultPaths.wrappedDekPath();
  final cipher = await VaultPaths.cipherPayloadPath();
  final modeFile = await VaultPaths.vaultModePath();
  final plain = _modeFileIsPlain(modeFile);
  if (!cipher.existsSync()) {
    throw VaultBackupException('No hay cofre para exportar.');
  }
  if (!plain && !wrapped.existsSync()) {
    throw VaultBackupException('No hay cofre para exportar.');
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

/// Extrae un ZIP de copia a [outDir] (debe existir o crearse antes).
Future<void> extractBackupZipToDirectory(File zipFile, Directory outDir) async {
  if (!zipFile.existsSync()) {
    throw VaultBackupException('No se encontró el archivo de copia.');
  }
  if (!outDir.existsSync()) {
    await outDir.create(recursive: true);
  }
  try {
    await extractFileToDisk(zipFile.path, outDir.path);
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

  if (_extractedDirIsPlainBackup(extractedDir)) {
    try {
      VaultPayload.decodeUtf8(await binFile.readAsBytes());
    } catch (_) {
      throw VaultBackupException('El contenido del cofre en la copia no es válido.');
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

/// Sustituye el material del cofre **activo** por el del directorio ya validado.
Future<void> applyImportFromDirectory(Directory extractedDir) async {
  final root = await VaultPaths.vaultDirectory();
  await applyImportToVaultRoot(extractedDir, root);
}

/// Escribe la copia validada en la raíz de un cofre concreto (p. ej. cofre nuevo).
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

  if (_extractedDirIsPlainBackup(extractedDir)) {
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
