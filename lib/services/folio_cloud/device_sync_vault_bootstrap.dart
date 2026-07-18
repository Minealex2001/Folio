import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../crypto/vault_crypto.dart';
import '../../data/storage/vault_storage.dart';
import '../../data/vault_paths.dart';
import '../../data/vault_registry.dart';
import '../../services/settings/folio_app_profile_crypto.dart';
import '../app_logger.dart';
import '../sync/vault_sync_pack.dart';
import 'device_sync_key_cache.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_device_sync_incremental.dart';
import 'folio_cloud_pack_crypto.dart';
import 'folio_storage_transport.dart';
import 'headless_device_sync_vault.dart';

/// Meta remota de una libreta con device-sync en la cuenta.
class DeviceSyncRemoteVaultInfo {
  const DeviceSyncRemoteVaultInfo({
    required this.vaultId,
    required this.displayName,
    required this.vaultMode,
    required this.rev,
    required this.contentFingerprint,
    required this.hasCloudPack,
  });

  final String vaultId;
  final String displayName;
  final String vaultMode; // 'plain' | 'encrypted' | ''
  final int rev;
  final String contentFingerprint;
  final bool hasCloudPack;

  bool get isPlain => vaultMode.trim().toLowerCase() == 'plain';
}

String deviceSyncBootstrapPrefix(String uid, String vaultId) =>
    'users/$uid/vaults/$vaultId/device-sync/bootstrap';

Future<SecretKey?> resolveAccountProfilePackKeyQuietly() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;
  final crypto = FolioAppProfileCrypto();
  try {
    String? wrapB64;
    try {
      final wrapRes = await callFolioHttpsCallable(
        'folioGetAppProfileRestoreWrap',
        <String, dynamic>{},
      );
      if (wrapRes is Map) {
        final w = '${wrapRes['restoreWrapB64'] ?? ''}'.trim();
        if (w.isNotEmpty) wrapB64 = w;
      }
    } catch (_) {}
    final resolved = await crypto.ensurePackKey(
      uid: uid,
      restoreWrapB64: wrapB64,
      restorePassword: '',
      preferRemoteWrap: wrapB64 != null && wrapB64.isNotEmpty,
    );
    return resolved.key;
  } catch (e) {
    AppLogger.warn(
      'account profile pack key unavailable for device-sync bootstrap',
      tag: 'cloud_sync',
      context: {'error': '$e'},
    );
    return null;
  }
}

/// Lista libretas con device-sync en la nube (callable; funciona también en Windows).
Future<List<DeviceSyncRemoteVaultInfo>> listRemoteDeviceSyncVaults() async {
  final raw = await callFolioHttpsCallable(
    'folioListDeviceSyncVaults',
    <String, dynamic>{},
  );
  if (raw is! Map) return const [];
  final list = raw['vaults'];
  if (list is! List) return const [];
  final out = <DeviceSyncRemoteVaultInfo>[];
  for (final item in list) {
    if (item is! Map) continue;
    final id = '${item['vaultId'] ?? ''}'.trim();
    if (id.isEmpty) continue;
    final revRaw = item['rev'];
    final rev = revRaw is num
        ? revRaw.toInt()
        : int.tryParse('$revRaw') ?? 0;
    out.add(
      DeviceSyncRemoteVaultInfo(
        vaultId: id,
        displayName: '${item['displayName'] ?? ''}'.trim(),
        vaultMode: '${item['vaultMode'] ?? ''}'.trim(),
        rev: rev,
        contentFingerprint: '${item['contentFingerprint'] ?? ''}'.trim(),
        hasCloudPack: item['hasCloudPack'] == true,
      ),
    );
  }
  return out;
}

/// Sube material de bootstrap (mode, keys, wrap de DEK con clave de cuenta).
/// Devuelve el wrap en base64 si se generó (para guardarlo también en Firestore).
Future<String?> uploadDeviceSyncBootstrap({
  required String uid,
  required String vaultId,
  required bool encrypted,
  List<int>? dekBytes,
}) async {
  final prefix = deviceSyncBootstrapPrefix(uid, vaultId);
  final storage = VaultStorage.instance;
  final mode = encrypted ? 'encrypted' : 'plain';
  await folioStoragePutData(
    FirebaseStorage.instance.ref().child('$prefix/vault.mode'),
    Uint8List.fromList(utf8.encode(mode)),
  );

  String? wrapB64;
  if (encrypted) {
    final keys = await storage.readVaultFile(vaultId, VaultPaths.wrappedDekFile);
    if (keys != null && keys.isNotEmpty) {
      await folioStoragePutData(
        FirebaseStorage.instance.ref().child('$prefix/vault.keys'),
        keys,
      );
    }
    if (dekBytes != null && dekBytes.length == VaultCrypto.dekLength) {
      final accountKey = await resolveAccountProfilePackKeyQuietly();
      if (accountKey != null) {
        final wrap = await cloudPackEncryptBytes(
          plain: Uint8List.fromList(dekBytes),
          packKey: accountKey,
        );
        await folioStoragePutData(
          FirebaseStorage.instance.ref().child('$prefix/dek.accountwrap.bin'),
          wrap,
        );
        wrapB64 = base64Encode(wrap);
        AppLogger.info(
          'device sync bootstrap dek wrap uploaded',
          tag: 'cloud_sync',
          context: {'vaultId': vaultId, 'wrapBytes': wrap.length},
        );
      } else {
        AppLogger.warn(
          'device sync bootstrap: account key missing, wrap not uploaded',
          tag: 'cloud_sync',
          context: {'vaultId': vaultId},
        );
      }
    }
  }
  return wrapB64;
}

Future<Uint8List?> _downloadBootstrapFile(String path, int maxBytes) async {
  try {
    return await folioStorageGetData(
      FirebaseStorage.instance.ref().child(path),
      maxBytes,
    );
  } catch (_) {
    return null;
  }
}

/// Obtiene la clave de pack sin desbloquear: plain determinista o DEK desde
/// `dek.accountwrap` cifrado con la clave de perfil de cuenta.
Future<SecretKey?> adoptDeviceSyncPackKeyFromBootstrap({
  required String vaultId,
  required DeviceSyncKeyCache keyCache,
  HeadlessDeviceSyncVault? headless,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;
  final id = vaultId.trim();
  if (id.isEmpty) return null;

  final existing = await keyCache.readSecretKey(id);
  if (existing != null) return existing;

  final probe = headless ?? HeadlessDeviceSyncVault(keyCache: keyCache);
  if (await probe.isPlain(id)) {
    final key = await DeviceSyncKeyCache.plainPackKey(uid: uid, vaultId: id);
    final raw = await key.extractBytes();
    await keyCache.save(id, raw);
    return key;
  }

  final accountKey = await resolveAccountProfilePackKeyQuietly();
  if (accountKey == null) {
    AppLogger.debug(
      'adopt pack key: no account profile key',
      tag: 'cloud_sync',
      context: {'vaultId': id},
    );
    return null;
  }

  // 1) Firestore meta (más fiable que Storage en algunos clientes).
  try {
    final meta = await callFolioHttpsCallable(
      'folioGetDeviceSyncMeta',
      <String, dynamic>{'vaultId': id},
    );
    if (meta is Map) {
      final b64 = '${meta['dekAccountWrapB64'] ?? ''}'.trim();
      if (b64.isNotEmpty) {
        final wrap = base64Decode(b64);
        final clear = await cloudPackDecryptBytes(
          blob: wrap,
          packKey: accountKey,
        );
        if (clear.length == VaultCrypto.dekLength) {
          await keyCache.save(id, clear);
          AppLogger.info(
            'adopt pack key from firestore wrap ok',
            tag: 'cloud_sync',
            context: {'vaultId': id},
          );
          return await VaultCrypto.dekFromBytes(clear);
        }
      }
    }
  } catch (e) {
    AppLogger.debug(
      'adopt pack key: firestore wrap miss',
      tag: 'cloud_sync',
      context: {'vaultId': id, 'error': '$e'},
    );
  }

  final prefix = deviceSyncBootstrapPrefix(uid, id);
  final wrap = await _downloadBootstrapFile(
    '$prefix/dek.accountwrap.bin',
    256 * 1024,
  );
  if (wrap == null || wrap.isEmpty) {
    AppLogger.debug(
      'adopt pack key: no dek.accountwrap yet',
      tag: 'cloud_sync',
      context: {'vaultId': id},
    );
    return null;
  }

  try {
    final clear = await cloudPackDecryptBytes(blob: wrap, packKey: accountKey);
    if (clear.length != VaultCrypto.dekLength) {
      throw StateError('invalid dek wrap length ${clear.length}');
    }
    await keyCache.save(id, clear);

    // Asegura vault.keys local si falta (desbloqueo con contraseña más adelante).
    final storage = VaultStorage.instance;
    final localKeys = await storage.readVaultFile(id, VaultPaths.wrappedDekFile);
    if (localKeys == null || localKeys.isEmpty) {
      final remoteKeys = await _downloadBootstrapFile(
        '$prefix/vault.keys',
        256 * 1024,
      );
      if (remoteKeys != null && remoteKeys.isNotEmpty) {
        await storage.writeVaultFile(id, VaultPaths.wrappedDekFile, remoteKeys);
      }
    }

    AppLogger.info(
      'adopt pack key from account wrap ok',
      tag: 'cloud_sync',
      context: {'vaultId': id},
    );
    return await VaultCrypto.dekFromBytes(clear);
  } catch (e) {
    AppLogger.warn(
      'adopt pack key failed',
      tag: 'cloud_sync',
      context: {'vaultId': id, 'error': '$e'},
    );
    return null;
  }
}

/// Crea en local una libreta que solo existe en la nube y aplica el pack remoto.
Future<bool> materializeRemoteDeviceSyncVault({
  required DeviceSyncRemoteVaultInfo remote,
  required HeadlessDeviceSyncVault headless,
  required DeviceSyncKeyCache keyCache,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  if (!remote.hasCloudPack) return false;

  final vaultId = remote.vaultId;
  final registry = VaultRegistry.instance;
  await registry.load();
  if (registry.containsVault(vaultId)) return false;

  AppLogger.info(
    'materialize remote device-sync vault',
    tag: 'cloud_sync',
    context: {
      'vaultId': vaultId,
      'mode': remote.vaultMode,
      'displayName': remote.displayName,
    },
  );

  // Meta Firestore + Storage.
  Map<String, dynamic>? syncMeta;
  try {
    final meta = await callFolioHttpsCallable(
      'folioGetDeviceSyncMeta',
      <String, dynamic>{'vaultId': vaultId},
    );
    if (meta is Map) syncMeta = Map<String, dynamic>.from(meta);
  } catch (e) {
    AppLogger.warn(
      'materialize: meta failed',
      tag: 'cloud_sync',
      context: {'vaultId': vaultId, 'error': '$e'},
    );
    return false;
  }

  final formatVersion = syncMeta?['syncFormatVersion'] is num
      ? (syncMeta!['syncFormatVersion'] as num).toInt()
      : 1;
  final manifestPath = '${syncMeta?['manifestStoragePath'] ?? ''}'.trim();
  final packPath = '${syncMeta?['packStoragePath'] ?? ''}'.trim();
  final remoteFp = '${syncMeta?['contentFingerprint'] ?? remote.contentFingerprint}'
      .trim();
  final isV2 = formatVersion >= 2 && manifestPath.isNotEmpty;
  if (!isV2 && packPath.isEmpty) return false;

  final prefix = deviceSyncBootstrapPrefix(uid, vaultId);
  final modeBytes = await _downloadBootstrapFile('$prefix/vault.mode', 64);
  var mode = remote.isPlain
      ? 'plain'
      : (remote.vaultMode.trim().isNotEmpty
          ? remote.vaultMode.trim().toLowerCase()
          : 'encrypted');
  if (modeBytes != null && modeBytes.isNotEmpty) {
    final m = utf8.decode(modeBytes).trim().toLowerCase();
    if (m == 'plain' || m == 'encrypted') mode = m;
  }
  final encrypted = mode != 'plain';

  late final SecretKey packKey;
  List<int>? dekBytes;
  if (encrypted) {
    final accountKey = await resolveAccountProfilePackKeyQuietly();
    if (accountKey == null) {
      AppLogger.warn(
        'materialize skipped: no account profile key',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId},
      );
      return false;
    }
    final wrap = await _downloadBootstrapFile(
      '$prefix/dek.accountwrap.bin',
      256 * 1024,
    );
    if (wrap == null || wrap.isEmpty) {
      AppLogger.warn(
        'materialize skipped: missing dek.accountwrap (re-sync from source device)',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId},
      );
      return false;
    }
    try {
      final clear = await cloudPackDecryptBytes(
        blob: wrap,
        packKey: accountKey,
      );
      if (clear.length != VaultCrypto.dekLength) {
        throw StateError('invalid dek wrap length');
      }
      dekBytes = clear;
      packKey = await VaultCrypto.dekFromBytes(clear);
    } catch (e) {
      AppLogger.warn(
        'materialize: dek wrap decrypt failed',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId, 'error': '$e'},
      );
      return false;
    }
  } else {
    packKey = await DeviceSyncKeyCache.plainPackKey(uid: uid, vaultId: vaultId);
  }

  await VaultPaths.initVaultStorage(vaultId);
  final storage = VaultStorage.instance;
  await storage.writeVaultFile(
    vaultId,
    VaultPaths.vaultModeFile,
    Uint8List.fromList(utf8.encode(mode)),
  );
  if (encrypted) {
    final keys = await _downloadBootstrapFile(
      '$prefix/vault.keys',
      256 * 1024,
    );
    if (keys != null && keys.isNotEmpty) {
      await storage.writeVaultFile(vaultId, VaultPaths.wrappedDekFile, keys);
    } else if (dekBytes != null) {
      // Sin vault.keys remoto: no se puede desbloquear con contraseña hasta
      // que el origen vuelva a subir bootstrap. Aun así materializamos contenido
      // con la DEK vía account-wrap (sync headless).
      AppLogger.warn(
        'materialize: vault.keys missing; content ok, password unlock may fail',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId},
      );
    }
  }

  late final Uint8List packBytes;
  try {
    if (isV2) {
      final rebuilt = await pullDeviceSyncIncremental(
        manifestStoragePath: manifestPath,
        packKey: packKey,
      );
      packBytes = rebuilt.packBytes;
    } else {
      final cipher = await folioStorageGetData(
        FirebaseStorage.instance.ref().child(packPath),
        80 * 1024 * 1024,
      );
      if (cipher == null || cipher.isEmpty) {
        throw StateError('Empty sync pack');
      }
      packBytes = await cloudPackDecryptBytes(blob: cipher, packKey: packKey);
    }
  } catch (e, st) {
    AppLogger.error(
      'materialize: pull pack failed',
      tag: 'cloud_sync',
      error: e,
      stackTrace: st,
      context: {'vaultId': vaultId},
    );
    try {
      await VaultPaths.deleteVaultDirectory(vaultId);
    } catch (_) {}
    return false;
  }

  final pack = VaultSyncPack.decodeFlexible(packBytes);
  await materializeVaultSyncPackAttachmentsForVault(vaultId, pack);
  await headless.savePayload(
    vaultId: vaultId,
    packKey: packKey,
    payload: pack.payload,
  );

  final name = remote.displayName.trim().isNotEmpty
      ? remote.displayName.trim()
      : (pack.payload.displayName.trim().isNotEmpty
          ? pack.payload.displayName.trim()
          : 'Libreta');
  await registry.add(
    VaultEntry(
      id: vaultId,
      displayName: name,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  if (pack.payload.displayName.trim().isNotEmpty &&
      pack.payload.displayName.trim() != name) {
    await registry.rename(vaultId, pack.payload.displayName.trim());
  }

  if (encrypted && dekBytes != null) {
    await keyCache.save(vaultId, dekBytes);
  } else {
    final raw = await packKey.extractBytes();
    await keyCache.save(vaultId, raw);
  }

  AppLogger.info(
    'materialize remote vault ok',
    tag: 'cloud_sync',
    context: {
      'vaultId': vaultId,
      'pages': pack.payload.pages.length,
      'fp': remoteFp,
      'name': name,
    },
  );
  return true;
}
