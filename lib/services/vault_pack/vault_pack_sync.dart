import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../crypto/vault_crypto.dart';
import '../../data/folio_cloud_pack_format.dart';
import '../../data/vault_backup.dart';
import '../../data/vault_paths.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_pack_crypto.dart';
import '../vault_cloud_pack_progress.dart';
import 'vault_pack_builder.dart';
import 'vault_pack_meta.dart';
import 'vault_pack_paths.dart';
import 'vault_pack_transport.dart';

/// Resultado de una subida pack (local/WebDAV).
class VaultPackUploadResult {
  const VaultPackUploadResult({
    required this.skippedUpToDate,
    required this.contentFingerprint,
    this.headSnapshot = '',
  });

  final bool skippedUpToDate;
  final String contentFingerprint;
  final String headSnapshot;
}

/// Sube la libreta abierta como pack incremental al [transport].
///
/// Para libretas cifradas, el envoltorio de recuperación se toma de `vault.keys`
/// (ya envuelto con la contraseña de la libreta), sin pedir la contraseña de nuevo.
Future<VaultPackUploadResult> uploadOpenVaultPack({
  required VaultSession session,
  required VaultPackTransport transport,
  int retentionCount = 10,
  OnVaultCloudPackProgress? onProgress,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException(
      'La libreta debe estar desbloqueada para crear la copia.',
    );
  }

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
  final vaultBinBytes = await session.vaultBinEquivalentBytes();
  final contentFp = await computeVaultCloudPackContentFingerprint(
    vaultBinBytes: vaultBinBytes,
  );

  rep(VaultCloudPackProgressStep.fetchingMeta, 0.09);
  final latest = await transport.readMeta();
  final latestFp = latest?.contentFingerprint ?? '';
  if (latestFp.isNotEmpty && latestFp == contentFp) {
    rep(VaultCloudPackProgressStep.skippedUpToDate, 1.0);
    return VaultPackUploadResult(
      skippedUpToDate: true,
      contentFingerprint: contentFp,
      headSnapshot: latest?.headSnapshot ?? '',
    );
  }

  // No dejar que una libreta local vacía (p. ej. estado en memoria vaciado
  // transitoriamente) sobreescriba/rote un backup existente con contenido:
  // este destino solo se dedupe por fingerprint, no compara "riqueza", así
  // que una subida vacía terminaría expulsando la última copia buena tras
  // `retentionCount` ciclos de GC.
  if (session.pages.isEmpty && latest != null) {
    AppLogger.error(
      'Refusing to push an empty vault over an existing pack backup',
      tag: 'vault-pack',
      context: {'contentFingerprint': contentFp},
    );
    throw VaultBackupException(
      'La libreta local está vacía; se rechaza subir sobre una copia '
      'existente con contenido.',
    );
  }

  final packKey = await session.cloudPackEncryptionKey();
  rep(VaultCloudPackProgressStep.restoreWrap, 0.11);

  Uint8List? restoreWrapBytes;
  String? restoreWrapKind;
  if (session.vaultUsesEncryption) {
    final wrapped = await VaultPaths.wrappedDekPath();
    if (wrapped.existsSync()) {
      restoreWrapBytes = Uint8List.fromList(await wrapped.readAsBytes());
      restoreWrapKind = 'vaultDek';
    }
  } else {
    final rawPk = await packKey.extractBytes();
    restoreWrapBytes = await VaultCrypto.wrapDek(
      dek: Uint8List.fromList(rawPk),
      password: '',
    );
    restoreWrapKind = 'packKey';
  }

  final oldSnapPath = latest?.headSnapshot ?? '';
  rep(VaultCloudPackProgressStep.indexingLocal, 0.135);
  final built = await buildVaultPackSnapshot(
    packKey: packKey,
    contentFingerprint: contentFp,
    vaultBinBytes: vaultBinBytes,
  );
  final blobs = built.blobs;
  final snapClear = built.manifest;
  final totalBlobs = blobs.length;
  var blobsDone = 0;

  for (final b in blobs) {
    await transport.putBlob(
      b.item.blobId,
      Uint8List.fromList(b.cipherBytes),
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
  final snapRel = '$kVaultPackSnapshotsDirName/snap-$stamp.bin';
  rep(VaultCloudPackProgressStep.uploadingSnapshot, 0.76);
  await transport.putSnapshot(snapRel, snapCipher);

  if (restoreWrapBytes != null) {
    await transport.putRestoreWrap(restoreWrapBytes);
  }

  final keepN = retentionCount <= 0 ? 1 : retentionCount;
  final prevSnaps = List<VaultPackSnapshotRef>.from(latest?.snapshots ?? const []);
  // Asegurar que el head anterior esté en la lista.
  if (oldSnapPath.isNotEmpty &&
      !prevSnaps.any((s) => s.path == oldSnapPath)) {
    prevSnaps.add(
      VaultPackSnapshotRef(
        path: oldSnapPath,
        createdAtUtc: latest?.updatedAtUtc ?? snapClear.createdAtUtc,
        contentFingerprint: latest?.contentFingerprint ?? '',
        sizeBytes: latest?.snapshotSizeBytes ?? 0,
      ),
    );
  }
  prevSnaps.add(
    VaultPackSnapshotRef(
      path: snapRel,
      createdAtUtc: snapClear.createdAtUtc,
      contentFingerprint: contentFp,
      sizeBytes: snapCipher.length,
    ),
  );
  // Más recientes al final; conservar los últimos keepN.
  while (prevSnaps.length > keepN) {
    prevSnaps.removeAt(0);
  }

  final meta = VaultPackMeta(
    formatVersion: VaultPackMeta.currentFormatVersion,
    contentFingerprint: contentFp,
    headSnapshot: snapRel,
    updatedAtUtc: snapClear.createdAtUtc,
    snapshotSizeBytes: snapCipher.length,
    hasRestoreWrap: restoreWrapBytes != null,
    wrapKind: restoreWrapKind,
    snapshots: prevSnaps,
  );

  rep(VaultCloudPackProgressStep.finalizing, 0.82);
  await transport.writeMeta(meta);

  rep(VaultCloudPackProgressStep.cleaningOldBlobs, 0.88);
  await _gcPack(
    transport: transport,
    packKey: packKey,
    retainedSnapshots: prevSnaps,
  );

  rep(VaultCloudPackProgressStep.complete, 1.0);
  unawaited(session.cleanupV0AfterSuccessfulSync());
  return VaultPackUploadResult(
    skippedUpToDate: false,
    contentFingerprint: contentFp,
    headSnapshot: snapRel,
  );
}

Future<void> _gcPack({
  required VaultPackTransport transport,
  required SecretKey packKey,
  required List<VaultPackSnapshotRef> retainedSnapshots,
}) async {
  final keepPaths = {for (final s in retainedSnapshots) s.path};
  final allSnaps = await transport.listSnapshotPaths();
  for (final path in allSnaps) {
    if (!keepPaths.contains(path)) {
      try {
        await transport.deleteSnapshot(path);
      } catch (e) {
        AppLogger.warn(
          'No se pudo borrar snapshot pack obsoleto',
          tag: 'vault-pack',
          context: {'path': path, 'error': '$e'},
        );
      }
    }
  }

  final liveBlobIds = <String>{};
  for (final ref in retainedSnapshots) {
    final bytes = await transport.getSnapshot(ref.path);
    if (bytes == null || bytes.isEmpty) {
      // Snapshot retenido ilegible: no borrar blobs (evitar GC destructivo).
      return;
    }
    final man = await cloudPackDecryptSnapshotManifest(
      cipherBlob: bytes,
      packKey: packKey,
    );
    if (man == null) return;
    for (final item in man.items) {
      liveBlobIds.add(item.blobId);
    }
  }

  final existing = await transport.listBlobIds();
  for (final id in existing) {
    if (liveBlobIds.contains(id)) continue;
    try {
      await transport.deleteBlob(id);
    } catch (e) {
      AppLogger.warn(
        'No se pudo borrar blob pack obsoleto',
        tag: 'vault-pack',
        context: {'blobId': id, 'error': '$e'},
      );
    }
  }
}

/// Materializa el pack head en [extractDir] (estructura de copia ZIP).
Future<void> downloadVaultPackToDirectory({
  required VaultPackTransport transport,
  required SecretKey packKey,
  required Directory extractDir,
  String? snapshotRelativePath,
}) async {
  final meta = await transport.readMeta();
  final path = (snapshotRelativePath ?? meta?.headSnapshot)?.trim() ?? '';
  if (path.isEmpty) {
    throw VaultBackupException('No hay copia incremental en el destino.');
  }
  final snapBytes = await transport.getSnapshot(path);
  if (snapBytes == null || snapBytes.isEmpty) {
    throw VaultBackupException('No se pudo leer el snapshot del pack.');
  }
  final manifest = await cloudPackDecryptSnapshotManifest(
    cipherBlob: snapBytes,
    packKey: packKey,
  );
  if (manifest == null) {
    throw VaultBackupException(
      'No se pudo leer la copia incremental (clave o datos).',
    );
  }

  if (!extractDir.existsSync()) {
    await extractDir.create(recursive: true);
  }

  for (final item in manifest.items) {
    final data = await transport.getBlob(item.blobId);
    if (data == null || data.isEmpty) {
      throw VaultBackupException('Falta un blob en el pack: ${item.blobId}');
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

/// Restaura pack usando el envoltorio (`restore_wrap.bin`) + contraseña.
Future<void> downloadVaultPackToDirectoryForRestore({
  required VaultPackTransport transport,
  required String restorePassword,
  required Directory extractDir,
  String? snapshotRelativePath,
}) async {
  final meta = await transport.readMeta();
  final wrapBytes = await transport.getRestoreWrap();
  if (wrapBytes == null || wrapBytes.isEmpty) {
    throw VaultBackupException(
      'Falta el envoltorio de recuperación para esta copia incremental.',
    );
  }
  final kind = meta?.wrapKind?.trim() ?? '';
  final unwrapped = await VaultCrypto.unwrapDek(
    wrapped: wrapBytes,
    password: restorePassword,
  );
  final SecretKey packKey = kind == 'packKey'
      ? SecretKey(unwrapped)
      : await VaultCrypto.dekFromBytes(unwrapped);

  await downloadVaultPackToDirectory(
    transport: transport,
    packKey: packKey,
    extractDir: extractDir,
    snapshotRelativePath: snapshotRelativePath ?? meta?.headSnapshot,
  );
}

/// Materializa con la clave de la sesión abierta (misma libreta).
Future<void> downloadVaultPackToDirectoryWithSession({
  required VaultSession session,
  required VaultPackTransport transport,
  required Directory extractDir,
  String? snapshotRelativePath,
}) async {
  if (!session.isUnlocked) {
    throw VaultBackupException('La libreta debe estar desbloqueada.');
  }
  final packKey = await session.cloudPackEncryptionKey();
  await downloadVaultPackToDirectory(
    transport: transport,
    packKey: packKey,
    extractDir: extractDir,
    snapshotRelativePath: snapshotRelativePath,
  );
}

/// Nombre estable para listar un pack en UI junto a ZIPs.
String vaultPackListEntryName({required String vaultId}) =>
    '$kVaultPackListEntryPrefix:$vaultId';

bool isVaultPackListEntryName(String name) =>
    name.toLowerCase().startsWith('$kVaultPackListEntryPrefix:');

String? vaultIdFromPackListEntryName(String name) {
  final prefix = '$kVaultPackListEntryPrefix:';
  if (!name.startsWith(prefix)) return null;
  final id = name.substring(prefix.length).trim();
  return id.isEmpty ? null : id;
}
