import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

/// Web (IndexedDB) store for imported custom icon bytes.
///
/// Storage keys are logical paths `custom_icons/{id}{ext}` and are stored as
/// [CustomIconEntry.filePath] so cloud sync / prefs stay platform-agnostic.
class CustomIconBlobStore {
  CustomIconBlobStore._();
  static final CustomIconBlobStore instance = CustomIconBlobStore._();

  static const _dbName = 'folio_custom_icons';
  static const _storeName = 'icons';
  static const _keyPrefix = 'custom_icons/';

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

  String _logicalKey(String id, String extension) =>
      '$_keyPrefix$id$extension';

  /// Writes [bytes] for [id] with [extension] (e.g. `.png`).
  /// Returns the logical key used as [CustomIconEntry.filePath].
  Future<String> write({
    required String id,
    required String extension,
    required List<int> bytes,
  }) async {
    final key = _logicalKey(id, extension);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await _tx<void>(idbModeReadWrite, (store) async {
      await store.put(data, key);
    });
    return key;
  }

  Future<Uint8List?> read(String storageKey) async {
    final key = storageKey.trim();
    if (key.isEmpty) return null;
    final raw = await _tx<Object?>(
      idbModeReadOnly,
      (store) async => store.getObject(key),
    );
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  Future<void> delete(String storageKey) async {
    final key = storageKey.trim();
    if (key.isEmpty) return;
    await _tx<void>(idbModeReadWrite, (store) async {
      await store.delete(key);
    });
  }
}
