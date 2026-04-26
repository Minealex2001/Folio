import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../../app/app_settings.dart';
import '../../data/folio_cloud_pack_format.dart';
import '../../data/vault_backup.dart';
import '../../data/vault_paths.dart';
import '../../session/vault_session.dart';
import '../folio_telemetry.dart';
import 'folio_cloud_backup.dart';
import 'folio_cloud_callable.dart';
import '../../crypto/vault_crypto.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_pack_crypto.dart';

List<int> _nonceBasisManifest() => utf8.encode('folio-pack:manifest');

List<int> _nonceBasisVaultKeys() => utf8.encode('folio-pack:vault_keys');

List<int> _nonceBasisVaultBin() => utf8.encode('folio-pack:vault_bin');

List<int> _nonceBasisVaultMode() => utf8.encode('folio-pack:vault_mode');

List<int> _nonceBasisAttachment(String posixPath) =>
    utf8.encode('folio-pack:att:$posixPath');

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

  await session.persistNow();
  final contentFp = await computeVaultCloudPackContentFingerprint();

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
        return u;
      } catch (_) {}
    }
    _logSyncTelemetry(
      telemetrySettings,
      'cloud_pack_push',
      true,
      durationMs: sw.elapsedMilliseconds,
    );
    return '';
  }

  final packKey = await session.cloudPackEncryptionKey();

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
    oldManifest = await _downloadDecryptManifest(
      storagePath: oldSnapPath,
      packKey: packKey,
    );
  }

  final wrapped = await VaultPaths.wrappedDekPath();
  final cipher = await VaultPaths.cipherPayloadPath();
  final modeFile = await VaultPaths.vaultModePath();
  if (!cipher.existsSync()) {
    throw StateError('No hay libreta para exportar.');
  }
  final plain = _modeFileIsPlainCloud(modeFile);
  if (!plain && !wrapped.existsSync()) {
    throw StateError('No hay libreta para exportar.');
  }

  final manifestJson = jsonEncode(<String, Object?>{
    'formatVersion': kVaultBackupFormatVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'appName': 'Folio',
  });
  final manifestPlain = utf8.encode(manifestJson);

  final items = <FolioCloudPackSnapshotItem>[];

  Future<void> addBlob({
    required FolioCloudPackBlobRole role,
    required List<int> plainBytes,
    required List<int> nonceBasis,
    String? attachmentPosix,
  }) async {
    final cipherBytes = await cloudPackEncryptPlainBlob(
      plain: plainBytes,
      packKey: packKey,
      nonceBasis: nonceBasis,
    );
    final id = await cloudPackBlobIdFromCipherBytes(cipherBytes);
    items.add(
      FolioCloudPackSnapshotItem(
        role: role,
        blobId: id,
        relativePath: attachmentPosix,
      ),
    );
    await _ensureBlobUploaded(
      uid: user.uid,
      vaultId: vaultId,
      blobId: id,
      bytes: cipherBytes,
    );
  }

  await addBlob(
    role: FolioCloudPackBlobRole.backupManifest,
    plainBytes: manifestPlain,
    nonceBasis: _nonceBasisManifest(),
  );

  if (!plain && wrapped.existsSync()) {
    await addBlob(
      role: FolioCloudPackBlobRole.vaultKeys,
      plainBytes: await wrapped.readAsBytes(),
      nonceBasis: _nonceBasisVaultKeys(),
    );
  }

  await addBlob(
    role: FolioCloudPackBlobRole.vaultBin,
    plainBytes: await cipher.readAsBytes(),
    nonceBasis: _nonceBasisVaultBin(),
  );

  if (modeFile.existsSync()) {
    await addBlob(
      role: FolioCloudPackBlobRole.vaultMode,
      plainBytes: await modeFile.readAsBytes(),
      nonceBasis: _nonceBasisVaultMode(),
    );
  }

  final vaultDir = await VaultPaths.vaultDirectory();
  final attDir = Directory(
    p.join(vaultDir.path, VaultPaths.attachmentsDirName),
  );
  final attPaths = <String>[];
  if (attDir.existsSync()) {
    await for (final entity in attDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: attDir.path)
          .replaceAll(r'\', '/');
      attPaths.add('${VaultPaths.attachmentsDirName}/$rel');
    }
    attPaths.sort();
    for (final posix in attPaths) {
      final f = File(p.join(vaultDir.path, posix));
      if (!f.existsSync()) continue;
      await addBlob(
        role: FolioCloudPackBlobRole.attachment,
        plainBytes: await f.readAsBytes(),
        nonceBasis: _nonceBasisAttachment(posix),
        attachmentPosix: posix,
      );
    }
  }

  final snapClear = FolioCloudPackSnapshotManifest(
    formatVersion: kFolioCloudPackFormatVersion,
    createdAtUtc: DateTime.now().toUtc().toIso8601String(),
    items: items,
    contentFingerprint: contentFp,
  );
  final snapCipher = await cloudPackEncryptSnapshotManifest(snapClear, packKey);

  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final snapName = 'snap-$stamp.bin';
  final snapRef = FirebaseStorage.instance.ref().child(
    'users/${user.uid}/vaults/$vaultId/cloud-packs/snapshots/$snapName',
  );
  await snapRef.putData(snapCipher);
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

  if (oldSnapPath.isNotEmpty && oldSnapPath != snapRef.fullPath) {
    try {
      await FirebaseStorage.instance.ref(oldSnapPath).delete();
    } catch (_) {}
  }

  for (final d in deleteList) {
    final bid = d['blobId']?.toString() ?? '';
    if (bid.isEmpty) continue;
    try {
      await FirebaseStorage.instance
          .ref('users/${user.uid}/vaults/$vaultId/cloud-packs/blobs/$bid')
          .delete();
    } catch (_) {}
  }

  try {
    await upsertFolioCloudBackupVaultIndex(
      vaultId: vaultId,
      displayName: await session.getActiveVaultDisplayLabel(),
      entitlementSnapshot: entitlementSnapshot,
    );
  } catch (_) {}

  final url = await snapRef.getDownloadURL();
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

bool _modeFileIsPlainCloud(File modeFile) {
  if (!modeFile.existsSync()) return false;
  return modeFile.readAsStringSync().trim().toLowerCase() == 'plain';
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

Future<FolioCloudPackSnapshotManifest?> _downloadDecryptManifest({
  required String storagePath,
  required SecretKey packKey,
}) async {
  final max = 32 * 1024 * 1024;
  final data = await FirebaseStorage.instance.ref(storagePath).getData(max);
  if (data == null || data.isEmpty) return null;
  return cloudPackDecryptSnapshotManifest(cipherBlob: data, packKey: packKey);
}

Future<void> _ensureBlobUploaded({
  required String uid,
  required String vaultId,
  required String blobId,
  required List<int> bytes,
}) async {
  final raw = await callFolioHttpsCallable(
    'folioCheckCloudPackBlobsExist',
    <String, dynamic>{
      'vaultId': vaultId,
      'blobIds': <String>[blobId],
    },
  );
  var missing = <String>[blobId];
  if (raw is Map) {
    final m = raw['missing'];
    if (m is List) {
      missing = m.map((e) => e.toString()).toList();
    }
  }
  if (missing.isEmpty) return;
  final ref = FirebaseStorage.instance.ref().child(
    'users/$uid/vaults/$vaultId/cloud-packs/blobs/$blobId',
  );
  await ref.putData(Uint8List.fromList(bytes));
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
    final data = await ref.getData(max);
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
