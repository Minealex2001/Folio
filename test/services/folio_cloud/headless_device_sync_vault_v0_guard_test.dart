/// Regresión: HeadlessDeviceSyncVault.savePayload, en la rama v0 (libreta
/// aún no migrada localmente al árbol), no debe sobrescribir `vault.bin` con
/// un payload vacío cuando ya había páginas. Este camino solo se ejercita en
/// un dispositivo que hace sync headless sin haberse desbloqueado nunca en
/// UI localmente (la migración a v1 es obligatoria al desbloquear/bootstrap).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/storage/vault_storage.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/folio_cloud/headless_device_sync_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('HeadlessDeviceSyncVault.savePayload anti-wipe guard (v0)', () {
    late Directory mockedSupportDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_headless_v0_guard_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            return mockedSupportDir.path;
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (mockedSupportDir.existsSync()) {
        await mockedSupportDir.delete(recursive: true);
      }
    });

    test('refuses to replace a non-empty legacy vault.bin with an empty payload', () async {
      const vaultId = 'headless-v0-guard-vault';
      await VaultStorage.instance.initVault(vaultId);
      await VaultStorage.instance.writeVaultFile(
        vaultId,
        VaultPaths.vaultModeFile,
        Uint8List.fromList(utf8.encode('plain')),
      );

      final sync = HeadlessDeviceSyncVault();
      final packKey = SecretKey(List<int>.filled(32, 7));

      final original = VaultPayload(
        pages: [
          FolioPage(
            id: 'p1',
            title: 'Importante',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'ok')],
          ),
        ],
      );
      await sync.savePayload(vaultId: vaultId, packKey: packKey, payload: original);

      // No debe lanzar: la libreta sigue en v0 (sin vault.format), así que el
      // guard debe actuar en silencio (log + skip), no como excepción — el
      // headless sync no puede permitirse romper el ciclo por esto.
      await sync.savePayload(
        vaultId: vaultId,
        packKey: packKey,
        payload: VaultPayload(pages: const []),
      );

      final stillThere = await sync.loadPayload(vaultId, packKey);
      expect(stillThere, isNotNull);
      expect(stillThere!.pages, hasLength(1));
      expect(stillThere.pages.first.title, 'Importante');
    });

    test('allows the first write of a genuinely new empty vault', () async {
      const vaultId = 'headless-v0-guard-fresh';
      await VaultStorage.instance.initVault(vaultId);
      await VaultStorage.instance.writeVaultFile(
        vaultId,
        VaultPaths.vaultModeFile,
        Uint8List.fromList(utf8.encode('plain')),
      );

      final sync = HeadlessDeviceSyncVault();
      final packKey = SecretKey(List<int>.filled(32, 7));

      await sync.savePayload(
        vaultId: vaultId,
        packKey: packKey,
        payload: VaultPayload(pages: const []),
      );

      final loaded = await sync.loadPayload(vaultId, packKey);
      expect(loaded, isNotNull);
      expect(loaded!.pages, isEmpty);
    });
  });
}
