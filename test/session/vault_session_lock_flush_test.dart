/// Regresión: lock() debía vaciar el guardado v1 pendiente incluso en
/// libretas sin cifrar. Antes del fix, `lock()` retornaba de inmediato para
/// libretas en claro (`if (!vaultUsesEncryption) return;`) sin cancelar ni
/// aplicar `_v1TreeSaveTimer` — si el usuario cambiaba de libreta
/// (`switchVault`) antes de que el debounce (450ms) expirara, ese guardado
/// pendiente podía completarse después de que `VaultPaths` ya apuntara a la
/// libreta nueva, escribiendo el contenido de la libreta abandonada dentro
/// del árbol de la libreta nueva.
///
/// Este test verifica el fix a nivel de `lock()`: tras editar una página en
/// una libreta v1 sin cifrar, `lock()` debe dejar el guardado ya aplicado en
/// disco (no pendiente) antes de retornar.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/session/vault_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('VaultSession.lock() flush anti-contaminación cruzada', () {
    late Directory mockedSupportDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_lock_flush_',
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

    test(
      'flushes pending v1 tree save before returning, even unencrypted',
      () async {
        const vaultAId = 'lock-flush-vault-a';
        VaultPaths.setActiveVaultId(vaultAId);
        await VaultPaths.initVaultStorage(vaultAId);
        final vaultADir = await VaultPaths.vaultDirectory();

        final session = VaultSession();
        session.debugMarkUnlockedForTests(formatVersion: 1);
        session.addPage(parentId: null);

        // El debounce v1 (450ms) todavía no expiró.
        expect(session.hasPendingDiskSave, isTrue);

        await session.lock();

        // Tras el fix, lock() no deja nada pendiente aunque la libreta no
        // esté cifrada — el guardado se aplicó de forma síncrona.
        expect(session.hasPendingDiskSave, isFalse);

        final onDisk = await VaultLocalStorage.loadFromTreeAt(vaultADir);
        expect(onDisk, isNotNull);
        expect(onDisk!.pages, hasLength(1));

        // Simula el resto de switchVault(): cambiar la libreta activa a B no
        // debe ver aparecer contenido de A, porque ya no queda timer vivo
        // que pudiera escribir tarde sobre el árbol de B.
        const vaultBId = 'lock-flush-vault-b';
        VaultPaths.setActiveVaultId(vaultBId);
        await VaultPaths.initVaultStorage(vaultBId);
        final vaultBDir = await VaultPaths.vaultDirectory();
        final bPayload = await VaultLocalStorage.loadFromTreeAt(vaultBDir);
        expect(bPayload, isNull);
      },
    );
  });
}
