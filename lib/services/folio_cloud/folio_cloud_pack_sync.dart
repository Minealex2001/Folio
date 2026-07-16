import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'folio_storage_transport.dart';
import 'package:path/path.dart' as p;

import '../../app/app_settings.dart';
import '../../data/folio_cloud_pack_format.dart';
import '../../data/vault_backup.dart';
import '../../data/vault_paths.dart';
import '../../session/vault_session.dart';
import '../folio_telemetry.dart';
import '../app_logger.dart';
import '../vault_pack/vault_pack_builder.dart';
import 'folio_cloud_backup.dart';
import 'folio_cloud_callable.dart';
import '../../crypto/vault_crypto.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_pack_crypto.dart';
import '../vault_cloud_pack_progress.dart';

void _logSyncTelemetry(
  AppSettings? settings,
  String syncType,
  bool success, {
  String? errorMessage,
  int? durationMs,
}) {
  final s = settings;
  if (s == null || !s.telemetryEnabled) return;
  unawaited(
    FolioTelemetry.logSyncEvent(
      s,
      syncType,
      success,
      errorMessage: errorMessage,
      durationMs: durationMs,
    ),
  );
}

/// Sube la libreta abierta como cloud-pack incremental (blobs cifrados + snapshot).
///
/// [restoreWrapPassword]: contraseña de la libreta (cifrada) o contraseña de recuperación
/// (sin cifrado) para guardar en el servidor un envoltorio que permite restaurar en un
/// dispositivo nuevo. Si es null y hace falta el primer envoltorio en una libreta cifrada,
/// la subida fallará con un error explícito.
Future<String?> uploadOpenVaultCloudPack({
  required VaultSession session,
  required String vaultId,
  FolioCloudSnapshot? entitlementSnapshot,
  String? restoreWrapPassword,
  AppSettings? telemetrySettings,
  OnVaultCloudPackProgress? onProgress,
}) async {
  final sw = Stopwatch()..start();
  try {
  requireFolioCloudBackupEntitlement(entitlementSnapshot);
  if (!session.isUnlocked) {
    throw StateError(
      'La libreta debe estar desbloqueada para subir la copia a la nube.',
    );
  }
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');

  void rep(VaultCloudPackProgressStep step, double progress01) {
    onProgress?.call(
      VaultCloudPackProgress(
        progress: progress01.clamp(0.0, 1.0),
        step: step,
      ),
    );
  }

  rep(VaultCloudPackProgressStep.preparing, 0.02);
  rep(VaultCloudPackProgressStep.persisting, 0.04);
  await session.persistNow();
  rep(VaultCloudPackProgressStep.fingerprinting, 0.07);
  final contentFp = await computeVaultCloudPackContentFingerprint();

  rep(VaultCloudPackProgressStep.fetchingMeta, 0.09);
  final latest = await _getLatestCloudPackMeta(vaultId: vaultId);
  final hasRestoreWrap = latest?['hasRestoreWrap'] == true;
  final pw = restoreWrapPassword?.trim() ?? '';
  if (pw.isEmpty && session.vaultUsesEncryption && !hasRestoreWrap) {
    throw StateError(
      'Se necesita la contraseña de la libreta una vez para permitir restaurar '
      'esta copia incremental en otro dispositivo.',
    );
  }
  final plainNeedsWrap = !session.vaultUsesEncryption && !hasRestoreWrap;
  final mustNotSkipUploadForWrap =
      (pw.isNotEmpty && !hasRestoreWrap) || plainNeedsWrap;
  final latestFp = latest?['contentFingerprint']?.toString().trim() ?? '';
  if (!mustNotSkipUploadForWrap &&
      latestFp.isNotEmpty &&
      latestFp == contentFp) {
    final sp = latest?['snapshotStoragePath']?.toString().trim() ?? '';
    if (sp.isNotEmpty) {
      try {
        final u = await FirebaseStorage.instance.ref(sp).getDownloadURL();
        _logSyncTelemetry(
          telemetrySettings,
          'cloud_pack_push',
          true,
          durationMs: sw.elapsedMilliseconds,
        );
        rep(VaultCloudPackProgressStep.skippedUpToDate, 1.0);
        return u;
      } catch (_) {}
    }
    _logSyncTelemetry(
      telemetrySettings,
      'cloud_pack_push',
      true,
      durationMs: sw.elapsedMilliseconds,
    );
    rep(VaultCloudPackProgressStep.skippedUpToDate, 1.0);
    return '';
  }

  final packKey = await session.cloudPackEncryptionKey();

  if (pw.isNotEmpty || plainNeedsWrap) {
    rep(VaultCloudPackProgressStep.restoreWrap, 0.11);
  }

  Uint8List? restoreWrapBytes;
  String? restoreWrapKind;
  if (pw.isNotEmpty) {
    if (session.vaultUsesEncryption) {
      final dek = session.cloudPackRestoreDekMaterial;
      if (dek == null) {
        throw StateError(
          'No se pudo leer la DEK para el envoltorio de recuperación.',
        );
      }
      restoreWrapBytes = await VaultCrypto.wrapDek(dek: dek, password: pw);
      restoreWrapKind = 'vaultDek';
    } else {
      final rawPk = await packKey.extractBytes();
      restoreWrapBytes = await VaultCrypto.wrapDek(
        dek: Uint8List.fromList(rawPk),
        password: pw,
      );
      restoreWrapKind = 'packKey';
    }
  } else if (plainNeedsWrap) {
    // Libreta sin cifrado: crear restore wrap con contraseña vacía para
    // permitir restaurar en otro dispositivo sin necesidad de contraseña.
    final rawPk = await packKey.extractBytes();
    restoreWrapBytes = await VaultCrypto.wrapDek(
      dek: Uint8List.fromList(rawPk),
      password: '',
    );
    restoreWrapKind = 'packKey';
  }

  FolioCloudPackSnapshotManifest? oldManifest;
  final oldSnapPath = latest?['snapshotStoragePath']?.toString().trim() ?? '';
  final oldSnapSize = _parseInt(latest?['snapshotSizeBytes']);
  if (oldSnapPath.isNotEmpty) {
    rep(VaultCloudPackProgressStep.downloadingPreviousManifest, 0.125);
    oldManifest = await _downloadDecryptManifest(
      storagePath: oldSnapPath,
      packKey: packKey,
    );
  }
  rep(VaultCloudPackProgressStep.indexingLocal, 0.135);

  final built = await buildVaultPackSnapshot(
    packKey: packKey,
    contentFingerprint: contentFp,
  );
  final items = built.manifest.items;
  final snapClear = built.manifest;
  final totalBlobs = built.blobs.length;
  var blobsDone = 0;

  for (final b in built.blobs) {
    await _ensureBlobUploaded(
      uid: user.uid,
      vaultId: vaultId,
      blobId: b.item.blobId,
      bytes: b.cipherBytes,
    );
    blobsDone++;
    final frac = totalBlobs <= 0 ? 1.0 : blobsDone / totalBlobs;
    onProgress?.call(
      VaultCloudPackProgress(
        progress: (0.15 + 0.58 * frac).clamp(0.0, 0.93),
        step: VaultCloudPackProgressStep.uploadingBlob,
        blobRole: b.item.role,
        attachmentRelativePath: b.item.relativePath,
        blobsCompleted: blobsDone,
        blobsTotal: totalBlobs,
      ),
    );
  }

  final snapCipher = await cloudPackEncryptSnapshotManifest(snapClear, packKey);

  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final snapName = 'snap-$stamp.bin';
  final snapRef = FirebaseStorage.instance.ref().child(
    'users/${user.uid}/vaults/$vaultId/cloud-packs/snapshots/$snapName',
  );
  rep(VaultCloudPackProgressStep.uploadingSnapshot, 0.76);
  await folioStoragePutData(snapRef, snapCipher);
  final snapSize = snapCipher.length;

  final oldIds = oldManifest == null
      ? <String, int>{}
      : {for (final i in oldManifest.items) i.blobId: 1};
  final newIds = {for (final i in items) i.blobId: 1};

  final deleteList = <Map<String, dynamic>>[];
  for (final id in oldIds.keys) {
    if (!newIds.containsKey(id)) {
      final sz = await _blobSizeIfExists(
        uid: user.uid,
        vaultId: vaultId,
        blobId: id,
      );
      if (sz != null && sz > 0) {
        deleteList.add(<String, dynamic>{'blobId': id, 'sizeBytes': sz});
      }
    }
  }

  final newBlobList = <Map<String, dynamic>>[];
  for (final i in items) {
    if (!oldIds.containsKey(i.blobId)) {
      final sz = await _blobSizeIfExists(
        uid: user.uid,
        vaultId: vaultId,
        blobId: i.blobId,
      );
      if (sz != null && sz > 0) {
        newBlobList.add(<String, dynamic>{'blobId': i.blobId, 'sizeBytes': sz});
      }
    }
  }

  rep(VaultCloudPackProgressStep.finalizing, 0.82);
  try {
    await callFolioHttpsCallable('folioFinalizeCloudPack', <String, dynamic>{
      'vaultId': vaultId,
      'snapshotStoragePath': snapRef.fullPath,
      'snapshotSizeBytes': snapSize,
      'contentFingerprint': contentFp,
      'oldSnapshotStoragePath': oldSnapPath.isNotEmpty ? oldSnapPath : null,
      'oldSnapshotSizeBytes': oldSnapSize > 0 ? oldSnapSize : null,
      'newBlobs': newBlobList,
      'deleteBlobs': deleteList,
      if (restoreWrapBytes != null &&
          restoreWrapKind != null) ...<String, dynamic>{
        'cloudPackRestoreWrapB64': base64Encode(restoreWrapBytes),
        'cloudPackRestoreWrapKind': restoreWrapKind,
      },
    });
  } catch (e) {
    await _rollbackFailedCloudPackUpload(
      uid: user.uid,
      vaultId: vaultId,
      snapshotPath: snapRef.fullPath,
      newBlobIds: newBlobList
          .map((b) => b['blobId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
    );
    rethrow;
  }

  rep(VaultCloudPackProgressStep.cleaningOldBlobs, 0.88);
  if (oldSnapPath.isNotEmpty && oldSnapPath != snapRef.fullPath) {
    try {
      await FirebaseStorage.instance.ref(oldSnapPath).delete();
    } catch (e) {
      AppLogger.warn(
        'No se pudo borrar snapshot antiguo tras cloud-pack',
        tag: 'cloud-pack',
        context: {'path': oldSnapPath, 'error': '$e'},
      );
    }
  }

  for (final d in deleteList) {
    final bid = d['blobId']?.toString() ?? '';
    if (bid.isEmpty) continue;
    try {
      await FirebaseStorage.instance
          .ref('users/${user.uid}/vaults/$vaultId/cloud-packs/blobs/$bid')
          .delete();
    } catch (e) {
      AppLogger.warn(
        'No se pudo borrar blob obsoleto tras cloud-pack',
        tag: 'cloud-pack',
        context: {'blobId': bid, 'error': '$e'},
      );
    }
  }

  rep(VaultCloudPackProgressStep.updatingVaultIndex, 0.93);
  try {
    await upsertFolioCloudBackupVaultIndex(
      vaultId: vaultId,
      displayName: await session.getActiveVaultDisplayLabel(),
      entitlementSnapshot: entitlementSnapshot,
    );
  } catch (e) {
    AppLogger.warn(
      'Cloud-pack subido pero falló actualizar índice de libreta',
      tag: 'cloud-pack',
      context: {'vaultId': vaultId, 'error': '$e'},
    );
  }

  final url = await snapRef.getDownloadURL();
  rep(VaultCloudPackProgressStep.complete, 1.0);
  _logSyncTelemetry(
    telemetrySettings,
    'cloud_pack_push',
    true,
    durationMs: sw.elapsedMilliseconds,
  );
  return url;
  } catch (e) {
    _logSyncTelemetry(
      telemetrySettings,
      'cloud_pack_push',
      false,
      errorMessage: '$e',
      durationMs: sw.elapsedMilliseconds,
    );
    rethrow;
  }
}

int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

Future<Map<String, dynamic>?> _getLatestCloudPackMeta({
  required String vaultId,
}) async {
  final raw = await callFolioHttpsCallable(
    'folioGetLatestCloudPackMeta',
    <String, dynamic>{'vaultId': vaultId},
  );
  if (raw is! Map) return null;
  final latest = raw['latest'];
  if (latest is! Map) return null;
  return Map<String, dynamic>.from(latest);
}

/// `true` si el último cloud-pack de [vaultId] es de una libreta sin cifrado
/// (envoltorio de recuperación tipo `packKey`, contraseña vacía); `false` si
/// es de una libreta cifrada (`vaultDek`, contraseña real); `null` si aún no
/// hay envoltorio o no se pudo consultar. No requiere contraseña: solo lee
/// metadatos, permite decidir si mostrar el campo de contraseña al restaurar
/// (ver onboarding, "restaurar en otro dispositivo").
Future<bool?> cloudPackRestoreIsPlainVault({required String vaultId}) async {
  final latest = await _getLatestCloudPackMeta(vaultId: vaultId);
  final kind = latest?['wrapKind']?.toString().trim() ?? '';
  if (kind == 'packKey') return true;
  if (kind == 'vaultDek') return false;
  return null;
}

Future<FolioCloudPackSnapshotManifest?> _downloadDecryptManifest({
  required String storagePath,
  required SecretKey packKey,
}) async {
  final max = 32 * 1024 * 1024;
  final data = await folioStorageGetData(
    FirebaseStorage.instance.ref(storagePath),
    max,
  );
  if (data == null || data.isEmpty) return null;
  return cloudPackDecryptSnapshotManifest(cipherBlob: data, packKey: packKey);
}

Future<void> _ensureBlobUploaded({
  required String uid,
  required String vaultId,
  required String blobId,
  required List<int> bytes,
}) async {
  final ref = FirebaseStorage.instance.ref().child(
    'users/$uid/vaults/$vaultId/cloud-packs/blobs/$blobId',
  );
  // Comprobar existencia en Storage desde el cliente (mismas reglas que la subida).
  // Evita `folioCheckCloudPackBlobsExist`, que en escritorio usa HTTP callable y puede
  // acabar en 504 por tiempo agotado en la cadena Functions → GCS.
  try {
    await ref.getMetadata();
    return;
  } on FirebaseException catch (e) {
    final c = e.code;
    if (c != 'object-not-found' && c != 'storage/object-not-found') {
      rethrow;
    }
  }
  await folioStoragePutData(ref, Uint8List.fromList(bytes));
}

Future<int?> _blobSizeIfExists({
  required String uid,
  required String vaultId,
  required String blobId,
}) async {
  final ref = FirebaseStorage.instance.ref().child(
    'users/$uid/vaults/$vaultId/cloud-packs/blobs/$blobId',
  );
  try {
    final m = await ref.getMetadata();
    return m.size ?? 0;
  } catch (_) {
    return null;
  }
}

/// Limpia snapshot y blobs recién subidos si falla `folioFinalizeCloudPack`.
Future<void> _rollbackFailedCloudPackUpload({
  required String uid,
  required String vaultId,
  required String snapshotPath,
  required List<String> newBlobIds,
}) async {
  try {
    await FirebaseStorage.instance.ref(snapshotPath).delete();
  } catch (_) {}
  for (final blobId in newBlobIds) {
    try {
      await FirebaseStorage.instance
          .ref('users/$uid/vaults/$vaultId/cloud-packs/blobs/$blobId')
          .delete();
    } catch (_) {}
  }
}

/// Descarga el último cloud-pack y lo deja en [extractDir] (estructura de copia).
Future<void> downloadLatestCloudPackToDirectory({
  required VaultSession session,
  required String vaultId,
  required Directory extractDir,
  FolioCloudSnapshot? entitlementSnapshot,
  AppSettings? telemetrySettings,
}) async {
  final sw = Stopwatch()..start();
  try {
    requireFolioCloudBackupEntitlement(entitlementSnapshot);
    if (!session.isUnlocked) {
      throw StateError('La libreta debe estar desbloqueada.');
    }
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase not initialized');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final latest = await _getLatestCloudPackMeta(vaultId: vaultId);
    final path = latest?['snapshotStoragePath']?.toString().trim() ?? '';
    if (path.isEmpty) {
      throw StateError('No hay copia incremental en la nube.');
    }

    final packKey = await session.cloudPackEncryptionKey();
    await _downloadCloudPackTreeToDirectory(
      uid: user.uid,
      vaultId: vaultId,
      snapshotStoragePath: path,
      packKey: packKey,
      extractDir: extractDir,
    );
    _logSyncTelemetry(
      telemetrySettings,
      'cloud_pack_pull',
      true,
      durationMs: sw.elapsedMilliseconds,
    );
  } catch (e) {
    _logSyncTelemetry(
      telemetrySettings,
      'cloud_pack_pull',
      false,
      errorMessage: '$e',
      durationMs: sw.elapsedMilliseconds,
    );
    rethrow;
  }
}

/// Restaura el último cloud-pack en [extractDir] usando el envoltorio de recuperación
/// (contraseña de la libreta cifrada o la contraseña de recuperación si la libreta está en claro).
Future<void> downloadCloudPackToDirectoryForRestore({
  required String vaultId,
  required String restorePassword,
  required Directory extractDir,
  FolioCloudSnapshot? entitlementSnapshot,
  AppSettings? telemetrySettings,
}) async {
  final sw = Stopwatch()..start();
  try {
  requireFolioCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');

  final wrapRaw = await callFolioHttpsCallable(
    'folioGetCloudPackRestoreWrap',
    <String, dynamic>{'vaultId': vaultId},
  );
  if (wrapRaw is! Map) {
    throw StateError('Respuesta inválida del envoltorio de recuperación.');
  }
  final wrapB64 = wrapRaw['wrapB64']?.toString().trim() ?? '';
  final kind = wrapRaw['wrapKind']?.toString().trim() ?? '';
  if (wrapB64.isEmpty || (kind != 'vaultDek' && kind != 'packKey')) {
    throw StateError('Falta el envoltorio de recuperación para esta libreta.');
  }
  final wrapBytes = Uint8List.fromList(base64Decode(wrapB64));
  final unwrapped = await VaultCrypto.unwrapDek(
    wrapped: wrapBytes,
    password: restorePassword,
  );
  final SecretKey packKey = kind == 'vaultDek'
      ? await VaultCrypto.dekFromBytes(unwrapped)
      : SecretKey(unwrapped);

  final latest = await _getLatestCloudPackMeta(vaultId: vaultId);
  final path = latest?['snapshotStoragePath']?.toString().trim() ?? '';
  if (path.isEmpty) {
    throw StateError('No hay copia incremental en la nube.');
  }

  await _downloadCloudPackTreeToDirectory(
    uid: user.uid,
    vaultId: vaultId,
    snapshotStoragePath: path,
    packKey: packKey,
    extractDir: extractDir,
  );
  _logSyncTelemetry(
    telemetrySettings,
    'cloud_pack_pull_restore',
    true,
    durationMs: sw.elapsedMilliseconds,
  );
  } catch (e) {
    _logSyncTelemetry(
      telemetrySettings,
      'cloud_pack_pull_restore',
      false,
      errorMessage: '$e',
      durationMs: sw.elapsedMilliseconds,
    );
    rethrow;
  }
}

Future<void> _downloadCloudPackTreeToDirectory({
  required String uid,
  required String vaultId,
  required String snapshotStoragePath,
  required SecretKey packKey,
  required Directory extractDir,
}) async {
  final manifest = await _downloadDecryptManifest(
    storagePath: snapshotStoragePath,
    packKey: packKey,
  );
  if (manifest == null) {
    throw StateError('No se pudo leer la copia incremental (clave o datos).');
  }

  if (!extractDir.existsSync()) {
    await extractDir.create(recursive: true);
  }

  for (final item in manifest.items) {
    final ref = FirebaseStorage.instance.ref().child(
      'users/$uid/vaults/$vaultId/cloud-packs/blobs/${item.blobId}',
    );
    final max = 512 * 1024 * 1024;
    final data = await folioStorageGetData(ref, max);
    if (data == null || data.isEmpty) {
      throw StateError('Falta un blob en la nube: ${item.blobId}');
    }
    final clear = await cloudPackDecryptBytes(blob: data, packKey: packKey);

    switch (item.role) {
      case FolioCloudPackBlobRole.backupManifest:
        await File(
          p.join(extractDir.path, kVaultBackupManifestFile),
        ).writeAsBytes(clear, flush: true);
      case FolioCloudPackBlobRole.vaultKeys:
        await File(
          p.join(extractDir.path, VaultPaths.wrappedDekFile),
        ).writeAsBytes(clear, flush: true);
      case FolioCloudPackBlobRole.vaultBin:
        await File(
          p.join(extractDir.path, VaultPaths.cipherPayloadFile),
        ).writeAsBytes(clear, flush: true);
      case FolioCloudPackBlobRole.vaultMode:
        await File(
          p.join(extractDir.path, VaultPaths.vaultModeFile),
        ).writeAsBytes(clear, flush: true);
      case FolioCloudPackBlobRole.attachment:
        final rel = item.relativePath!;
        final out = File(p.join(extractDir.path, rel));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(clear, flush: true);
    }
  }
}
