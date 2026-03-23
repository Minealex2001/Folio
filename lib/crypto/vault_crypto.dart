import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Argon2id + AES-256-GCM for Folio vault (DEK wrapping and payload encryption).
class VaultCrypto {
  VaultCrypto._();

  static final _random = Random.secure();
  static final Argon2id _argon2 = Argon2id(
    parallelism: 1,
    memory: 19456,
    iterations: 2,
    hashLength: 32,
  );
  static final AesGcm _aes = AesGcm.with256bits();

  static const int saltLength = 16;
  static const int dekLength = 32;
  static const int nonceLength = 12;

  static Uint8List randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  static Future<SecretKey> deriveKekFromPassword({
    required String password,
    required List<int> salt,
  }) async {
    return _argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Returns concatenation: [salt (16)][nonce (12)][ciphertext+mac] wrapping [dek].
  static Future<Uint8List> wrapDek({
    required List<int> dek,
    required String password,
    List<int>? salt,
  }) async {
    final s = salt != null ? Uint8List.fromList(salt) : randomBytes(saltLength);
    final kek = await deriveKekFromPassword(password: password, salt: s);
    final nonce = randomBytes(nonceLength);
    final box = await _aes.encrypt(dek, secretKey: kek, nonce: nonce);
    final out = BytesBuilder(copy: false);
    out.add(s);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  static Future<Uint8List> unwrapDek({
    required List<int> wrapped,
    required String password,
  }) async {
    if (wrapped.length < saltLength + nonceLength + 16) {
      throw VaultCryptoException('Datos de clave corruptos');
    }
    final s = wrapped.sublist(0, saltLength);
    final nonce = wrapped.sublist(saltLength, saltLength + nonceLength);
    final macStart = wrapped.length - 16;
    final cipher = wrapped.sublist(saltLength + nonceLength, macStart);
    final mac = Mac(wrapped.sublist(macStart));
    final kek = await deriveKekFromPassword(password: password, salt: s);
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: mac),
        secretKey: kek,
      );
      return Uint8List.fromList(clear);
    } on Object {
      throw VaultCryptoException('Contraseña incorrecta o datos dañados');
    }
  }

  /// Encrypt [plain] with DEK. Format: [nonce 12][cipher][mac 16]
  static Future<Uint8List> encryptPayload({
    required List<int> plain,
    required SecretKey dek,
  }) async {
    final nonce = randomBytes(nonceLength);
    final box = await _aes.encrypt(plain, secretKey: dek, nonce: nonce);
    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  static Future<Uint8List> decryptPayload({
    required List<int> blob,
    required SecretKey dek,
  }) async {
    if (blob.length < nonceLength + 16) {
      throw VaultCryptoException('Cofre corrupto');
    }
    final nonce = blob.sublist(0, nonceLength);
    final macStart = blob.length - 16;
    final cipher = blob.sublist(nonceLength, macStart);
    final mac = Mac(blob.sublist(macStart));
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: dek,
    );
    return Uint8List.fromList(clear);
  }

  static Future<SecretKey> dekFromBytes(List<int> bytes) async {
    if (bytes.length != dekLength) {
      throw VaultCryptoException('DEK inválida');
    }
    return SecretKey(bytes);
  }
}

class VaultCryptoException implements Exception {
  VaultCryptoException(this.message);
  final String message;

  @override
  String toString() => message;
}
