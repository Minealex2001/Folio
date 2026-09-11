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
///
/// Wrapper compatible con la API previa: resuelve rutas vía [VaultPaths] y
/// delega en [buildVaultPackSnapshotCore]. La lógica real (gzip / hashing /
/// AES-GCM / blobIds / orden / manifest / formato) vive en el núcleo, que es
/// invocable desde un isolate (no toca plugins).
Future<({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest})>
    buildVaultPackSnapshot({
  required SecretKey packKey,
  required String contentFingerprint,
  required Uint8List vaultBinBytes,
}) async {
  final wrapped = await VaultPaths.wrappedDekPath();
  final modeFile = await VaultPaths.vaultModePath();
  final vaultDir = await VaultPaths.vaultDirectory();
  final keyBytes = Uint8List.fromList(await packKey.extractBytes());
  return buildVaultPackSnapshotCore(
    vaultDirPath: vaultDir.path,
    wrappedDekPath: wrapped.path,
    vaultModePath: modeFile.path,
    keyMaterial: keyBytes,
    // El wrapper recibe una `packKey` ya derivada por el llamador: se usa
    // tal cual (`SecretKey(keyMaterial)`), sin re-derivar en el núcleo.
    isPlain: false,
    contentFingerprint: contentFingerprint,
    vaultBinBytes: vaultBinBytes,
  );
}

/// Núcleo reutilizable de [buildVaultPackSnapshot], parametrizado solo por
/// tipos transferibles entre isolates (rutas `String`, bytes, `bool`).
///
/// - [keyMaterial]: si [isPlain] es `false`, se usa como `SecretKey` directa
///   (DEK de la libreta cifrada, o pack key ya derivada). Si [isPlain] es
///   `true`, se **ignora** y la pack key se deriva aquí de [vaultBinBytes]
///   con la misma construcción que `VaultSession.cloudPackEncryptionKey()`
///   (evita serializar la libreta una segunda vez en el UI isolate).
///
/// NO cambia ninguna lógica de gzip / hashing / AES-GCM / blobIds / orden de
/// blobs / manifest / formato respecto a la versión previa.
Future<({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest})>
    buildVaultPackSnapshotCore({
  required String vaultDirPath,
  required String wrappedDekPath,
  required String vaultModePath,
  required Uint8List keyMaterial,
  required bool isPlain,
  required String contentFingerprint,
  required Uint8List vaultBinBytes,
  String attachmentsDirName = 'attachments', // == VaultPaths.attachmentsDirName
}) async {
  final wrapped = File(wrappedDekPath);
  final modeFile = File(vaultModePath);
  final plain = _modeFileIsPlain(modeFile);
  if (!plain && !wrapped.existsSync()) {
    throw VaultBackupException('No hay libreta para exportar.');
  }

  final packKey = isPlain
      ? await derivePlainPackKey(vaultBinBytes)
      : SecretKey(keyMaterial);

  final attDir = Directory(p.join(vaultDirPath, attachmentsDirName));
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
      attPaths.add('$attachmentsDirName/$rel');
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
    final f = File(p.join(vaultDirPath, posix));
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

/// Deriva la pack key de una libreta EN CLARO a partir de sus bytes
/// serializados. Misma construcción que `VaultSession.cloudPackEncryptionKey()`
/// (rama plana) — se duplica aquí porque un isolate no puede llamar a
/// `VaultSession`. NO cambia la semántica de cifrado del pack.
///
/// Pública para que el UI isolate pueda derivar la misma pack key sin volver a
/// serializar la libreta (la necesita para `restoreWrap` y cifrar/descifrar el
/// manifiesto), mientras el worker la deriva por su cuenta.
Future<SecretKey> derivePlainPackKey(Uint8List vaultBinBytes) async {
  final h = await Sha256().hash(vaultBinBytes);
  final h2 = await Sha256().hash(
    Uint8List.fromList(utf8.encode('FolioCloudPackPlainV1') + h.bytes),
  );
  return SecretKey(h2.bytes);
}
