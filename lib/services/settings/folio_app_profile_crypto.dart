import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../crypto/vault_crypto.dart';
import '../folio_cloud/folio_cloud_pack_crypto.dart';

/// Clave AES del perfil de ajustes de la cuenta (no depende del vault).
class FolioAppProfileCrypto {
  FolioAppProfileCrypto({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _localKeyPrefix = 'folio_app_profile_pack_key_v1_';
  static const _prefsKeyPrefix = 'folio_app_profile_pack_key_prefs_v1_';
  static const _magic = <int>[
    0x66, 0x6f, 0x6c, 0x69, 0x6f, 0x61, 0x70, 0x6b, 0x31, // folioapk1
  ];

  String _localKey(String uid) => '$_localKeyPrefix$uid';
  String _prefsKey(String uid) => '$_prefsKeyPrefix$uid';

  Future<String?> _readLocalRaw(String uid) async {
    try {
      final local = await _storage.read(key: _localKey(uid));
      if (local != null && local.isNotEmpty) return local;
    } catch (e) {
      debugPrint('[settings_sync] secure storage read failed: $e');
    }
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_prefsKey(uid));
      if (v != null && v.isNotEmpty) return v;
    } catch (e) {
      debugPrint('[settings_sync] prefs key read failed: $e');
    }
    return null;
  }

  Future<void> _writeLocalRaw(String uid, String b64) async {
    var wroteSecure = false;
    try {
      await _storage.write(key: _localKey(uid), value: b64);
      wroteSecure = true;
    } catch (e) {
      debugPrint('[settings_sync] secure storage write failed: $e');
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey(uid), b64);
    } catch (e) {
      debugPrint('[settings_sync] prefs key write failed: $e');
      if (!wroteSecure) rethrow;
    }
  }

  /// Obtiene o crea la clave local. Si hay [restoreWrapB64] + [password], restaura.
  Future<({SecretKey key, Uint8List? newWrapB64})> ensurePackKey({
    required String uid,
    String? restoreWrapB64,
    String? restorePassword,
  }) async {
    final local = await _readLocalRaw(uid);
    if (local != null && local.isNotEmpty) {
      try {
        final bytes = base64Decode(local);
        if (bytes.length == 32) {
          return (key: await VaultCrypto.dekFromBytes(bytes), newWrapB64: null);
        }
      } catch (_) {}
    }

    final wrap = restoreWrapB64?.trim() ?? '';
    final pw = restorePassword ?? '';
    if (wrap.isNotEmpty) {
      final wrapped = base64Decode(wrap);
      final plainMarker = _tryUnwrapAccountMarker(wrapped);
      final dek = plainMarker ??
          await VaultCrypto.unwrapDek(wrapped: wrapped, password: pw);
      await _writeLocalRaw(uid, base64Encode(dek));
      return (key: await VaultCrypto.dekFromBytes(dek), newWrapB64: null);
    }

    final raw = VaultCrypto.randomBytes(32);
    await _writeLocalRaw(uid, base64Encode(raw));
    // Sin passphrase: formato ligero (evita Argon2 ~19 MiB en el hilo UI).
    final wrapBytes = pw.isEmpty
        ? _wrapAccountMarker(raw)
        : await VaultCrypto.wrapDek(dek: raw, password: pw);
    return (key: await VaultCrypto.dekFromBytes(raw), newWrapB64: wrapBytes);
  }

  /// `folioapk1` + DEK(32) + padding hasta ≥44 bytes (validación del callable).
  static Uint8List _wrapAccountMarker(List<int> dek) {
    final out = Uint8List(48);
    out.setAll(0, _magic);
    out.setAll(_magic.length, dek);
    // bytes 41..47: padding fijo
    for (var i = _magic.length + dek.length; i < out.length; i++) {
      out[i] = 0xa5;
    }
    return out;
  }

  static Uint8List? _tryUnwrapAccountMarker(List<int> wrapped) {
    if (wrapped.length < _magic.length + 32) return null;
    for (var i = 0; i < _magic.length; i++) {
      if (wrapped[i] != _magic[i]) return null;
    }
    return Uint8List.fromList(
      wrapped.sublist(_magic.length, _magic.length + 32),
    );
  }

  static Future<Uint8List> encryptProfile({
    required List<int> plain,
    required SecretKey packKey,
  }) =>
      cloudPackEncryptBytes(plain: plain, packKey: packKey);

  static Future<Uint8List> decryptProfile({
    required List<int> blob,
    required SecretKey packKey,
  }) =>
      cloudPackDecryptBytes(blob: blob, packKey: packKey);

  static Future<String> fingerprint(List<int> plain) async {
    final h = await Sha256().hash(plain);
    return h.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String? currentUid() => FirebaseAuth.instance.currentUser?.uid;
}
