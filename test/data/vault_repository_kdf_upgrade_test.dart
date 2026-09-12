// Perfil Argon2id elegible por el usuario ("Balanceado" v1 / "Reforzado" v2):
// - upgradeKdfIfNeeded solo cierra el hueco legacy->Balanceado, nunca fuerza
//   a nadie ya en v1/v2 hacia el perfil reforzado.
// - upgradeToHardenedProfile es la acción explícita del usuario para subir a
//   v2, y propaga errores (a diferencia de upgradeKdfIfNeeded).
// - rewrapDek (usado por changeMasterPassword) preserva el perfil actual por
//   defecto, para no re-endurecer en silencio al cambiar de contraseña.
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/crypto/vault_crypto.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/data/vault_repository.dart';

/// Reconstruye un blob "legacy" a mano (mismo formato que producía `wrapDek`
/// antes de introducirse el versionado), igual que
/// `test/crypto/vault_crypto_wrap_test.dart`.
Future<Uint8List> _wrapLegacy({
  required List<int> dek,
  required String password,
  required List<int> salt,
}) async {
  final argon2Legacy = Argon2id(
    parallelism: 1,
    memory: 19456,
    iterations: 2,
    hashLength: 32,
  );
  final kek = await argon2Legacy.deriveKey(
    secretKey: SecretKey(password.codeUnits),
    nonce: salt,
  );
  final aes = AesGcm.with256bits();
  final nonce = VaultCrypto.randomBytes(VaultCrypto.nonceLength);
  final box = await aes.encrypt(dek, secretKey: kek, nonce: nonce);
  final out = BytesBuilder(copy: false);
  out.add(salt);
  out.add(box.nonce);
  out.add(box.cipherText);
  out.add(box.mac.bytes);
  return out.takeBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('VaultRepository KDF profile management', () {
    late Directory mockedSupportDir;
    final repo = VaultRepository();
    const password = 'correct horse battery staple';

    setUp(() async {
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_kdf_upgrade_',
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

    Future<Uint8List> setUpLegacyVault(String vaultId) async {
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      final dek = VaultCrypto.randomBytes(VaultCrypto.dekLength);
      final salt = VaultCrypto.randomBytes(VaultCrypto.saltLength);
      final legacyWrapped = await _wrapLegacy(
        dek: dek,
        password: password,
        salt: salt,
      );
      await VaultPaths.writeWrappedDek(legacyWrapped);
      await VaultPaths.writeVaultMode('encrypted');
      return dek;
    }

    Future<Uint8List> setUpBalancedVault(String vaultId) async {
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      final dek = VaultCrypto.randomBytes(VaultCrypto.dekLength);
      final wrapped = await VaultCrypto.wrapDek(
        dek: dek,
        password: password,
        version: VaultCrypto.profileBalanced,
      );
      await VaultPaths.writeWrappedDek(wrapped);
      await VaultPaths.writeVaultMode('encrypted');
      return dek;
    }

    group('upgradeKdfIfNeeded (auto-heal silencioso al desbloquear)', () {
      test('sube una libreta legacy a Balanceado (v1), no a Reforzado', () async {
        final dek = await setUpLegacyVault('kdf-upgrade-legacy');

        final before = await VaultPaths.readWrappedDek();
        expect(VaultCrypto.wrapVersion(before!), equals(0));

        await repo.upgradeKdfIfNeeded(password);

        final after = await VaultPaths.readWrappedDek();
        expect(VaultCrypto.wrapVersion(after!), equals(VaultCrypto.profileBalanced));

        final unlockedDek = await repo.unlockWithPassword(password);
        expect(unlockedDek, equals(dek));
      });

      test('es no-op si la libreta legacy ya se subió a Balanceado', () async {
        await setUpLegacyVault('kdf-upgrade-already-balanced');
        await repo.upgradeKdfIfNeeded(password);
        final upgraded = await VaultPaths.readWrappedDek();

        await repo.upgradeKdfIfNeeded(password);
        final unchanged = await VaultPaths.readWrappedDek();

        expect(unchanged, equals(upgraded));
      });

      test('no toca una libreta ya en Balanceado (no la fuerza a Reforzado)', () async {
        await setUpBalancedVault('kdf-upgrade-stays-balanced');
        final before = await VaultPaths.readWrappedDek();

        await repo.upgradeKdfIfNeeded(password);

        final after = await VaultPaths.readWrappedDek();
        expect(after, equals(before));
        expect(VaultCrypto.wrapVersion(after!), equals(VaultCrypto.profileBalanced));
      });
    });

    group('upgradeToHardenedProfile (acción explícita del usuario)', () {
      test('sube una libreta Balanceada a Reforzado sin cambiar el DEK', () async {
        final dek = await setUpBalancedVault('kdf-hardened-from-balanced');

        await repo.upgradeToHardenedProfile(password);

        final after = await VaultPaths.readWrappedDek();
        expect(VaultCrypto.wrapVersion(after!), equals(VaultCrypto.profileHardened));
        final unlockedDek = await repo.unlockWithPassword(password);
        expect(unlockedDek, equals(dek));
      });

      test('propaga el error con contraseña incorrecta y no toca vault.keys', () async {
        await setUpBalancedVault('kdf-hardened-wrong-password');
        final before = await VaultPaths.readWrappedDek();

        await expectLater(
          repo.upgradeToHardenedProfile('wrong password'),
          throwsA(anything),
        );

        final after = await VaultPaths.readWrappedDek();
        expect(after, equals(before));
      });
    });

    group('rewrapDek preserva el perfil por defecto (cambio de contraseña)', () {
      test('cambiar de contraseña sin targetVersion no re-endurece una libreta Balanceada', () async {
        await setUpBalancedVault('kdf-rewrap-preserves-balanced');

        await repo.rewrapDek(currentPassword: password, newPassword: 'new password');

        final after = await VaultPaths.readWrappedDek();
        expect(VaultCrypto.wrapVersion(after!), equals(VaultCrypto.profileBalanced));
        final unlockedDek = await repo.unlockWithPassword('new password');
        expect(unlockedDek, isNotNull);
      });
    });

    group('createVault kdfProfile', () {
      test('kdfProfile: profileBalanced produce un vault.keys v1', () async {
        VaultPaths.setActiveVaultId('kdf-create-balanced');
        await VaultPaths.initVaultStorage('kdf-create-balanced');
        await repo.createVault(
          password: password,
          kdfProfile: VaultCrypto.profileBalanced,
        );
        final wrapped = await VaultPaths.readWrappedDek();
        expect(VaultCrypto.wrapVersion(wrapped!), equals(VaultCrypto.profileBalanced));
      });

      test('sin kdfProfile, sigue produciendo el perfil reforzado por defecto', () async {
        VaultPaths.setActiveVaultId('kdf-create-default');
        await VaultPaths.initVaultStorage('kdf-create-default');
        await repo.createVault(password: password);
        final wrapped = await VaultPaths.readWrappedDek();
        expect(VaultCrypto.wrapVersion(wrapped!), equals(VaultCrypto.currentWrapVersion));
      });
    });

    group('currentKdfProfile', () {
      test('devuelve el byte de versión de vault.keys', () async {
        await setUpBalancedVault('kdf-current-profile-balanced');
        expect(await repo.currentKdfProfile(), equals(VaultCrypto.profileBalanced));
      });

      test('devuelve null si no hay vault.keys (libreta en texto plano)', () async {
        VaultPaths.setActiveVaultId('kdf-current-profile-plain');
        await VaultPaths.initVaultStorage('kdf-current-profile-plain');
        expect(await repo.currentKdfProfile(), isNull);
      });
    });
  });
}
