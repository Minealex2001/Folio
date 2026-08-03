import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

import '../../crypto/vault_crypto.dart';
import '../../data/vault_payload.dart';
import '../../models/folio_page.dart';
import '../../utils/concurrency.dart';
import '../app_logger.dart';
import '../sync/vault_sync_pack.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_pack_crypto.dart';
import 'folio_storage_transport.dart';

/// Cifra+hashea un lote de páginas/adjuntos en un isolate aparte: por cada
/// item de `message['items']` (`{id, role, json?, bytes?}`) hace el
/// `jsonEncode` (si aplica) + AES-GCM + SHA-256 — el trabajo de CPU más
/// pesado de un push, antes hecho uno a uno en el isolate de UI.
Future<List<Map<String, Object?>>> _encryptPackItemsIsolate(
  Map<String, Object?> message,
) async {
  final packKey = await VaultCrypto.dekFromBytes(
    message['keyBytes'] as Uint8List,
  );
  final items = message['items'] as List;
  final out = <Map<String, Object?>>[];
  for (final raw in items) {
    final item = raw as Map;
    final json = item['json'];
    final plain = json != null
        ? utf8.encode(jsonEncode(json))
        : item['bytes'] as Uint8List;
    final cipher = await cloudPackEncryptPlainBlob(
      plain: plain,
      packKey: packKey,
      role: item['role'] as String,
    );
    final blobId = await cloudPackBlobIdFromCipherBytes(cipher);
    out.add({'id': item['id'], 'cipher': cipher, 'blobId': blobId});
  }
  return out;
}

/// Descifra un lote de blobs ya descargados (ciphertext -> plaintext) en un
/// isolate aparte. El `jsonDecode` sigue en el isolate de UI (barato: solo
/// arma Maps, no hay serialización de string pesada).
Future<List<Uint8List>> _decryptPackItemsIsolate(
  Map<String, Object?> message,
) async {
  final packKey = await VaultCrypto.dekFromBytes(
    message['keyBytes'] as Uint8List,
  );
  final ciphers = message['ciphers'] as List;
  final out = <Uint8List>[];
  for (final cipher in ciphers) {
    out.add(await cloudPackDecryptBytes(blob: cipher as Uint8List, packKey: packKey));
  }
  return out;
}

/// v3 sube cada página como blob independiente (content-addressed), igual
/// que los adjuntos; v2 (legacy, aún leído) sube todo el payload en un único
/// blob. `kDeviceSyncFormatVersion`/`kDeviceSyncManifestFormat` son siempre
/// los del formato que este cliente ESCRIBE; el pull acepta ambos.
const int kDeviceSyncFormatVersion = 3;
const String kDeviceSyncManifestFormat = kDeviceSyncManifestFormatV3;
const String kDeviceSyncManifestFormatV2 = 'folio.device.sync.manifest.v2';
const String kDeviceSyncManifestFormatV3 = 'folio.device.sync.manifest.v3';

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
    this.vaultBlobId = '',
    this.pageBlobIds = const {},
  });

  final String manifestPath;
  final int manifestSizeBytes;
  final Set<String> blobIds;
  final int rev;

  /// Manifiesto por página que este push acaba de dejar en la nube — para
  /// persistir como "último aplicado" y diffear la próxima vez sin red.
  final String vaultBlobId;
  final Map<String, String> pageBlobIds;
}

class DeviceSyncPullResult {
  const DeviceSyncPullResult({
    required this.packBytes,
    required this.blobIds,
    this.vaultBlobId = '',
    this.pageBlobIds = const {},
    this.manifestPageCount,
  });

  final Uint8List packBytes;
  final Set<String> blobIds;

  /// Manifiesto resuelto de este pull (vacío en formato v2 legacy, que no
  /// tiene páginas sueltas) — para persistir como "último aplicado" y poder
  /// diffear la próxima vez sin descargar nada.
  final String vaultBlobId;
  final Map<String, String> pageBlobIds;

  /// Recuento de páginas que el propio manifiesto declara tener (`pageCount`,
  /// formato v3+). `null` en manifiestos que predatan este campo — el llamador
  /// debe tratar eso como "desconocido", no como "cero".
  final int? manifestPageCount;
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
  String ownerUid = '',
  String displayName = '',
  String vaultMode = '',
  String packKeyKind = 'account',
  String dekAccountWrapB64 = '',
  DeviceSyncTransferProgress? onProgress,
  /// `rev` remoto sobre el que este push cree estar construyendo (última meta
  /// vista por este dispositivo). El backend lo usa como concurrencia
  /// optimista: si ya no coincide con el `rev` actual, rechaza el finalize en
  /// vez de pisar en silencio un estado más nuevo de otro dispositivo.
  int? expectedBaseRev,
  /// El usuario ya confirmó explícitamente que una caída fuerte de páginas
  /// respecto al `pageCount` remoto anterior es un borrado intencional (no
  /// un push parcial accidental) — ver el error `sync_page_count_regression`.
  bool confirmPageCountRegression = false,
}) async {
  final storageUid = ownerUid.trim().isNotEmpty ? ownerUid.trim() : uid;
  AppLogger.info(
    'incremental push start',
    tag: 'cloud_sync',
    context: {
      'vaultId': vaultId,
      'ownerUid': storageUid,
      'prevBlobs': previousBlobIds.length,
      'pages': pack.payload.pages.length,
      'attachments': pack.attachments.length,
    },
  );
  // v3: cada página es su propio blob content-addressed (como los adjuntos);
  // el resto del payload (metadatos de libreta, integraciones, etc.) va en
  // un único blob aparte. Así un push solo sube lo que cambió de verdad.
  //
  // El jsonEncode+AES-GCM+SHA-256 de "resto" + páginas + adjuntos se manda
  // de una vez a un isolate aparte en vez de uno a uno en el isolate de UI
  // (era el pico de CPU más repetido del ciclo de sync: corre en cada push).
  final packKeyBytes = Uint8List.fromList(await packKey.extractBytes());
  final batchItems = <Map<String, Object?>>[
    {
      'id': '__rest__',
      'role': 'device-sync-vault',
      'json': pack.payload.restJsonExcludingPages(),
    },
    for (final page in pack.payload.pages)
      {
        'id': page.id,
        'role': 'device-sync-page:${page.id}',
        'json': VaultPayload.pageSliceJson(page, pack.payload.comments),
      },
    for (final a in pack.attachments)
      {
        'id': a.path,
        'role': 'device-sync-att:${a.path}',
        'bytes': a.bytes,
      },
  ];
  final encrypted = await compute(_encryptPackItemsIsolate, {
    'keyBytes': packKeyBytes,
    'items': batchItems,
  });

  final vaultBlobId = encrypted[0]['blobId'] as String;
  final cipherByBlobId = <String, Uint8List>{
    vaultBlobId: encrypted[0]['cipher'] as Uint8List,
  };

  final pageEntries = <Map<String, String>>[];
  final pageCount = pack.payload.pages.length;
  for (var i = 0; i < pageCount; i++) {
    final e = encrypted[1 + i];
    final blobId = e['blobId'] as String;
    cipherByBlobId[blobId] = e['cipher'] as Uint8List;
    pageEntries.add({'pageId': e['id'] as String, 'blobId': blobId});
  }

  final attachmentEntries = <Map<String, String>>[];
  for (var i = 0; i < pack.attachments.length; i++) {
    final e = encrypted[1 + pageCount + i];
    final a = pack.attachments[i];
    final blobId = e['blobId'] as String;
    cipherByBlobId[blobId] = e['cipher'] as Uint8List;
    attachmentEntries.add({
      'path': a.path,
      'blobId': blobId,
      if (a.sha256Hex.isNotEmpty) 'sha256': a.sha256Hex,
    });
  }

  final allBlobIds = cipherByBlobId.keys.toSet();
  final newBlobIds = allBlobIds.difference(previousBlobIds);
  final supposedlyExisting = allBlobIds.intersection(previousBlobIds);
  // La caché de blobIds puede quedar obsoleta si otro dispositivo borró blobs.
  // Verificar existencia antes de omitir la subida (evita manifiestos rotos).
  // Las comprobaciones HEAD son ligeras e independientes entre sí, así que se
  // lanzan con concurrencia acotada en vez de una tras otra.
  await mapConcurrent(supposedlyExisting.toList(), (blobId) async {
    final path = 'users/$storageUid/vaults/$vaultId/device-sync/blobs/$blobId';
    final exists = await folioStorageObjectExists(path);
    if (!exists) {
      newBlobIds.add(blobId);
      AppLogger.warn(
        'incremental push: blob missing, will re-upload',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId, 'blobId': blobId},
      );
    }
  }, concurrency: 12);
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
  // Payloads más pesados que las comprobaciones de existencia: concurrencia
  // más baja para no saturar el uplink ni mantener muchos blobs en memoria.
  await mapConcurrent(toUpload, (blobId) async {
    final cipher = cipherByBlobId[blobId]!;
    final path = 'users/$storageUid/vaults/$vaultId/device-sync/blobs/$blobId';
    await folioStoragePutData(path, cipher);
    newBlobList.add({'blobId': blobId, 'sizeBytes': cipher.length});
    done++;
    onProgress?.call(done, totalSteps, done / totalSteps);
  }, concurrency: 4);

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
    'vaultBlobId': vaultBlobId,
    'pageCount': pageCount,
    'pages': pageEntries,
    'attachments': attachmentEntries,
  };
  final manifestCipher = await cloudPackEncryptBytes(
    plain: utf8.encode(jsonEncode(manifestClear)),
    packKey: packKey,
  );
  final stamp =
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final manifestPath =
      'users/$storageUid/vaults/$vaultId/device-sync/manifests/manifest-$stamp.bin';
  await folioStoragePutData(
    manifestPath,
    manifestCipher,
  );
  done++;
  onProgress?.call(done, totalSteps, 1.0);

  // Solo enviar rutas antiguas si coinciden con el vault actual; si no, el
  // backend responde invalid-argument (p. ej. caché de otra libreta).
  final safeOldPack = _safeDeviceSyncPackPath(storageUid, vaultId, oldPackPath);
  final safeOldManifest =
      _safeDeviceSyncManifestPath(storageUid, vaultId, oldManifestPath);

  final finalize = await callFolioHttpsCallable(
    'folioFinalizeDeviceSync',
    <String, dynamic>{
      'vaultId': vaultId,
      if (storageUid != uid) 'ownerUid': storageUid,
      'syncFormatVersion': kDeviceSyncFormatVersion,
      'manifestStoragePath': manifestPath,
      'manifestSizeBytes': manifestCipher.length,
      'contentFingerprint': contentFingerprint,
      'pageCount': pageCount,
      if (expectedBaseRev != null) 'expectedBaseRev': expectedBaseRev,
      if (confirmPageCountRegression) 'confirmPageCountRegression': true,
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
    vaultBlobId: vaultBlobId,
    pageBlobIds: {
      for (final e in pageEntries) e['pageId']!: e['blobId']!,
    },
  );
}

/// Manifiesto ya leído y resuelto a nivel de página: qué blob corresponde al
/// "resto de la libreta" (vault v3) o al payload completo (v2), y qué blob
/// corresponde a cada página. Permite decidir por página qué descargar sin
/// bajar contenido.
class DeviceSyncManifestPageBlobIds {
  const DeviceSyncManifestPageBlobIds({
    required this.vaultBlobId,
    required this.pageBlobIds,
  });

  /// `payloadBlobId` (v2) o `vaultBlobId` (v3) — el "resto" no-por-página.
  final String vaultBlobId;

  /// `pageId -> blobId`. Vacío en manifiestos v2 (no hay páginas sueltas).
  final Map<String, String> pageBlobIds;
}

/// Lee el manifiesto y devuelve el blob del resto de la libreta + el mapa
/// `pageId -> blobId` de cada página, sin descargar ningún blob de contenido.
/// Es lo que permite calcular qué páginas cambiaron en la nube comparando
/// contra el último manifiesto aplicado, sin tráfico de red adicional.
Future<DeviceSyncManifestPageBlobIds> peekDeviceSyncManifestPageBlobIds({
  required String manifestStoragePath,
  required SecretKey packKey,
}) async {
  final manifestCipher = await folioStorageGetData(
    manifestStoragePath,
    16 * 1024 * 1024,
  );
  if (manifestCipher == null || manifestCipher.isEmpty) {
    return const DeviceSyncManifestPageBlobIds(vaultBlobId: '', pageBlobIds: {});
  }
  final manifestPlain = await cloudPackDecryptBytes(
    blob: manifestCipher,
    packKey: packKey,
  );
  final decoded = jsonDecode(utf8.decode(manifestPlain));
  if (decoded is! Map) {
    return const DeviceSyncManifestPageBlobIds(vaultBlobId: '', pageBlobIds: {});
  }
  final map = Map<String, dynamic>.from(decoded);
  final format = map['format'];
  if (format != kDeviceSyncManifestFormatV2 &&
      format != kDeviceSyncManifestFormatV3) {
    return const DeviceSyncManifestPageBlobIds(vaultBlobId: '', pageBlobIds: {});
  }
  if (format == kDeviceSyncManifestFormatV2) {
    final payloadBlobId = '${map['payloadBlobId'] ?? ''}'.trim().toLowerCase();
    return DeviceSyncManifestPageBlobIds(
      vaultBlobId: cloudPackIsValidBlobId(payloadBlobId) ? payloadBlobId : '',
      pageBlobIds: const {},
    );
  }
  final vaultBlobId = '${map['vaultBlobId'] ?? ''}'.trim().toLowerCase();
  final pageBlobIds = <String, String>{};
  final pagesRaw = map['pages'];
  if (pagesRaw is List) {
    for (final item in pagesRaw) {
      if (item is! Map) continue;
      final pageId = '${item['pageId'] ?? ''}'.trim();
      final blobId = '${item['blobId'] ?? ''}'.trim().toLowerCase();
      if (pageId.isEmpty || !cloudPackIsValidBlobId(blobId)) continue;
      pageBlobIds[pageId] = blobId;
    }
  }
  return DeviceSyncManifestPageBlobIds(
    vaultBlobId: cloudPackIsValidBlobId(vaultBlobId) ? vaultBlobId : '',
    pageBlobIds: pageBlobIds,
  );
}

/// Lee solo los blobIds del manifiesto (sin descargar blobs de contenido).
Future<Set<String>> peekDeviceSyncManifestBlobIds({
  required String manifestStoragePath,
  required SecretKey packKey,
}) async {
  final manifestCipher = await folioStorageGetData(
    manifestStoragePath,
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
  final format = map['format'];
  if (format != kDeviceSyncManifestFormatV2 &&
      format != kDeviceSyncManifestFormatV3) {
    return {};
  }
  final out = <String>{};
  if (format == kDeviceSyncManifestFormatV2) {
    final payloadBlobId = '${map['payloadBlobId'] ?? ''}'.trim().toLowerCase();
    if (cloudPackIsValidBlobId(payloadBlobId)) out.add(payloadBlobId);
  } else {
    final vaultBlobId = '${map['vaultBlobId'] ?? ''}'.trim().toLowerCase();
    if (cloudPackIsValidBlobId(vaultBlobId)) out.add(vaultBlobId);
    final pagesRaw = map['pages'];
    if (pagesRaw is List) {
      for (final item in pagesRaw) {
        if (item is! Map) continue;
        final blobId = '${item['blobId'] ?? ''}'.trim().toLowerCase();
        if (cloudPackIsValidBlobId(blobId)) out.add(blobId);
      }
    }
  }
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
  /// Payload local ya conocido, usado para reponer páginas/resto cuyo blobId
  /// remoto coincide con [knownPageBlobIds]/[knownVaultBlobId] sin
  /// descargarlas de nuevo (sync incremental por página).
  VaultPayload? knownLocalPayload,
  Map<String, String> knownPageBlobIds = const {},
  String knownVaultBlobId = '',
}) async {
  AppLogger.info(
    'incremental pull start',
    tag: 'cloud_sync',
    context: {'manifest': manifestStoragePath},
  );
  final manifestCipher = await folioStorageGetData(
    manifestStoragePath,
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
  final format = map['format'];
  final isV3 = format == kDeviceSyncManifestFormatV3;
  final isV2 = format == kDeviceSyncManifestFormatV2;
  if (!isV2 && !isV3) {
    throw StateError('Unsupported device-sync manifest format: $format');
  }

  // v2: un único blob con todo el payload. v3: un blob "resto de libreta" +
  // un blob por página. Ambos casos se resuelven a un conjunto de blobs de
  // contenido antes de descargar, para reutilizar el mismo downloader.
  final manifestPageCountRaw = map['pageCount'];
  final manifestPageCount =
      manifestPageCountRaw is num ? manifestPageCountRaw.toInt() : null;

  String payloadBlobId = '';
  final pageSpecs = <({String pageId, String blobId})>[];
  if (isV2) {
    payloadBlobId = '${map['payloadBlobId'] ?? ''}'.trim().toLowerCase();
    if (!cloudPackIsValidBlobId(payloadBlobId)) {
      throw StateError('Invalid payloadBlobId');
    }
  } else {
    payloadBlobId = '${map['vaultBlobId'] ?? ''}'.trim().toLowerCase();
    if (!cloudPackIsValidBlobId(payloadBlobId)) {
      throw StateError('Invalid vaultBlobId');
    }
    final pagesRaw = map['pages'];
    if (pagesRaw is List) {
      for (final item in pagesRaw) {
        if (item is! Map) continue;
        final pageId = '${item['pageId'] ?? ''}'.trim();
        final blobId = '${item['blobId'] ?? ''}'.trim().toLowerCase();
        if (pageId.isEmpty || !cloudPackIsValidBlobId(blobId)) continue;
        pageSpecs.add((pageId: pageId, blobId: blobId));
      }
    }
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

  final allIds = <String>{
    payloadBlobId,
    ...pageSpecs.map((e) => e.blobId),
    ...attSpecs.map((e) => e.blobId),
  };

  final localPagesById = <String, FolioPage>{
    for (final p in knownLocalPayload?.pages ?? const <FolioPage>[]) p.id: p,
  };
  final canReuseRest = isV3 &&
      knownLocalPayload != null &&
      knownVaultBlobId.isNotEmpty &&
      payloadBlobId == knownVaultBlobId;
  bool canReusePage(({String pageId, String blobId}) spec) =>
      knownLocalPayload != null &&
      localPagesById.containsKey(spec.pageId) &&
      knownPageBlobIds[spec.pageId] == spec.blobId;

  final toDownloadIds = <String>{
    if (!canReuseRest) payloadBlobId,
    ...pageSpecs.where((s) => !canReusePage(s)).map((e) => e.blobId),
    ...attSpecs.map((e) => e.blobId),
  };
  final total = toDownloadIds.length;

  final pathParts = manifestStoragePath.split('/');
  if (pathParts.length < 6) {
    throw StateError('Cannot resolve blob path from manifest');
  }
  final uid = pathParts[1];
  final vaultId = pathParts[3];

  // 1) Descarga concurrente de los ciphertexts que hagan falta (red). El
  // progreso avanza aquí porque es la parte que domina el tiempo real.
  final cipherByBlobId = <String, Uint8List>{};
  var downloaded = 0;
  await mapConcurrent(toDownloadIds.toList(), (blobId) async {
    final path = 'users/$uid/vaults/$vaultId/device-sync/blobs/$blobId';
    try {
      final cipher = await folioStorageGetData(
        path,
        kFolioStorageMaxObjectBytes,
      );
      if (cipher == null || cipher.isEmpty) {
        throw StateError('Missing device-sync blob $blobId');
      }
      cipherByBlobId[blobId] = cipher;
      downloaded++;
      onProgress?.call(downloaded, total, total == 0 ? 1.0 : downloaded / total);
    } catch (e) {
      AppLogger.error(
        'incremental pull blob failed',
        tag: 'cloud_sync',
        error: e,
        context: {'path': path, 'blobId': blobId},
      );
      throw StateError('device-sync blob missing or unreadable: $path');
    }
  }, concurrency: 4);

  // 2) Descifrado en lote en un isolate aparte (evita un AES-GCM por blob en
  // el isolate de UI — antes intercalado con cada descarga).
  final orderedIds = cipherByBlobId.keys.toList();
  final decrypted = await compute(_decryptPackItemsIsolate, {
    'keyBytes': Uint8List.fromList(await packKey.extractBytes()),
    'ciphers': [for (final id in orderedIds) cipherByBlobId[id]!],
  });
  final plainByBlobId = <String, Uint8List>{
    for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: decrypted[i],
  };

  Uint8List blobPlain(String blobId) {
    final v = plainByBlobId[blobId];
    if (v == null) {
      throw StateError('device-sync blob not fetched: $blobId');
    }
    return v;
  }

  final Map<String, dynamic> payloadJson;
  if (isV2) {
    final payloadBytes = blobPlain(payloadBlobId);
    final decodedPayload = jsonDecode(utf8.decode(payloadBytes));
    if (decodedPayload is! Map) {
      throw StateError('Invalid device-sync payload');
    }
    payloadJson = Map<String, dynamic>.from(decodedPayload);
  } else {
    final Map<String, dynamic> decodedRest;
    if (canReuseRest) {
      decodedRest = knownLocalPayload.restJsonExcludingPages();
    } else {
      final restBytes = blobPlain(payloadBlobId);
      final decoded = jsonDecode(utf8.decode(restBytes));
      if (decoded is! Map) {
        throw StateError('Invalid device-sync vault blob');
      }
      decodedRest = Map<String, dynamic>.from(decoded);
    }
    final pageSlices = pageSpecs.map((spec) {
      if (canReusePage(spec)) {
        return VaultPayload.pageSliceJson(
          localPagesById[spec.pageId]!,
          knownLocalPayload!.comments,
        );
      }
      final pageBytes = blobPlain(spec.blobId);
      final decodedSlice = jsonDecode(utf8.decode(pageBytes));
      if (decodedSlice is! Map) {
        throw StateError('Invalid device-sync page blob (${spec.pageId})');
      }
      return Map<String, dynamic>.from(decodedSlice);
    }).toList();
    payloadJson = VaultPayload.mergeRestAndPageSlices(decodedRest, pageSlices);
  }

  final attachments = attSpecs.map((spec) {
    final bytes = blobPlain(spec.blobId);
    return VaultSyncPackAttachment(
      path: spec.path,
      sha256Hex: spec.sha,
      bytes: bytes,
    );
  }).toList();

  final pack = VaultSyncPack(
    payload: VaultPayload.fromJson(Map<String, dynamic>.from(payloadJson)),
    attachments: attachments,
  );

  final packBytes = Uint8List.fromList(await pack.encodeUtf8Async());
  AppLogger.info(
    'incremental pull ok',
    tag: 'cloud_sync',
    context: {
      'blobs': allIds.length,
      'downloaded': toDownloadIds.length,
      'reused': allIds.length - toDownloadIds.length,
      'attachments': attachments.length,
      'packBytes': packBytes.length,
    },
  );

  return DeviceSyncPullResult(
    packBytes: packBytes,
    blobIds: allIds,
    vaultBlobId: isV3 ? payloadBlobId : '',
    pageBlobIds: isV3
        ? {for (final s in pageSpecs) s.pageId: s.blobId}
        : const {},
    manifestPageCount: isV3 ? manifestPageCount : null,
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
