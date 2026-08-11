import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../data/folio_cloud_pack_format.dart';
import '../../data/vault_backup.dart';
import '../../data/vault_paths.dart';
import '../folio_cloud/folio_cloud_blob_codec.dart';
import '../folio_cloud/folio_cloud_pack_crypto.dart';
import '../folio_cloud/folio_storage_transport.dart';

/// Un blob cifrado listo para subir al pack.
class VaultPackPreparedBlob {
  const VaultPackPreparedBlob({
    required this.item,
    required this.cipherBytes,
  });

  final FolioCloudPackSnapshotItem item;
  final List<int> cipherBytes;
}

/// Construye la lista de blobs cifrados + manifiesto de snapshot a partir
/// de la libreta abierta.
///
/// [vaultBinBytes] viene del estado en memoria
/// (`VaultSession.vaultBinEquivalentBytes()`), no de leer `vault.bin` del
/// disco: funciona igual en v0 y v1, sin depender de que ese archivo siga
/// existiendo tras migrar.
///
/// Formato v2: comprime (gzip cuando ayuda) y trocea payloads grandes en
/// partes ≤ [kFolioCloudBlobChunkPlainBytes] antes de cifrar, para no
/// superar el tope HTTP de [kFolioStorageMaxObjectBytes].
Future<({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest})>
    buildVaultPackSnapshot({
  required SecretKey packKey,
  required String contentFingerprint,
  required Uint8List vaultBinBytes,
}) async {
  final wrapped = await VaultPaths.wrappedDekPath();
  final modeFile = await VaultPaths.vaultModePath();
  final plain = _modeFileIsPlain(modeFile);
  if (!plain && !wrapped.existsSync()) {
    throw VaultBackupException('No hay libreta para exportar.');
  }

  final vaultDir = await VaultPaths.vaultDirectory();
  final attDir = Directory(
    p.join(vaultDir.path, VaultPaths.attachmentsDirName),
  );
  final attPaths = <String>[];
  if (attDir.existsSync()) {
    await for (final entity in attDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: attDir.path)
          .replaceAll(r'\', '/');
      attPaths.add('${VaultPaths.attachmentsDirName}/$rel');
    }
    attPaths.sort();
  }

  final manifestJson = jsonEncode(<String, Object?>{
    'formatVersion': kVaultBackupFormatVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'appName': 'Folio',
  });
  final manifestPlain = utf8.encode(manifestJson);

  final prepared = <VaultPackPreparedBlob>[];
  final items = <FolioCloudPackSnapshotItem>[];

  Future<void> addBlob({
    required FolioCloudPackBlobRole role,
    required List<int> plainBytes,
    String? attachmentPosix,
  }) async {
    final preparedPlain = prepareCloudBlobPlainChunks(
      plain: plainBytes,
      role: folioCloudPackRoleWire(role),
      attachmentRelativePath: attachmentPosix,
    );
    final chunkCount = preparedPlain.chunks.length;
    for (var i = 0; i < chunkCount; i++) {
      final chunkPlain = preparedPlain.chunks[i];
      // Incluir índice en el role del nonce para que trozos distintos del
      // mismo contenido (imposible en content-addressed, pero sí si se
      // re-parte) no reutilicen nonce.
      final cipherBytes = await cloudPackEncryptPlainBlob(
        plain: chunkPlain,
        packKey: packKey,
        role: chunkCount == 1
            ? role.name
            : '${role.name}:chunk:$i/$chunkCount',
      );
      if (cipherBytes.length > kFolioStorageMaxObjectBytes) {
        throw StateError(
          'Cloud-pack chunk too large after encrypt '
          '(${cipherBytes.length} > $kFolioStorageMaxObjectBytes)',
        );
      }
      final id = await cloudPackBlobIdFromCipherBytes(cipherBytes);
      final item = FolioCloudPackSnapshotItem(
        role: role,
        blobId: id,
        relativePath: attachmentPosix,
        chunkIndex: i,
        chunkCount: chunkCount,
        compression: preparedPlain.compression,
      );
      items.add(item);
      prepared.add(VaultPackPreparedBlob(item: item, cipherBytes: cipherBytes));
    }
  }

  await addBlob(
    role: FolioCloudPackBlobRole.backupManifest,
    plainBytes: manifestPlain,
  );

  if (!plain && wrapped.existsSync()) {
    await addBlob(
      role: FolioCloudPackBlobRole.vaultKeys,
      plainBytes: await wrapped.readAsBytes(),
    );
  }

  await addBlob(
    role: FolioCloudPackBlobRole.vaultBin,
    plainBytes: vaultBinBytes,
  );

  if (modeFile.existsSync()) {
    await addBlob(
      role: FolioCloudPackBlobRole.vaultMode,
      plainBytes: await modeFile.readAsBytes(),
    );
  }

  for (final posix in attPaths) {
    final f = File(p.join(vaultDir.path, posix));
    if (!f.existsSync()) continue;
    await addBlob(
      role: FolioCloudPackBlobRole.attachment,
      plainBytes: await f.readAsBytes(),
      attachmentPosix: posix,
    );
  }

  final snapClear = FolioCloudPackSnapshotManifest(
    formatVersion: kFolioCloudPackFormatVersion,
    createdAtUtc: DateTime.now().toUtc().toIso8601String(),
    items: items,
    contentFingerprint: contentFingerprint,
  );

  return (blobs: prepared, manifest: snapClear);
}

bool _modeFileIsPlain(File modeFile) {
  if (!modeFile.existsSync()) return false;
  return modeFile.readAsStringSync().trim().toLowerCase() == 'plain';
}
