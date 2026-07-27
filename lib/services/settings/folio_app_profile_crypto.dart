import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../crypto/vault_crypto.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_identity.dart';
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
      AppLogger.warn(
        'Secure storage read failed',
        tag: 'settings_sync',
        context: {'error': '$e'},
      );
    }
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_prefsKey(uid));
      if (v != null && v.isNotEmpty) return v;
    } catch (e) {
      AppLogger.warn(
        'Prefs key read failed',
        tag: 'settings_sync',
        context: {'error': '$e'},
      );
    }
    return null;
  }

  Future<void> _writeLocalRaw(String uid, String b64) async {
    var wroteSecure = false;
    try {
      await _storage.write(key: _localKey(uid), value: b64);
      wroteSecure = true;
    } catch (e) {
      AppLogger.warn(
        'Secure storage write failed',
        tag: 'settings_sync',
        context: {'error': '$e'},
      );
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey(uid), b64);
    } catch (e) {
      AppLogger.warn(
        'Prefs key write failed',
        tag: 'settings_sync',
        context: {'error': '$e'},
      );
      if (!wroteSecure) rethrow;
    }
  }

  /// `true` si ya hay una clave cacheada para este dispositivo/cuenta —
  /// permite evitar llamar al callable de restore-wrap quando no hace falta.
  Future<bool> hasCachedLocalKey(String uid) async {
    final local = await _readLocalRaw(uid);
    return local != null && local.isNotEmpty;
  }

  /// Fuerza adoptar la clave canónica de la cuenta (ignora la clave local ya
  /// cacheada) y la persiste, sobrescribiendo cualquier clave previa.
  ///
  /// Se usa cuando descifrar con la clave local falla con un error de MAC:
  /// indica que este dispositivo minó su propia clave en una carrera del
  /// primer push/pull (dos dispositivos "primeros" a la vez) y quedó
  /// huérfano respecto al resto de la cuenta. Solo funciona con wraps sin
  /// contraseña (marcador plano); si el wrap remoto está protegido con
  /// contraseña hace falta [restorePassword].
  Future<SecretKey?> adoptCanonicalKey({
    required String uid,
    required String restoreWrapB64,
    String restorePassword = '',
  }) async {
    final wrap = restoreWrapB64.trim();
    if (wrap.isEmpty) return null;
    try {
      final wrapped = base64Decode(wrap);
      final dek = await _unwrapRestoreWrap(
        wrapped,
        password: restorePassword,
      );
      if (dek == null) return null;
      await _writeLocalRaw(uid, base64Encode(dek));
      return VaultCrypto.dekFromBytes(dek);
    } catch (_) {
      return null;
    }
  }

  /// Emite el wrap de la clave local actual (o crea una) para subirlo al
  /// servidor. Usado al reclamar la cuenta con «mantener local».
  Future<({SecretKey key, Uint8List wrapB64})> exportLocalKeyWrap({
    required String uid,
    String password = '',
  }) async {
    final local = await _readLocalRaw(uid);
    Uint8List dek;
    if (local != null && local.isNotEmpty) {
      try {
        final bytes = base64Decode(local);
        if (bytes.length == 32) {
          dek = Uint8List.fromList(bytes);
        } else {
          dek = VaultCrypto.randomBytes(32);
          await _writeLocalRaw(uid, base64Encode(dek));
        }
      } catch (_) {
        dek = VaultCrypto.randomBytes(32);
        await _writeLocalRaw(uid, base64Encode(dek));
      }
    } else {
      dek = VaultCrypto.randomBytes(32);
      await _writeLocalRaw(uid, base64Encode(dek));
    }
    final wrapBytes = password.isEmpty
        ? _wrapAccountMarker(dek)
        : await VaultCrypto.wrapDek(dek: dek, password: password);
    return (key: await VaultCrypto.dekFromBytes(dek), wrapB64: wrapBytes);
  }

  /// Obtiene o crea la clave local. Si hay [restoreWrapB64] + [password], restaura.
  ///
  /// Con [preferRemoteWrap] = true, si el servidor ya tiene wrap se adopta esa
  /// clave aunque exista caché local distinta — evita cifrar packs nuevos con
  /// una clave huérfana mientras el wrap de cuenta sigue siendo otro.
  Future<({SecretKey key, Uint8List? newWrapB64})> ensurePackKey({
    required String uid,
    String? restoreWrapB64,
    String? restorePassword,
    bool preferRemoteWrap = false,
  }) async {
    final wrap = restoreWrapB64?.trim() ?? '';
    final pw = restorePassword ?? '';

    if (preferRemoteWrap && wrap.isNotEmpty) {
      final dek = await _unwrapRestoreWrap(
        base64Decode(wrap),
        password: pw,
      );
      if (dek != null) {
        await _writeLocalRaw(uid, base64Encode(dek));
        return (key: await VaultCrypto.dekFromBytes(dek), newWrapB64: null);
      }
    }

    final local = await _readLocalRaw(uid);
    if (local != null && local.isNotEmpty) {
      try {
        final bytes = base64Decode(local);
        if (bytes.length == 32) {
          return (
            key: await VaultCrypto.dekFromBytes(bytes),
            newWrapB64: null,
          );
        }
      } catch (_) {}
    }

    if (wrap.isNotEmpty) {
      final dek = await _unwrapRestoreWrap(
        base64Decode(wrap),
        password: pw,
      );
      if (dek == null) {
        throw StateError('App profile restore wrap could not be unwrapped');
      }
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

  Future<Uint8List?> _unwrapRestoreWrap(
    List<int> wrapped, {
    required String password,
  }) async {
    final plainMarker = _tryUnwrapAccountMarker(wrapped);
    if (plainMarker != null) return plainMarker;
    if (password.isEmpty) return null;
    try {
      return await VaultCrypto.unwrapDek(wrapped: wrapped, password: password);
    } catch (_) {
      return null;
    }
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

  static String? currentUid() => folioCloudCurrentUid();
}
