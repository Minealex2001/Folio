import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../crypto/vault_crypto.dart';
import '../app_logger.dart';

/// Cache de material de cifrado para device-sync **sin** desbloquear la libreta.
///
/// - Libreta cifrada: DEK (32 bytes), se guarda al desbloquear.
/// - Libreta en claro: clave estable aleatoria (no derivada de `vault.bin`,
///   para que el MAC no cambie al editar).
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

  static String _key(String vaultId) => 'folio_device_sync_key_v1_$vaultId';
  static String _prefsFallback(String vaultId) =>
      'folio_device_sync_key_prefs_v1_$vaultId';

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
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsFallback(id), b64);
      AppLogger.debug(
        'key cache saved',
        tag: 'cloud_sync',
        context: {'vaultId': id, 'secure': secureOk},
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
