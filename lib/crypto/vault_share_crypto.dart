import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/errors/folio_exception.dart';

/// Wrap/unwrap de la clave de sync de una libreta compartida (mismo patrón que collab).
class VaultShareCrypto {
  VaultShareCrypto._();

  static final _random = Random.secure();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static const int _nonceLength = 12;
  static const int _keyLength = 32;

  static String normalizeShareCode(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();

  static String generateShareCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer();
    for (var i = 0; i < 10; i++) {
      buf.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  static Future<SecretKey> _deriveWrapKey({
    required String shareCodeNormalized,
    required String ownerUid,
    required String vaultId,
  }) async {
    final out = await _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(shareCodeNormalized)),
      nonce: utf8.encode('$ownerUid/$vaultId'),
      info: utf8.encode('FolioVaultShareWrapKey/v1'),
    );
    return SecretKey(out.bytes);
  }

  static Future<Uint8List> _seal({
    required List<int> plain,
    required SecretKey key,
  }) async {
    final nonce = _randomBytes(_nonceLength);
    final box = await _aes.encrypt(plain, secretKey: key, nonce: nonce);
    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  static Future<Uint8List> _open({
    required List<int> blob,
    required SecretKey key,
  }) async {
    if (blob.length < _nonceLength + 16) {
      throw VaultShareCryptoException('Datos cifrados incompletos');
    }
    final nonce = blob.sublist(0, _nonceLength);
    final macStart = blob.length - 16;
    final cipher = blob.sublist(_nonceLength, macStart);
    final mac = Mac(blob.sublist(macStart));
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on Object {
      throw VaultShareCryptoException('No se pudo descifrar (código incorrecto)');
    }
  }

  /// Envuelve bytes de clave (DEK o pack key, 32 bytes) con el share code.
  static Future<String> wrapKeyB64({
    required List<int> keyBytes,
    required String shareCode,
    required String ownerUid,
    required String vaultId,
  }) async {
    if (keyBytes.length != _keyLength) {
      throw VaultShareCryptoException('Clave inválida');
    }
    final wrap = await _deriveWrapKey(
      shareCodeNormalized: normalizeShareCode(shareCode),
      ownerUid: ownerUid,
      vaultId: vaultId,
    );
    final sealed = await _seal(plain: keyBytes, key: wrap);
    return base64Encode(sealed);
  }

  static Future<Uint8List> unwrapKeyB64({
    required String wrappedB64,
    required String shareCode,
    required String ownerUid,
    required String vaultId,
  }) async {
    late final List<int> wrapped;
    try {
      wrapped = base64Decode(wrappedB64);
    } on Object {
      throw VaultShareCryptoException('Clave envuelta inválida');
    }
    final wrap = await _deriveWrapKey(
      shareCodeNormalized: normalizeShareCode(shareCode),
      ownerUid: ownerUid,
      vaultId: vaultId,
    );
    final clear = await _open(blob: wrapped, key: wrap);
    if (clear.length != _keyLength) {
      throw VaultShareCryptoException('Clave corrupta');
    }
    return clear;
  }
}

class VaultShareCryptoException extends FolioException {
  VaultShareCryptoException(super.message);
}
