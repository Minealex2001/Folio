/// Regresión: VaultRepository.savePayload (formato v0, `vault.bin`) no debe
/// sobrescribir una libreta con páginas por un payload vacío. A diferencia
/// del árbol v1 (VaultLocalStorage.decomposeAndStoreAt), este camino no tenía
/// ningún guard — solo estaba protegido por el `.bak` de una generación.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/data/vault_repository.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('VaultRepository.savePayload anti-wipe guard (v0)', () {
    late Directory mockedSupportDir;

    setUp(() async {
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_repo_empty_overwrite_',
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
      if (mockedSupportDir.existsSync()) {
        await mockedSupportDir.delete(recursive: true);
      }
    });

    test('refuses to replace a non-empty vault.bin with an empty payload', () async {
      const vaultId = 'repo-empty-overwrite-plain';
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      await VaultPaths.writeVaultMode('plain');

      final repo = VaultRepository();
      final original = VaultPayload(
        pages: [
          FolioPage(
            id: 'p1',
            title: 'Importante',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'ok')],
          ),
        ],
      );
      await repo.savePayload(original, null);

      await expectLater(
        () => repo.savePayload(VaultPayload(pages: const []), null),
        throwsA(isA<VaultEmptyOverwriteException>()),
      );

      final stillThere = await repo.loadPayload(null);
      expect(stillThere.pages, hasLength(1));
      expect(stillThere.pages.first.title, 'Importante');
    });

    test('allows the first write of a genuinely new empty vault', () async {
      const vaultId = 'repo-empty-overwrite-fresh';
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      await VaultPaths.writeVaultMode('plain');

      final repo = VaultRepository();
      await repo.savePayload(VaultPayload(pages: const []), null);

      final loaded = await repo.loadPayload(null);
      expect(loaded.pages, isEmpty);
    });
  });
}
