/// Regresión: unlockWithDeviceAuth/unlockWithPasskey deben rutar a
/// VaultFlowState.recovery ante un VaultCorruptionException, igual que ya
/// hacía unlockWithPassword. Antes del fix, ambos propagaban la excepción sin
/// capturarla (la sesión quedaba con DEK asignado pero sin transición de
/// estado), en vez de ofrecer la pantalla de recuperación.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/services/quick_unlock_storage.dart';
import 'package:folio/session/vault_session.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'
    show AuthMessages;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeQuickUnlockStorage extends QuickUnlockStorage {
  @override
  Future<Uint8List?> readDek(String vaultId) async =>
      Uint8List.fromList(List<int>.filled(32, 7));
}

class _FakeLocalAuthentication extends LocalAuthentication {
  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('Unlock corruption handling parity', () {
    late Directory mockedSupportDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_unlock_corruption_',
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

    /// Vault marcado v1 pero sin árbol legible: dispara VaultCorruptionException
    /// dentro de _ensureV1AndLoad (mismo camino de detección de corrupción
    /// que motivó el incidente de wipe por sync documentado en FEATURES.md).
    Future<void> setUpUnreadableV1Vault(String vaultId) async {
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      final vaultDir = await VaultPaths.vaultDirectory();
      await File(
        p.join(vaultDir.path, 'vault.format'),
      ).writeAsString('1', flush: true);
      // Sin repo/tree.json: loadFromTree() devuelve null.
    }

    test('unlockWithDeviceAuth routes to recovery on corruption', () async {
      const vaultId = 'unlock-corruption-device-auth';
      await setUpUnreadableV1Vault(vaultId);

      final session = VaultSession(
        quickUnlock: _FakeQuickUnlockStorage(),
        localAuth: _FakeLocalAuthentication(),
      );

      await session.unlockWithDeviceAuth();

      expect(session.state, VaultFlowState.recovery);
    });
  });
}
