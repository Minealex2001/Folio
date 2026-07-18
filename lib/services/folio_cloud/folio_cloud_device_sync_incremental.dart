import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../data/vault_payload.dart';
import '../app_logger.dart';
import '../sync/vault_sync_pack.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_pack_crypto.dart';
import 'folio_storage_transport.dart';

const int kDeviceSyncFormatVersion = 2;
const String kDeviceSyncManifestFormat = 'folio.device.sync.manifest.v2';

typedef DeviceSyncTransferProgress = void Function(
  int completed,
  int total,
  double fraction,
);

class DeviceSyncPushResult {
  const DeviceSyncPushResult({
    required this.manifestPath,
    required this.manifestSizeBytes,
    required this.blobIds,
    required this.rev,
  });

  final String manifestPath;
  final int manifestSizeBytes;
  final Set<String> blobIds;
  final int rev;
}

class DeviceSyncPullResult {
  const DeviceSyncPullResult({
    required this.packBytes,
    required this.blobIds,
  });

  final Uint8List packBytes;
  final Set<String> blobIds;
}

/// Sube blobs content-addressed + manifiesto cifrado (device-sync v2).
Future<DeviceSyncPushResult> pushDeviceSyncIncremental({
  required String uid,
  required String vaultId,
  required VaultSyncPack pack,
  required SecretKey packKey,
  required String contentFingerprint,
  required String deviceId,
  required String deviceName,
  required Set<String> previousBlobIds,
  required String oldManifestPath,
  required int oldManifestSize,
  required String oldPackPath,
  required int oldPackSize,
  String displayName = '',
  String vaultMode = '',
  String packKeyKind = 'account',
  String dekAccountWrapB64 = '',
  DeviceSyncTransferProgress? onProgress,
}) async {
  AppLogger.info(
    'incremental push start',
    tag: 'cloud_sync',
    context: {
      'vaultId': vaultId,
      'prevBlobs': previousBlobIds.length,
      'attachments': pack.attachments.length,
    },
  );
  final payloadPlain = utf8.encode(jsonEncode(pack.payload.toJson()));
  final payloadCipher = await cloudPackEncryptPlainBlob(
    plain: payloadPlain,
    packKey: packKey,
    role: 'device-sync-payload',
  );
  final payloadBlobId = await cloudPackBlobIdFromCipherBytes(payloadCipher);

  final attachmentEntries = <Map<String, String>>[];
  final cipherByBlobId = <String, Uint8List>{
    payloadBlobId: payloadCipher,
  };

  for (final a in pack.attachments) {
    final attCipher = await cloudPackEncryptPlainBlob(
      plain: a.bytes,
      packKey: packKey,
      role: 'device-sync-att:${a.path}',
    );
    final blobId = await cloudPackBlobIdFromCipherBytes(attCipher);
    cipherByBlobId[blobId] = attCipher;
    attachmentEntries.add({
      'path': a.path,
      'blobId': blobId,
      if (a.sha256Hex.isNotEmpty) 'sha256': a.sha256Hex,
    });
  }

  final allBlobIds = cipherByBlobId.keys.toSet();
  var newBlobIds = allBlobIds.difference(previousBlobIds);
  final supposedlyExisting = allBlobIds.intersection(previousBlobIds);
  // La caché de blobIds puede quedar obsoleta si otro dispositivo borró blobs.
  // Verificar existencia antes de omitir la subida (evita manifiestos rotos).
  for (final blobId in supposedlyExisting) {
    final path = 'users/$uid/vaults/$vaultId/device-sync/blobs/$blobId';
    final exists = await folioStorageObjectExists(
      FirebaseStorage.instance.ref().child(path),
    );
    if (!exists) {
      newBlobIds = {...newBlobIds, blobId};
      AppLogger.warn(
        'incremental push: blob missing, will re-upload',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId, 'blobId': blobId},
      );
    }
  }
  final obsoleteBlobIds = previousBlobIds.difference(allBlobIds);
  AppLogger.debug(
    'incremental push delta',
    tag: 'cloud_sync',
    context: {
      'vaultId': vaultId,
      'newBlobs': newBlobIds.length,
      'obsoleteBlobs': obsoleteBlobIds.length,
      'totalBlobs': allBlobIds.length,
    },
  );

  final toUpload = newBlobIds.toList();
  final totalSteps = toUpload.length + 1;
  var done = 0;

  final newBlobList = <Map<String, dynamic>>[];
  for (final blobId in toUpload) {
    final cipher = cipherByBlobId[blobId]!;
    final path = 'users/$uid/vaults/$vaultId/device-sync/blobs/$blobId';
    await folioStoragePutData(
      FirebaseStorage.instance.ref().child(path),
      cipher,
    );
    newBlobList.add({'blobId': blobId, 'sizeBytes': cipher.length});
    done++;
    onProgress?.call(done, totalSteps, done / totalSteps);
  }

  // No borrar blobs obsoletos al instante: un pull concurrente del manifiesto
  // anterior puede recibir 404. La cuota ya descuenta vía deleteBlobs; el GC
  // de ficheros puede hacerse más tarde. (Evita manifiestos huérfanos.)
  final deleteBlobList = <Map<String, dynamic>>[
    for (final blobId in obsoleteBlobIds)
      {'blobId': blobId, 'sizeBytes': 1},
  ];

  final manifestClear = <String, Object?>{
    'format': kDeviceSyncManifestFormat,
    'formatVersion': kDeviceSyncFormatVersion,
    'contentFingerprint': contentFingerprint,
    'payloadBlobId': payloadBlobId,
    'attachments': attachmentEntries,
  };
  final manifestCipher = await cloudPackEncryptBytes(
    plain: utf8.encode(jsonEncode(manifestClear)),
    packKey: packKey,
  );
  final stamp =
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final manifestPath =
      'users/$uid/vaults/$vaultId/device-sync/manifests/manifest-$stamp.bin';
  await folioStoragePutData(
    FirebaseStorage.instance.ref().child(manifestPath),
    manifestCipher,
  );
  done++;
  onProgress?.call(done, totalSteps, 1.0);

  // Solo enviar rutas antiguas si coinciden con el vault actual; si no, el
  // backend responde invalid-argument (p. ej. caché de otra libreta).
  final safeOldPack = _safeDeviceSyncPackPath(uid, vaultId, oldPackPath);
  final safeOldManifest =
      _safeDeviceSyncManifestPath(uid, vaultId, oldManifestPath);

  final finalize = await callFolioHttpsCallable(
    'folioFinalizeDeviceSync',
    <String, dynamic>{
      'vaultId': vaultId,
      'syncFormatVersion': kDeviceSyncFormatVersion,
      'manifestStoragePath': manifestPath,
      'manifestSizeBytes': manifestCipher.length,
      'contentFingerprint': contentFingerprint,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'newBlobs': newBlobList,
      if (displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
      if (vaultMode.trim().isNotEmpty) 'vaultMode': vaultMode.trim(),
      if (packKeyKind.trim().isNotEmpty) 'packKeyKind': packKeyKind.trim(),
      if (dekAccountWrapB64.trim().isNotEmpty)
        'dekAccountWrapB64': dekAccountWrapB64.trim(),
      if (deleteBlobList.isNotEmpty) 'deleteBlobs': deleteBlobList,
      if (safeOldManifest.isNotEmpty)
        'oldManifestStoragePath': safeOldManifest,
      if (safeOldManifest.isNotEmpty && oldManifestSize > 0)
        'oldManifestSizeBytes': oldManifestSize,
      if (safeOldPack.isNotEmpty) 'oldPackStoragePath': safeOldPack,
      if (safeOldPack.isNotEmpty && oldPackSize > 0)
        'oldPackSizeBytes': oldPackSize,
    },
  );

  // Intencionadamente no borramos blobs obsoletos aquí (carrera pull/push).

  var rev = 0;
  if (finalize is Map) {
    final r = finalize['rev'];
    if (r is num) rev = r.toInt();
  }

  AppLogger.info(
    'incremental push ok',
    tag: 'cloud_sync',
    context: {
      'vaultId': vaultId,
      'rev': rev,
      'manifestBytes': manifestCipher.length,
      'blobCount': allBlobIds.length,
    },
  );

  return DeviceSyncPushResult(
    manifestPath: manifestPath,
    manifestSizeBytes: manifestCipher.length,
    blobIds: allBlobIds,
    rev: rev,
  );
}

/// Lee solo los blobIds del manifiesto (sin descargar blobs de contenido).
Future<Set<String>> peekDeviceSyncManifestBlobIds({
  required String manifestStoragePath,
  required SecretKey packKey,
}) async {
  final manifestCipher = await folioStorageGetData(
    FirebaseStorage.instance.ref().child(manifestStoragePath),
    16 * 1024 * 1024,
  );
  if (manifestCipher == null || manifestCipher.isEmpty) return {};
  final manifestPlain = await cloudPackDecryptBytes(
    blob: manifestCipher,
    packKey: packKey,
  );
  final decoded = jsonDecode(utf8.decode(manifestPlain));
  if (decoded is! Map) return {};
  final map = Map<String, dynamic>.from(decoded);
  if (map['format'] != kDeviceSyncManifestFormat) return {};
  final out = <String>{};
  final payloadBlobId = '${map['payloadBlobId'] ?? ''}'.trim().toLowerCase();
  if (cloudPackIsValidBlobId(payloadBlobId)) out.add(payloadBlobId);
  final attRaw = map['attachments'];
  if (attRaw is List) {
    for (final item in attRaw) {
      if (item is! Map) continue;
      final blobId = '${item['blobId'] ?? ''}'.trim().toLowerCase();
      if (cloudPackIsValidBlobId(blobId)) out.add(blobId);
    }
  }
  return out;
}

/// Descarga manifiesto v2 + blobs y reconstruye bytes de [VaultSyncPack].
Future<DeviceSyncPullResult> pullDeviceSyncIncremental({
  required String manifestStoragePath,
  required SecretKey packKey,
  DeviceSyncTransferProgress? onProgress,
}) async {
  AppLogger.info(
    'incremental pull start',
    tag: 'cloud_sync',
    context: {'manifest': manifestStoragePath},
  );
  final manifestCipher = await folioStorageGetData(
    FirebaseStorage.instance.ref().child(manifestStoragePath),
    16 * 1024 * 1024,
  );
  if (manifestCipher == null || manifestCipher.isEmpty) {
    throw StateError('Empty device-sync manifest');
  }
  final manifestPlain = await cloudPackDecryptBytes(
    blob: manifestCipher,
    packKey: packKey,
  );
  final decoded = jsonDecode(utf8.decode(manifestPlain));
  if (decoded is! Map) {
    throw StateError('Invalid device-sync manifest');
  }
  final map = Map<String, dynamic>.from(decoded);
  if (map['format'] != kDeviceSyncManifestFormat) {
    throw StateError('Unsupported device-sync manifest format');
  }
  final payloadBlobId = '${map['payloadBlobId'] ?? ''}'.trim().toLowerCase();
  if (!cloudPackIsValidBlobId(payloadBlobId)) {
    throw StateError('Invalid payloadBlobId');
  }

  final attRaw = map['attachments'];
  final attSpecs = <({String path, String blobId, String sha})>[];
  if (attRaw is List) {
    for (final item in attRaw) {
      if (item is! Map) continue;
      final path = '${item['path'] ?? ''}'.trim().replaceAll(r'\', '/');
      final blobId = '${item['blobId'] ?? ''}'.trim().toLowerCase();
      final sha = '${item['sha256'] ?? ''}'.trim().toLowerCase();
      if (path.isEmpty || !cloudPackIsValidBlobId(blobId)) continue;
      attSpecs.add((path: path, blobId: blobId, sha: sha));
    }
  }

  final allIds = <String>{payloadBlobId, ...attSpecs.map((e) => e.blobId)};
  final total = allIds.length;
  var done = 0;

  Future<Uint8List> downloadBlob(String blobId) async {
    final parts = manifestStoragePath.split('/');
    if (parts.length < 6) {
      throw StateError('Cannot resolve blob path from manifest');
    }
    final uid = parts[1];
    final vaultId = parts[3];
    final path = 'users/$uid/vaults/$vaultId/device-sync/blobs/$blobId';
    try {
      final cipher = await folioStorageGetData(
        FirebaseStorage.instance.ref().child(path),
        80 * 1024 * 1024,
      );
      if (cipher == null || cipher.isEmpty) {
        throw StateError('Missing device-sync blob $blobId');
      }
      final clear = await cloudPackDecryptBytes(blob: cipher, packKey: packKey);
      done++;
      onProgress?.call(done, total, done / total);
      return clear;
    } catch (e) {
      AppLogger.error(
        'incremental pull blob failed',
        tag: 'cloud_sync',
        error: e,
        context: {'path': path, 'blobId': blobId},
      );
      throw StateError('device-sync blob missing or unreadable: $path');
    }
  }

  final payloadBytes = await downloadBlob(payloadBlobId);
  final payloadJson = jsonDecode(utf8.decode(payloadBytes));
  if (payloadJson is! Map) {
    throw StateError('Invalid device-sync payload');
  }

  final attachments = <VaultSyncPackAttachment>[];
  for (final spec in attSpecs) {
    final bytes = await downloadBlob(spec.blobId);
    attachments.add(
      VaultSyncPackAttachment(
        path: spec.path,
        sha256Hex: spec.sha,
        bytes: bytes,
      ),
    );
  }

  final pack = VaultSyncPack(
    payload: VaultPayload.fromJson(Map<String, dynamic>.from(payloadJson)),
    attachments: attachments,
  );

  final packBytes = Uint8List.fromList(pack.encodeUtf8());
  AppLogger.info(
    'incremental pull ok',
    tag: 'cloud_sync',
    context: {
      'blobs': allIds.length,
      'attachments': attachments.length,
      'packBytes': packBytes.length,
    },
  );

  return DeviceSyncPullResult(
    packBytes: packBytes,
    blobIds: allIds,
  );
}

/// Misma regla que `assertDeviceSyncPackStoragePath` en Cloud Functions.
String _safeDeviceSyncPackPath(String uid, String vaultId, String path) {
  final p = path.trim();
  if (p.isEmpty) return '';
  final prefix = 'users/$uid/vaults/$vaultId/device-sync/packs/';
  if (!p.startsWith(prefix) || p.contains('..') || !p.endsWith('.bin')) {
    return '';
  }
  return p;
}

String _safeDeviceSyncManifestPath(String uid, String vaultId, String path) {
  final p = path.trim();
  if (p.isEmpty) return '';
  final prefix = 'users/$uid/vaults/$vaultId/device-sync/manifests/';
  if (!p.startsWith(prefix) || p.contains('..') || !p.endsWith('.bin')) {
    return '';
  }
  return p;
}
