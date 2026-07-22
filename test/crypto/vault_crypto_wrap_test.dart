import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/crypto/vault_crypto.dart';

/// Reconstruye un blob "legacy" (sin byte de versión, parámetros Argon2id
/// antiguos de OWASP-mínimo) tal como lo producía `wrapDek` antes de que se
/// introdujera el versionado del formato — para probar que `unwrapDek` sigue
/// pudiendo leerlo.
Future<Uint8List> _wrapLegacy({
  required List<int> dek,
  required String password,
  required List<int> salt,
}) async {
  final argon2Legacy = Argon2id(parallelism: 1, memory: 19456, iterations: 2, hashLength: 32);
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
  test('wrapDek/unwrapDek round-trips with the current (versioned) format', () async {
    final dek = VaultCrypto.randomBytes(VaultCrypto.dekLength);
    const password = 'correct horse battery staple';
    final wrapped = await VaultCrypto.wrapDek(dek: dek, password: password);
    final unwrapped = await VaultCrypto.unwrapDek(wrapped: wrapped, password: password);
    expect(unwrapped, equals(dek));
  });

  test('unwrapDek still reads a legacy (unversioned) blob', () async {
    final dek = VaultCrypto.randomBytes(VaultCrypto.dekLength);
    const password = 'legacy password';
    final salt = VaultCrypto.randomBytes(VaultCrypto.saltLength);
    final legacyWrapped = await _wrapLegacy(dek: dek, password: password, salt: salt);
    final unwrapped = await VaultCrypto.unwrapDek(wrapped: legacyWrapped, password: password);
    expect(unwrapped, equals(dek));
  });

  test('unwrapDek rejects a wrong password for both formats', () async {
    final dek = VaultCrypto.randomBytes(VaultCrypto.dekLength);
    final wrapped = await VaultCrypto.wrapDek(dek: dek, password: 'right-password');
    await expectLater(
      VaultCrypto.unwrapDek(wrapped: wrapped, password: 'wrong-password'),
      throwsA(isA<VaultCryptoException>()),
    );

    final salt = VaultCrypto.randomBytes(VaultCrypto.saltLength);
    final legacyWrapped = await _wrapLegacy(dek: dek, password: 'right-legacy', salt: salt);
    await expectLater(
      VaultCrypto.unwrapDek(wrapped: legacyWrapped, password: 'wrong-legacy'),
      throwsA(isA<VaultCryptoException>()),
    );
  });

  test('wrapDek output carries one extra leading byte versus the legacy format', () async {
    final dek = VaultCrypto.randomBytes(VaultCrypto.dekLength);
    const password = 'pw';
    final salt = VaultCrypto.randomBytes(VaultCrypto.saltLength);
    final wrapped = await VaultCrypto.wrapDek(dek: dek, password: password, salt: salt);
    final legacyWrapped = await _wrapLegacy(dek: dek, password: password, salt: salt);
    // Mismo salt/dek/password → mismo tamaño de ciphertext; el nuevo formato
    // debe ser exactamente 1 byte más largo (el byte de versión).
    expect(wrapped.length, equals(legacyWrapped.length + 1));
  });
}
