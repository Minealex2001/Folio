// Paso 3 del traslado de Cloud Backup a un isolate: garantiza que construir el
// pack vía `compute()` produce bytes IDÉNTICOS a construirlo en el isolate
// llamante. Compara, blob a blob: `blobId`, rol, orden, chunking, compresión y
// los BYTES de ciphertext. La única no-determinación preexistente (el timestamp
// `exportedAt` del blob `backupManifest` y `createdAtUtc` del manifiesto) se
// excluye explícitamente — no la introduce este cambio.
//
// Cubre libreta EN CLARO (pack key derivada en el UI isolate con
// `derivePlainPackKey`, igual que producción) y libreta CIFRADA (DEK bytes
// pasados al worker). También: una excepción dentro del worker se propaga y no
// deja pack a medias.
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/folio_cloud_pack_format.dart';
import 'package:folio/data/vault_backup.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/vault_pack/vault_pack_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shim de nivel superior equivalente al `_buildPackInIsolate` privado de
/// `folio_cloud_pack_sync.dart` (mismo cuerpo: `isPlain: false`, la pack key
/// llega ya en `keyMaterial`).
Future<({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest})>
    _buildPackShim(Map<String, Object?> msg) {
  return buildVaultPackSnapshotCore(
    vaultDirPath: msg['vaultDirPath'] as String,
    wrappedDekPath: msg['wrappedDekPath'] as String,
    vaultModePath: msg['vaultModePath'] as String,
    keyMaterial: msg['keyMaterial'] as Uint8List,
    isPlain: false,
    contentFingerprint: msg['contentFingerprint'] as String,
    vaultBinBytes: msg['vaultBinBytes'] as Uint8List,
  );
}

/// Igual que el shim pero revienta dentro del worker (ruta de vault inválida
/// tras marcar la libreta como cifrada sin `vault.keys`).
Future<({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest})>
    _buildPackShimThatThrows(Map<String, Object?> msg) {
  return buildVaultPackSnapshotCore(
    vaultDirPath: msg['vaultDirPath'] as String,
    wrappedDekPath: '${msg['vaultDirPath']}/does-not-exist.keys',
    vaultModePath: '${msg['vaultDirPath']}/does-not-exist.mode',
    keyMaterial: msg['keyMaterial'] as Uint8List,
    isPlain: false,
    contentFingerprint: msg['contentFingerprint'] as String,
    vaultBinBytes: msg['vaultBinBytes'] as Uint8List,
  );
}

Uint8List _fakeMedia(int bytes, int seed) {
  final r = Random(seed);
  final out = Uint8List(bytes);
  const chunk = 'RIFF....WEBP/JPEG payload chunk with some entropy ';
  for (var i = 0; i < bytes; i++) {
    out[i] = i % 64 == 0
        ? r.nextInt(256)
        : chunk.codeUnitAt(i % chunk.length) ^ (r.nextInt(8));
  }
  return out;
}

VaultPayload _payload({int pages = 60, int blocksPerPage = 20}) {
  return VaultPayload(
    pages: List.generate(pages, (pi) {
      final id = 'bi_page_$pi';
      return FolioPage(
        id: id,
        title: 'Página $pi',
        blocks: List.generate(blocksPerPage, (bi) {
          final todo = bi % 5 == 0;
          return FolioBlock(
            id: '${id}_b$bi',
            type: todo ? 'todo' : 'paragraph',
            text: 'Bloque $bi de la página $pi con texto de relleno repetido '
                'para dar trabajo real a gzip nivel 6.',
            checked: todo ? false : null,
          );
        }),
      );
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDir;
  const vaultId = 'cloudpack-byteid-vault';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDir = Directory.systemTemp.createTempSync('folio_cloudpack_byteid_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => supportDir.path,
    );
    VaultPaths.setActiveVaultId(vaultId);
    await VaultPaths.initVaultStorage(vaultId);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    VaultPaths.clearActiveVaultId();
    try {
      supportDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<String> vdirPath() async => (await VaultPaths.vaultDirectory()).path;
  Future<String> wrappedPath() async => (await VaultPaths.wrappedDekPath()).path;
  Future<String> modePath() async => (await VaultPaths.vaultModePath()).path;

  Future<void> writeAttachments(List<(int, int)> sizes) async {
    final adir = Directory('${await vdirPath()}/${VaultPaths.attachmentsDirName}')
      ..createSync(recursive: true);
    for (var i = 0; i < sizes.length; i++) {
      File('${adir.path}/att_$i.bin')
          .writeAsBytesSync(_fakeMedia(sizes[i].$1, sizes[i].$2));
    }
  }

  void expectByteIdentical(
    ({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest}) a,
    ({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest}) b,
  ) {
    expect(b.blobs.length, a.blobs.length, reason: 'nº de blobs');
    for (var i = 0; i < a.blobs.length; i++) {
      final ia = a.blobs[i].item;
      final ib = b.blobs[i].item;
      expect(ib.role, ia.role, reason: 'blob $i rol');
      expect(ib.relativePath, ia.relativePath, reason: 'blob $i path');
      expect(ib.chunkIndex, ia.chunkIndex, reason: 'blob $i chunkIndex');
      expect(ib.chunkCount, ia.chunkCount, reason: 'blob $i chunkCount');
      expect(ib.compression, ia.compression, reason: 'blob $i compresión');
      if (ia.role == FolioCloudPackBlobRole.backupManifest) {
        // Contiene `exportedAt` = DateTime.now(): no-determinista aun sin
        // isolate. Solo comprobamos que sigue en la misma posición/rol.
        continue;
      }
      expect(ib.blobId, ia.blobId, reason: 'blob $i blobId');
      expect(
        ib.blobId,
        equals(ia.blobId),
      );
      expect(
        b.blobs[i].cipherBytes,
        orderedEquals(a.blobs[i].cipherBytes),
        reason: 'blob $i ciphertext (rol ${ia.role.name})',
      );
    }
    // Items del manifiesto (mismos blobIds y orden, salvo el manifest-blob).
    expect(b.manifest.items.length, a.manifest.items.length);
    for (var i = 0; i < a.manifest.items.length; i++) {
      if (a.manifest.items[i].role == FolioCloudPackBlobRole.backupManifest) {
        continue;
      }
      expect(b.manifest.items[i].blobId, a.manifest.items[i].blobId,
          reason: 'manifest item $i');
    }
    expect(b.manifest.contentFingerprint, a.manifest.contentFingerprint);
    expect(b.manifest.formatVersion, a.manifest.formatVersion);
  }

  test('libreta EN CLARO: compute() == llamada directa (byte-identical)',
      () async {
    File('${await vdirPath()}/${VaultPaths.vaultModeFile}')
        .writeAsStringSync('plain');
    await writeAttachments([
      (250 * 1024, 1),
      (250 * 1024, 2),
      (8 * 1024 * 1024, 99), // WAV-like → se gzipea
    ]);
    final vbin = Uint8List.fromList(_payload().encodeUtf8());
    final fp = await computeVaultCloudPackContentFingerprint(vaultBinBytes: vbin);
    // Igual que producción para libreta en claro: pack key derivada en el UI
    // isolate, sus bytes van al worker.
    final packKeyBytes =
        Uint8List.fromList(await (await derivePlainPackKey(vbin)).extractBytes());

    final msg = <String, Object?>{
      'vaultBinBytes': vbin,
      'contentFingerprint': fp,
      'keyMaterial': packKeyBytes,
      'vaultDirPath': await vdirPath(),
      'wrappedDekPath': await wrappedPath(),
      'vaultModePath': await modePath(),
    };

    final direct = await buildVaultPackSnapshotCore(
      vaultDirPath: msg['vaultDirPath'] as String,
      wrappedDekPath: msg['wrappedDekPath'] as String,
      vaultModePath: msg['vaultModePath'] as String,
      keyMaterial: packKeyBytes,
      isPlain: false,
      contentFingerprint: fp,
      vaultBinBytes: vbin,
    );
    final viaIsolate = await compute(_buildPackShim, msg);

    expectByteIdentical(direct, viaIsolate);
    // Debe haber al menos: manifest + vaultBin + vaultMode + 3 adjuntos.
    expect(direct.blobs.length, greaterThanOrEqualTo(6));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('libreta CIFRADA (DEK bytes): compute() == llamada directa', () async {
    // `buildVaultPackSnapshotCore` no descifra `vault.keys`; solo necesita que
    // exista y que `vault.mode` no diga "plain". Con una DEK arbitraria basta
    // para verificar identidad de bytes entre ambos caminos.
    File(await wrappedPath()).writeAsBytesSync(_fakeMedia(512, 7));
    await writeAttachments([(1024 * 1024, 3), (1024 * 1024, 4)]);
    final vbin = _fakeMedia(2 * 1024 * 1024, 55); // "ciphertext" de vault.bin
    final fp = await computeVaultCloudPackContentFingerprint(vaultBinBytes: vbin);
    final dek =
        Uint8List.fromList(await (await AesGcm.with256bits().newSecretKey())
            .extractBytes());

    final msg = <String, Object?>{
      'vaultBinBytes': vbin,
      'contentFingerprint': fp,
      'keyMaterial': dek,
      'vaultDirPath': await vdirPath(),
      'wrappedDekPath': await wrappedPath(),
      'vaultModePath': await modePath(),
    };

    final direct = await buildVaultPackSnapshotCore(
      vaultDirPath: msg['vaultDirPath'] as String,
      wrappedDekPath: msg['wrappedDekPath'] as String,
      vaultModePath: msg['vaultModePath'] as String,
      keyMaterial: dek,
      isPlain: false,
      contentFingerprint: fp,
      vaultBinBytes: vbin,
    );
    final viaIsolate = await compute(_buildPackShim, msg);

    expectByteIdentical(direct, viaIsolate);
    // manifest + vault.keys + vaultBin + 2 adjuntos.
    expect(
      direct.blobs.any((b) => b.item.role == FolioCloudPackBlobRole.vaultKeys),
      isTrue,
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('libreta EN CLARO: derivePlainPackKey(UI) == packKey que deriva el worker',
      () async {
    // Elimina-2ª-serialización: el UI isolate deriva con derivePlainPackKey y
    // el worker (isPlain:true) deriva por su cuenta de vaultBinBytes → mismo
    // pack, mismos bytes.
    File('${await vdirPath()}/${VaultPaths.vaultModeFile}')
        .writeAsStringSync('plain');
    await writeAttachments([(300 * 1024, 11)]);
    final vbin = Uint8List.fromList(_payload(pages: 40).encodeUtf8());
    final fp = await computeVaultCloudPackContentFingerprint(vaultBinBytes: vbin);
    final packKeyBytes =
        Uint8List.fromList(await (await derivePlainPackKey(vbin)).extractBytes());

    final uiDerivedKey = await buildVaultPackSnapshotCore(
      vaultDirPath: await vdirPath(),
      wrappedDekPath: await wrappedPath(),
      vaultModePath: await modePath(),
      keyMaterial: packKeyBytes,
      isPlain: false,
      contentFingerprint: fp,
      vaultBinBytes: vbin,
    );
    final workerDerivedKey = await buildVaultPackSnapshotCore(
      vaultDirPath: await vdirPath(),
      wrappedDekPath: await wrappedPath(),
      vaultModePath: await modePath(),
      keyMaterial: Uint8List(0), // ignorado
      isPlain: true, // el worker deriva de vaultBinBytes
      contentFingerprint: fp,
      vaultBinBytes: vbin,
    );

    expectByteIdentical(uiDerivedKey, workerDerivedKey);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('excepción dentro del worker se propaga por compute() y no deja pack',
      () async {
    File('${await vdirPath()}/${VaultPaths.vaultModeFile}')
        .writeAsStringSync('plain');
    final vbin = Uint8List.fromList(_payload(pages: 10).encodeUtf8());
    final fp = await computeVaultCloudPackContentFingerprint(vaultBinBytes: vbin);
    final packKeyBytes =
        Uint8List.fromList(await (await derivePlainPackKey(vbin)).extractBytes());

    Object? caught;
    ({List<VaultPackPreparedBlob> blobs, FolioCloudPackSnapshotManifest manifest})?
        result;
    try {
      result = await compute(_buildPackShimThatThrows, <String, Object?>{
        'vaultBinBytes': vbin,
        'contentFingerprint': fp,
        'keyMaterial': packKeyBytes,
        'vaultDirPath': await vdirPath(),
      });
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull, reason: 'la excepción debe cruzar compute()');
    expect(result, isNull, reason: 'ningún pack parcial en caso de fallo');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
