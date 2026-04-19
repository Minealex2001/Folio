import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import 'folio_cloud_callable.dart';

import '../../data/vault_backup.dart';
import '../../session/vault_session.dart';
import 'folio_cloud_entitlements.dart';

// Nota: listamos copias siempre vía callable (incluye sizeBytes y soporta escritorio).

void _requireCloudBackupEntitlement(FolioCloudSnapshot? snapshot) {
  requireFolioCloudBackupEntitlement(snapshot);
}

/// Visible para otros servicios de copia (p. ej. cloud-pack).
void requireFolioCloudBackupEntitlement(FolioCloudSnapshot? snapshot) {
  if (snapshot != null && !snapshot.canUseCloudBackup) {
    throw StateError(
      'Tu plan Folio Cloud no incluye copia en la nube o la suscripción no está activa.',
    );
  }
}

/// Upload encrypted vault backup zip to `users/{uid}/backups/`.
/// Si [entitlementSnapshot] no es null, comprueba [FolioCloudSnapshot.canUseCloudBackup] antes de subir.
Future<String> uploadEncryptedBackupFile(
  File file, {
  required String vaultId,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  // Legado: permite subir un ZIP existente si ya lo tienes localmente.
  final name = 'vault-$stamp.zip';
  final ref = FirebaseStorage.instance.ref().child(
    'users/${user.uid}/vaults/$vaultId/backups/$name',
  );
  await ref.putFile(file);
  return await ref.getDownloadURL();
}

Future<Map<String, dynamic>?> _getLatestBackupMeta({
  required String vaultId,
}) async {
  final raw = await callFolioHttpsCallable(
    'folioGetLatestVaultBackupMeta',
    <String, dynamic>{'vaultId': vaultId},
  );
  if (raw is! Map) return null;
  final latest = raw['latest'];
  if (latest is! Map) return null;
  return Map<String, dynamic>.from(latest);
}

Future<void> _recordBackupMeta({
  required String vaultId,
  required String fileName,
  required String storagePath,
  required int sizeBytes,
  required String fingerprint,
  required int vaultBytes,
  required int attachmentsBytes,
  required String containerFormat,
}) async {
  await callFolioHttpsCallable('folioRecordVaultBackupMeta', <String, dynamic>{
    'vaultId': vaultId,
    'fileName': fileName,
    'storagePath': storagePath,
    'sizeBytes': sizeBytes,
    'fingerprint': fingerprint,
    'vaultBytes': vaultBytes,
    'attachmentsBytes': attachmentsBytes,
    'containerFormat': containerFormat,
  });
}

/// Crea un TAR.GZ temporal de la libreta **abierta**, lo sube a Storage y elimina el temporal.
/// No pide al usuario elegir archivos.
Future<String> uploadOpenVaultEncryptedToCloud({
  required VaultSession session,
  required String vaultId,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (!session.isUnlocked) {
    throw StateError(
      'La libreta debe estar desbloqueada para subir la copia a la nube.',
    );
  }
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (FirebaseAuth.instance.currentUser == null) {
    throw StateError('Not signed in');
  }
  final fp = await computeVaultCloudBackupFingerprint();
  final latest = await _getLatestBackupMeta(vaultId: vaultId);
  final latestFp = latest?['fingerprint']?.toString().trim() ?? '';
  if (latestFp.isNotEmpty && latestFp == fp.fingerprint) {
    // Copia idéntica (mejor no subir otra vez).
    final sp = latest?['storagePath']?.toString().trim() ?? '';
    if (sp.isNotEmpty) {
      try {
        return await FirebaseStorage.instance.ref(sp).getDownloadURL();
      } catch (_) {}
    }
    return '';
  }

  await session.persistNow();
  final tmp = Directory.systemTemp.createTempSync('folio_cloud_up_');
  final tgzFile = File(p.join(tmp.path, 'vault.tar.gz'));
  try {
    await exportVaultTarGz(tgzFile);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final name = 'vault-$stamp.tar.gz';
    final ref = FirebaseStorage.instance.ref().child(
      'users/${user.uid}/vaults/$vaultId/backups/$name',
    );
    final snap = await ref.putFile(tgzFile);
    final sizeBytes = snap.totalBytes;
    try {
      await _recordBackupMeta(
        vaultId: vaultId,
        fileName: name,
        storagePath: ref.fullPath,
        sizeBytes: sizeBytes,
        fingerprint: fp.fingerprint,
        vaultBytes: fp.vaultBytes,
        attachmentsBytes: fp.attachmentsBytes,
        containerFormat: 'tar.gz',
      );
    } catch (_) {}
    return await ref.getDownloadURL();
  } finally {
    try {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}

/// Copia listada en `users/{uid}/backups/` (orden: nombre descendente).
class FolioCloudBackupEntry {
  const FolioCloudBackupEntry({
    required this.fileName,
    required this.storagePath,
    required this.sizeBytes,
    required this.createdAt,
    this.isCloudPack = false,
  });

  final String fileName;
  final String storagePath;
  final int sizeBytes;
  final String createdAt;

  /// Copia incremental (cloud-pack); restaurar con [downloadLatestCloudPackToDirectory].
  final bool isCloudPack;
}

class FolioCloudBackupVaultEntry {
  const FolioCloudBackupVaultEntry({
    required this.vaultId,
    required this.displayName,
  });

  final String vaultId;
  final String displayName;
}

Future<List<FolioCloudBackupVaultEntry>> listFolioCloudBackupVaults({
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (FirebaseAuth.instance.currentUser == null) {
    throw StateError('Not signed in');
  }
  final raw =
      await callFolioHttpsCallable('folioListBackupVaults', <String, dynamic>{});
  if (raw is! Map) return const [];
  final vaults = raw['vaults'];
  if (vaults is! List) return const [];
  final out = <FolioCloudBackupVaultEntry>[];
  for (final e in vaults) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final id = m['vaultId']?.toString().trim() ?? '';
    if (id.isEmpty) continue;
    final name = m['displayName']?.toString().trim() ?? '';
    out.add(FolioCloudBackupVaultEntry(vaultId: id, displayName: name));
  }
  out.sort(
    (a, b) => (a.displayName.isNotEmpty ? a.displayName : a.vaultId)
        .compareTo(b.displayName.isNotEmpty ? b.displayName : b.vaultId),
  );
  return out;
}

Future<List<FolioCloudBackupEntry>> _listFolioCloudBackupsViaCallable({
  required String vaultId,
}) async {
  final raw = await callFolioHttpsCallable(
    'folioListVaultBackups',
    <String, dynamic>{'vaultId': vaultId},
  );
  if (raw is! Map) {
    throw StateError('Respuesta inválida al listar copias en la nube.');
  }
  final legacy = <FolioCloudBackupEntry>[];
  FolioCloudBackupEntry? cloudPack;
  final cloud = raw['cloudPack'];
  if (cloud is Map) {
    final m = Map<String, dynamic>.from(cloud);
    final fn = m['fileName']?.toString() ?? '';
    final sp = m['storagePath']?.toString() ?? '';
    final szRaw = m['sizeBytes'];
    final sz = szRaw is int
        ? szRaw
        : szRaw is num
            ? szRaw.toInt()
            : int.tryParse('$szRaw') ?? 0;
    final createdAt = m['createdAt']?.toString() ?? '';
    if (fn.isNotEmpty && sp.isNotEmpty) {
      cloudPack = FolioCloudBackupEntry(
        fileName: fn,
        storagePath: sp,
        sizeBytes: sz < 0 ? 0 : sz,
        createdAt: createdAt,
        isCloudPack: true,
      );
    }
  }
  final items = raw['items'];
  if (items is! List) {
    if (cloudPack != null) return <FolioCloudBackupEntry>[cloudPack];
    return const [];
  }
  for (final e in items) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final fn = m['fileName']?.toString() ?? '';
    final sp = m['storagePath']?.toString() ?? '';
    final szRaw = m['sizeBytes'];
    final sz = szRaw is int
        ? szRaw
        : szRaw is num
            ? szRaw.toInt()
            : int.tryParse('$szRaw') ?? 0;
    final createdAt = m['createdAt']?.toString() ?? '';
    if (fn.isEmpty || sp.isEmpty) continue;
    legacy.add(
      FolioCloudBackupEntry(
        fileName: fn,
        storagePath: sp,
        sizeBytes: sz < 0 ? 0 : sz,
        createdAt: createdAt,
        isCloudPack: false,
      ),
    );
  }
  legacy.sort((a, b) => b.fileName.compareTo(a.fileName));
  if (cloudPack != null) {
    return <FolioCloudBackupEntry>[cloudPack, ...legacy];
  }
  return legacy;
}

/// Lista archivos en la carpeta de copias de Folio Cloud.
Future<List<FolioCloudBackupEntry>> listFolioCloudBackups({
  required String vaultId,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (FirebaseAuth.instance.currentUser == null) {
    throw StateError('Not signed in');
  }
  // Unificamos el listado vía callable para incluir sizeBytes y soportar escritorio.
  return _listFolioCloudBackupsViaCallable(vaultId: vaultId);
}

int _folioCloudBackupGetDataMaxBytes(FolioCloudBackupEntry entry) {
  const cap = 512 * 1024 * 1024;
  if (entry.sizeBytes <= 0) return cap;
  final padded = entry.sizeBytes + 65536;
  if (padded < entry.sizeBytes) return cap;
  return padded > cap ? cap : padded;
}

/// Descarga los bytes de una copia (ZIP/TAR.GZ) desde Storage.
///
/// En web se usa en lugar de [Reference.writeToFile], que no está soportado.
Future<Uint8List> downloadFolioCloudBackupBytes({
  required FolioCloudBackupEntry entry,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (FirebaseAuth.instance.currentUser == null) {
    throw StateError('Not signed in');
  }
  final ref = FirebaseStorage.instance.ref(entry.storagePath);
  final maxBytes = _folioCloudBackupGetDataMaxBytes(entry);
  final data = await ref.getData(maxBytes);
  if (data == null || data.isEmpty) {
    throw StateError('La descarga no devolvió datos.');
  }
  return data;
}

/// Descarga una copia de la nube a un archivo local.
Future<void> downloadFolioCloudBackup({
  required FolioCloudBackupEntry entry,
  required File destinationFile,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');
  final ref = FirebaseStorage.instance.ref(entry.storagePath);
  if (kIsWeb) {
    final data = await downloadFolioCloudBackupBytes(
      entry: entry,
      entitlementSnapshot: entitlementSnapshot,
    );
    await destinationFile.writeAsBytes(data, flush: true);
  } else {
    await ref.writeToFile(destinationFile);
  }
}

Future<void> deleteFolioCloudBackup({
  required FolioCloudBackupEntry entry,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');
  final ref = FirebaseStorage.instance.ref(entry.storagePath);
  await ref.delete();
}

Future<void> trimFolioCloudBackups({
  required String vaultId,
  int maxCount = 10,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (FirebaseAuth.instance.currentUser == null) {
    throw StateError('Not signed in');
  }
  await callFolioHttpsCallable('folioTrimVaultBackups', <String, dynamic>{
    'vaultId': vaultId,
    'maxCount': maxCount,
  });
}

Future<void> trimFolioCloudBackupsByBytes({
  required String vaultId,
  required int maxBytes,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (FirebaseAuth.instance.currentUser == null) {
    throw StateError('Not signed in');
  }
  await callFolioHttpsCallable('folioTrimVaultBackupsByBytes', <String, dynamic>{
    'vaultId': vaultId,
    'maxBytes': maxBytes,
  });
}

Future<void> upsertFolioCloudBackupVaultIndex({
  required String vaultId,
  required String displayName,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requireCloudBackupEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (FirebaseAuth.instance.currentUser == null) {
    throw StateError('Not signed in');
  }
  await callFolioHttpsCallable('folioUpsertVaultBackupIndex', <String, dynamic>{
    'vaultId': vaultId,
    'displayName': displayName,
  });
}
