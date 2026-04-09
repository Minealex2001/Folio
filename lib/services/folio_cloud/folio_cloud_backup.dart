import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart' as p;

import 'folio_cloud_callable.dart';

import '../../data/vault_backup.dart';
import '../../session/vault_session.dart';
import 'folio_cloud_entitlements.dart';

/// En Windows/Linux el SDK C++ de Storage no implementa list/listAll y devuelve siempre vacío
/// (flutterfire#11915). En esas plataformas listamos vía Cloud Function + Admin SDK.
bool get _folioStorageClientListBrokenDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

void _requireCloudBackupEntitlement(FolioCloudSnapshot? snapshot) {
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
  final name = 'vault-$stamp.zip';
  final ref = FirebaseStorage.instance.ref().child(
    'users/${user.uid}/vaults/$vaultId/backups/$name',
  );
  await ref.putFile(file);
  return await ref.getDownloadURL();
}

/// Crea un ZIP temporal de la libreta **abierta**, lo sube a Storage y elimina el temporal.
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
  await session.persistNow();
  final tmp = Directory.systemTemp.createTempSync('folio_cloud_up_');
  final zipFile = File(p.join(tmp.path, 'vault.zip'));
  try {
    await exportVaultZip(zipFile);
    return await uploadEncryptedBackupFile(
      zipFile,
      vaultId: vaultId,
      entitlementSnapshot: entitlementSnapshot,
    );
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
  });

  final String fileName;
  final String storagePath;
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
  final raw = await callFolioHttpsCallable('folioListVaultBackups', <String, dynamic>{
    'vaultId': vaultId,
  });
  if (raw is! Map) {
    throw StateError('Respuesta inválida al listar copias en la nube.');
  }
  final items = raw['items'];
  if (items is! List) return const [];
  final out = <FolioCloudBackupEntry>[];
  for (final e in items) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final fn = m['fileName']?.toString() ?? '';
    final sp = m['storagePath']?.toString() ?? '';
    if (fn.isEmpty || sp.isEmpty) continue;
    out.add(FolioCloudBackupEntry(fileName: fn, storagePath: sp));
  }
  out.sort((a, b) => b.fileName.compareTo(a.fileName));
  return out;
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
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');
  if (_folioStorageClientListBrokenDesktop) {
    return _listFolioCloudBackupsViaCallable(vaultId: vaultId);
  }
  final ref = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/vaults/$vaultId/backups',
      );
  final list = await ref.listAll();
  final out = list.items
      .map(
        (r) => FolioCloudBackupEntry(
          fileName: r.name,
          storagePath: r.fullPath,
        ),
      )
      .toList();
  out.sort((a, b) => b.fileName.compareTo(a.fileName));
  return out;
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
  await ref.writeToFile(destinationFile);
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
