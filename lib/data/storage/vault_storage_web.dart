import 'dart:async';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:uuid/uuid.dart';

/// Web (IndexedDB) implementation of VaultStorage.
///
/// Data layout:
///   Database name : 'folio_vault_store' (version 1)
///   Object store  : 'vault_files'
///   Key pattern   : '<vaultId>/<filename>'
///                   e.g. 'abc123/vault.bin'
///                        'abc123/attachments/img.png'
class VaultStorage {
  VaultStorage._();
  static final VaultStorage instance = VaultStorage._();

  static const _dbName = 'folio_vault_store';
  static const _storeName = 'vault_files';
  static const _attachmentsDir = 'attachments';
  static const _uuid = Uuid();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final factory = idbFactoryBrowser;
    _db = await factory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
    return _db!;
  }

  Future<T> _tx<T>(
    String mode,
    Future<T> Function(ObjectStore store) fn,
  ) async {
    final db = await _open();
    final txn = db.transaction(_storeName, mode);
    final store = txn.objectStore(_storeName);
    final result = await fn(store);
    await txn.completed;
    return result;
  }

  String _key(String vaultId, String filename) => '$vaultId/$filename';

  // ── Vault file operations ─────────────────────────────────────────────

  Future<Uint8List?> readVaultFile(String vaultId, String filename) async {
    final raw = await _tx<Object?>(
      idbModeReadOnly,
      (store) async => store.getObject(_key(vaultId, filename)),
    );
    if (raw == null) return null;
    return raw as Uint8List;
  }

  Future<void> writeVaultFile(
    String vaultId,
    String filename,
    Uint8List data,
  ) async {
    await _tx<void>(
      idbModeReadWrite,
      (store) async {
        await store.put(data, _key(vaultId, filename));
      },
    );
  }

  Future<bool> vaultFileExists(String vaultId, String filename) async {
    final raw = await _tx<Object?>(
      idbModeReadOnly,
      (store) async => store.getObject(_key(vaultId, filename)),
    );
    return raw != null;
  }

  Future<void> deleteVaultFile(String vaultId, String filename) async {
    await _tx<void>(
      idbModeReadWrite,
      (store) async {
        await store.delete(_key(vaultId, filename));
      },
    );
  }

  Future<int> vaultFileSize(String vaultId, String filename) async {
    final bytes = await readVaultFile(vaultId, filename);
    return bytes?.length ?? 0;
  }

  // ── Vault lifecycle ────────────────────────────────────────────────────

  Future<bool> vaultExists(String vaultId) async {
    final hasKeys = await vaultFileExists(vaultId, 'vault.keys');
    if (hasKeys) return true;
    return vaultFileExists(vaultId, 'vault.bin');
  }

  /// No-op on web: the IndexedDB store is always ready.
  Future<void> initVault(String vaultId) async {}

  Future<void> deleteVault(String vaultId) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    // Enumerate and delete all keys starting with vaultId/
    final prefix = '$vaultId/';
    final request = store.openCursor(autoAdvance: false);
    final keysToDelete = <Object>[];
    await for (final cursor in request) {
      final key = cursor.key as String?;
      if (key != null && key.startsWith(prefix)) {
        keysToDelete.add(cursor.key!);
      }
      cursor.next();
    }
    for (final k in keysToDelete) {
      await store.delete(k);
    }
    await txn.completed;
  }

  Future<int> vaultTotalBytes(String vaultId) async {
    final paths = await _listKeysWithPrefix('$vaultId/');
    var total = 0;
    for (final k in paths) {
      final part = k.substring('$vaultId/'.length);
      final bytes = await readVaultFile(vaultId, part);
      total += bytes?.length ?? 0;
    }
    return total;
  }

  // ── Attachment operations ─────────────────────────────────────────────

  Future<String> importAttachmentBytes(
    String vaultId,
    Uint8List bytes,
    String ext, {
    String? preferredName,
  }) async {
    final safeExt = _safeAttachmentExt(ext);
    String name;
    if (preferredName != null) {
      name = await _resolvePreferredName(vaultId, preferredName, safeExt);
    } else {
      name = '${_uuid.v4()}$safeExt';
    }
    final relative = '$_attachmentsDir/$name';
    await writeVaultFile(vaultId, relative, bytes);
    return relative;
  }

  Future<Uint8List?> readAttachment(
    String vaultId,
    String relativePath,
  ) async {
    if (!relativePath.startsWith('$_attachmentsDir/')) return null;
    return readVaultFile(vaultId, relativePath);
  }

  Future<void> deleteAttachment(String vaultId, String relativePath) async {
    if (!relativePath.startsWith('$_attachmentsDir/')) return;
    await deleteVaultFile(vaultId, relativePath);
  }

  Future<void> clearAttachments(String vaultId) async {
    final prefix = '$vaultId/$_attachmentsDir/';
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    final cursor = store.openCursor(autoAdvance: false);
    final keysToDelete = <Object>[];
    await for (final c in cursor) {
      final key = c.key as String?;
      if (key != null && key.startsWith(prefix)) {
        keysToDelete.add(c.key!);
      }
      c.next();
    }
    for (final k in keysToDelete) {
      await store.delete(k);
    }
    await txn.completed;
  }

  Future<List<String>> listAttachmentPaths(String vaultId) async {
    final prefix = '$vaultId/$_attachmentsDir/';
    final keys = await _listKeysWithPrefix(prefix);
    return keys
        .map((k) => k.substring('$vaultId/'.length))
        .where((rel) => rel.startsWith('$_attachmentsDir/'))
        .toList();
  }

  /// Always returns null on web – no native filesystem.
  Future<Object?> getNativeVaultDirectory(String vaultId) async => null;

  /// Not supported on web. Throws [UnsupportedError].
  /// Use [importAttachmentBytes] instead.
  Future<String> importAttachmentFromFile(
    String vaultId,
    dynamic source, {
    bool preserveExtension = false,
    bool preserveFileName = false,
  }) {
    throw UnsupportedError(
      'importAttachmentFromFile is not supported on web. Use importAttachmentBytes.',
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────

  Future<List<String>> _listKeysWithPrefix(String prefix) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final keys = <String>[];
    final cursor = store.openCursor(autoAdvance: false);
    await for (final c in cursor) {
      final key = c.key as String?;
      if (key != null && key.startsWith(prefix)) keys.add(key);
      c.next();
    }
    await txn.completed;
    return keys;
  }

  Future<String> _resolvePreferredName(
    String vaultId,
    String baseName,
    String ext,
  ) async {
    final clean = _sanitizeBase(baseName);
    final direct = '$clean$ext';
    if (!await vaultFileExists(vaultId, '$_attachmentsDir/$direct')) {
      return direct;
    }
    final suffix = _uuid.v4().split('-').first;
    return '${clean}_$suffix$ext';
  }

  static String _sanitizeBase(String base) {
    final cleaned = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'archivo';
    return cleaned.length <= 64 ? cleaned : cleaned.substring(0, 64).trim();
  }

  static String _safeAttachmentExt(String ext) {
    if (ext.isEmpty) return '.bin';
    final clean = ext.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '');
    if (clean.length < 2 || clean.length > 12 || !clean.startsWith('.')) {
      return '.bin';
    }
    return clean;
  }
}
