import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../crypto/vault_crypto.dart';
import '../app_logger.dart';
import 'folio_cloud_callable.dart';

/// Cache de material de cifrado para device-sync **sin** desbloquear la libreta.
///
/// - Libreta cifrada: DEK (32 bytes), se guarda al desbloquear.
/// - Libreta en claro: clave determinista por cuenta+vaultId (misma en todos
///   los dispositivos) o, en legado, clave estable aleatoria en caché.
///
/// Vive en el almacén seguro del SO. Necesario para sync tipo Drive en
/// segundo plano mientras la UI está en pantalla de bloqueo.
class DeviceSyncKeyCache {
  DeviceSyncKeyCache({FlutterSecureStorage? storage})
      : _secure = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secure;

  static const _prefsPrefix = 'folio_device_sync_key_v1_';
  static String _key(String vaultId) => '$_prefsPrefix${vaultId.trim()}';
  static String _prefsFallback(String vaultId) =>
      'folio_device_sync_key_prefs_v1_${vaultId.trim()}';

  /// Clave de pack determinista para libretas en claro (cross-device).
  ///
  /// [accountSecret] es un valor aleatorio de 32 bytes por cuenta+libreta
  /// (ver [ensureAccountSyncSecret]) — sin él, esta clave sería recalculable
  /// solo con `uid`+`vaultId`, que el backend ya conoce por ser parte de la
  /// propia ruta de Storage/Firestore del pack.
  static Future<SecretKey> plainPackKey({
    required String uid,
    required String vaultId,
    required String accountSecret,
  }) async {
    final material = utf8.encode(
      'FolioDeviceSyncPlainV1:${uid.trim()}:${vaultId.trim()}:${accountSecret.trim()}',
    );
    final digest = await Sha256().hash(material);
    return VaultCrypto.dekFromBytes(Uint8List.fromList(digest.bytes));
  }

  /// Obtiene (o crea, en el primer dispositivo que lo pida) el secreto de
  /// cuenta+libreta usado en [plainPackKey], vía la Cloud Function
  /// `folioEnsurePlainVaultSyncSecret`. Todos los dispositivos de la misma
  /// cuenta obtienen el mismo valor (get-or-create idempotente en Firestore).
  static Future<String> ensureAccountSyncSecret(String vaultId) async {
    final result = await callFolioHttpsCallable(
      'folioEnsurePlainVaultSyncSecret',
      {'vaultId': vaultId.trim()},
    );
    final map = result is Map ? Map<String, dynamic>.from(result) : const {};
    final secret = (map['secret'] as String?)?.trim() ?? '';
    if (secret.isEmpty) {
      throw StateError('folioEnsurePlainVaultSyncSecret: respuesta sin secreto');
    }
    return secret;
  }

  Future<void> save(String vaultId, List<int> keyBytes) async {
    final id = vaultId.trim();
    if (id.isEmpty || keyBytes.length != VaultCrypto.dekLength) {
      AppLogger.debug(
        'key cache save skipped',
        tag: 'cloud_sync',
        context: {
          'vaultId': id.isEmpty ? '(empty)' : id,
          'keyLen': keyBytes.length,
        },
      );
      return;
    }
    final b64 = base64Encode(keyBytes);
    var secureOk = false;
    try {
      await _secure.write(key: _key(id), value: b64);
      secureOk = true;
    } catch (e) {
      AppLogger.warn(
        'key cache secure write failed',
        tag: 'cloud_sync',
        context: {'vaultId': id, 'error': '$e'},
      );
    }
    if (secureOk) {
      // Secure write succeeded: purge any legacy plaintext copy so the raw
      // key never lingers unencrypted on disk.
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove(_prefsFallback(id));
      } catch (e) {
        AppLogger.warn(
          'key cache prefs cleanup failed',
          tag: 'cloud_sync',
          context: {'vaultId': id, 'error': '$e'},
        );
      }
      AppLogger.debug(
        'key cache saved',
        tag: 'cloud_sync',
        context: {'vaultId': id, 'secure': true},
      );
      return;
    }
    // Secure storage unavailable on this platform/device: fall back to
    // SharedPreferences only in this branch, never unconditionally.
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsFallback(id), b64);
      AppLogger.debug(
        'key cache saved',
        tag: 'cloud_sync',
        context: {'vaultId': id, 'secure': false},
      );
    } catch (e) {
      AppLogger.warn(
        'key cache prefs write failed',
        tag: 'cloud_sync',
        context: {'vaultId': id, 'error': '$e'},
      );
    }
  }

  Future<Uint8List?> read(String vaultId) async {
    final id = vaultId.trim();
    if (id.isEmpty) return null;
    String? b64;
    try {
      b64 = await _secure.read(key: _key(id));
    } catch (e) {
      AppLogger.debug(
        'key cache secure read failed',
        tag: 'cloud_sync',
        context: {'vaultId': id, 'error': '$e'},
      );
      b64 = null;
    }
    if (b64 == null || b64.isEmpty) {
      try {
        final p = await SharedPreferences.getInstance();
        b64 = p.getString(_prefsFallback(id));
      } catch (e) {
        AppLogger.debug(
          'key cache prefs read failed',
          tag: 'cloud_sync',
          context: {'vaultId': id, 'error': '$e'},
        );
        return null;
      }
    }
    if (b64 == null || b64.isEmpty) {
      AppLogger.debug(
        'key cache miss',
        tag: 'cloud_sync',
        context: {'vaultId': id},
      );
      return null;
    }
    try {
      final bytes = base64Decode(b64);
      if (bytes.length != VaultCrypto.dekLength) {
        AppLogger.warn(
          'key cache invalid length',
          tag: 'cloud_sync',
          context: {'vaultId': id, 'keyLen': bytes.length},
        );
        return null;
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      AppLogger.warn(
        'key cache decode failed',
        tag: 'cloud_sync',
        context: {'vaultId': id, 'error': '$e'},
      );
      return null;
    }
  }

  Future<SecretKey?> readSecretKey(String vaultId) async {
    final bytes = await read(vaultId);
    if (bytes == null) return null;
    return VaultCrypto.dekFromBytes(bytes);
  }

  /// Si no hay clave cacheada, crea una estable y la guarda.
  Future<SecretKey> ensurePlainVaultSyncKey(String vaultId) async {
    final existing = await readSecretKey(vaultId);
    if (existing != null) return existing;
    AppLogger.info(
      'key cache: creating plain vault sync key',
      tag: 'cloud_sync',
      context: {'vaultId': vaultId.trim()},
    );
    final raw = VaultCrypto.randomBytes(VaultCrypto.dekLength);
    await save(vaultId, raw);
    return VaultCrypto.dekFromBytes(raw);
  }
}
