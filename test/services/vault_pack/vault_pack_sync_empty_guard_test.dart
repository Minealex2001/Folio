/// Regresión: uploadOpenVaultPack no debe subir una libreta local vacía
/// sobre un destino que ya tiene un pack con contenido — este formato solo
/// dedupe por fingerprint, no compara "riqueza" (páginas), así que una
/// subida vacía terminaría expulsando la última copia buena tras suficientes
/// ciclos de GC por retención.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_backup.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/services/vault_pack/vault_pack_meta.dart';
import 'package:folio/services/vault_pack/vault_pack_sync.dart';
import 'package:folio/services/vault_pack/vault_pack_transport.dart';
import 'package:folio/session/vault_session.dart';

class _FakeTransport implements VaultPackTransport {
  _FakeTransport({this.meta});

  VaultPackMeta? meta;
  bool blobPut = false;
  bool metaWritten = false;

  @override
  String get label => 'fake';

  @override
  Future<VaultPackMeta?> readMeta() async => meta;

  @override
  Future<void> writeMeta(VaultPackMeta m) async {
    metaWritten = true;
    meta = m;
  }

  @override
  Future<bool> blobExists(String blobId) async => false;

  @override
  Future<void> putBlob(String blobId, Uint8List bytes) async {
    blobPut = true;
  }

  @override
  Future<Uint8List?> getBlob(String blobId) async => null;

  @override
  Future<void> deleteBlob(String blobId) async {}

  @override
  Future<void> putSnapshot(String relativePath, Uint8List bytes) async {}

  @override
  Future<Uint8List?> getSnapshot(String relativePath) async => null;

  @override
  Future<void> deleteSnapshot(String relativePath) async {}

  @override
  Future<void> putRestoreWrap(Uint8List bytes) async {}

  @override
  Future<Uint8List?> getRestoreWrap() async => null;

  @override
  Future<List<String>> listSnapshotPaths() async => const [];

  @override
  Future<List<String>> listBlobIds() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('uploadOpenVaultPack empty-vault guard', () {
    late Directory mockedSupportDir;

    setUp(() async {
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_pack_empty_guard_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            return mockedSupportDir.path;
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      VaultPaths.clearActiveVaultId();
      try {
        if (mockedSupportDir.existsSync()) {
          await mockedSupportDir.delete(recursive: true);
        }
      } catch (_) {
        // Windows puede tardar en liberar el handle del .bak recién
        // rotado por AtomicFileWriter; no es relevante para este test.
      }
    });

    test(
      'refuses to push an empty vault over an existing pack backup',
      () async {
        const vaultId = 'pack-empty-guard-vault';
        VaultPaths.setActiveVaultId(vaultId);
        await VaultPaths.initVaultStorage(vaultId);
        await VaultPaths.writeVaultMode('plain');

        final session = VaultSession();
        session.debugMarkUnlockedForTests();
        expect(session.pages, isEmpty);

        final transport = _FakeTransport(
          meta: const VaultPackMeta(
            formatVersion: VaultPackMeta.currentFormatVersion,
            contentFingerprint: 'previous-fp',
            headSnapshot: 'snapshots/snap-old.bin',
            updatedAtUtc: '2026-01-01T00:00:00Z',
          ),
        );

        await expectLater(
          uploadOpenVaultPack(session: session, transport: transport),
          throwsA(isA<VaultBackupException>()),
        );
        expect(transport.blobPut, isFalse);
        expect(transport.metaWritten, isFalse);
      },
    );
  });
}
