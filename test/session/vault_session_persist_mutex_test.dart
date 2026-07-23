/// Regresión: dos escrituras v1 concurrentes (`persistNow`) no deben pisarse
/// sobre `repo.tmp`, y `lock()`/`flushPendingSave()` deben esperar a que
/// cualquier escritura "suelta" (disparada por el debounce y no esperada por
/// nadie, `unawaited`) termine antes de devolver el control — de lo
/// contrario `switchVault()` puede cambiar la libreta activa mientras esa
/// escritura suelta sigue en vuelo, y cuando por fin resuelve el directorio
/// destino, escribe el contenido de la libreta vieja dentro de la nueva
/// (contaminación cruzada real observada en producción).
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

  group('VaultSession v1 persist mutex', () {
    late Directory mockedSupportDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_persist_mutex_',
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
      } catch (_) {}
    });

    test(
      'two concurrent persistNow calls do not race on repo.tmp',
      () async {
        const vaultId = 'persist-mutex-concurrent';
        VaultPaths.setActiveVaultId(vaultId);
        await VaultPaths.initVaultStorage(vaultId);

        final session = VaultSession();
        session.debugMarkUnlockedForTests(formatVersion: 1);
        session.addPage(parentId: null);
        final pageId = session.selectedPage!.id;
        session.updateBlockText(
          pageId,
          session.selectedPage!.blocks.first.id,
          'contenido concurrente',
        );

        // Simula la llamada "suelta" del debounce (no se espera) + una
        // llamada explícita casi simultánea (p. ej. flushPendingSave desde
        // lock()) — antes del fix, ambas escribían repo.tmp a la vez.
        final calls = await Future.wait([
          session.persistNow(),
          session.persistNow(),
        ]);
        expect(calls, hasLength(2)); // ambas completaron sin lanzar

        final vaultDir = await VaultPaths.vaultDirectory();
        final loaded = await VaultLocalStorage.loadFromTreeAt(vaultDir);
        expect(loaded, isNotNull);
        expect(loaded!.pages, hasLength(1));
        expect(loaded.pages.first.blocks.first.text, 'contenido concurrente');
      },
    );

    test(
      'lock() waits for an in-flight persist before returning (no cross-vault leak)',
      () async {
        const vaultId = 'persist-mutex-lock-wait';
        VaultPaths.setActiveVaultId(vaultId);
        await VaultPaths.initVaultStorage(vaultId);

        final session = VaultSession();
        session.debugMarkUnlockedForTests(formatVersion: 1);
        session.addPage(parentId: null);
        session.updateBlockText(
          session.selectedPage!.id,
          session.selectedPage!.blocks.first.id,
          'edición justo antes de bloquear',
        );

        // Simula el timer de debounce disparándose "suelto" (unawaited) justo
        // antes de que el usuario cambie de libreta.
        final stray = session.persistNow();

        // lock() debe esperar esta escritura suelta antes de devolver el
        // control — si no lo hace, un switchVault() posterior podría cambiar
        // VaultPaths.activeVaultId mientras `stray` sigue resolviendo su
        // directorio destino.
        await session.lock();
        await stray; // no debería quedar nada pendiente a estas alturas.

        expect(session.hasPendingDiskSave, isFalse);

        final vaultDir = await VaultPaths.vaultDirectory();
        final loaded = await VaultLocalStorage.loadFromTreeAt(vaultDir);
        expect(loaded, isNotNull);
        expect(loaded!.pages, hasLength(1));
        expect(
          loaded.pages.first.blocks.first.text,
          'edición justo antes de bloquear',
        );
      },
    );
  });
}
