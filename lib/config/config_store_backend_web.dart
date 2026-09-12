import 'dart:async';

import 'package:idb_shim/idb_browser.dart';

import 'config_paths.dart';

/// Implementación web (IndexedDB vía idb_shim) de almacenamiento de
/// [ConfigStore]: un object store por categoría, mismo patrón que
/// `vault_storage_web.dart`.
class ConfigStoreBackend {
  ConfigStoreBackend._();
  static final ConfigStoreBackend instance = ConfigStoreBackend._();

  static const _dbName = 'folio_config_store';
  // v2: añade 'tokens'/'variables' (Fase 12). v3: añade 'accessibility'
  // (Fase 22). v4: añade 'workspace' (Fase 28) — subir la versión es
  // necesario para que onUpgradeNeeded se dispare de nuevo en
  // instalaciones que ya abrieron la base en una versión anterior.
  static const _dbVersion = 4;

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final factory = idbFactoryBrowser;
    _db = await factory.open(
      _dbName,
      version: _dbVersion,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.database;
        for (final category in ConfigCategory.values) {
          if (!db.objectStoreNames.contains(category.folderName)) {
            db.createObjectStore(category.folderName);
          }
        }
      },
    );
    return _db!;
  }

  Future<T> _tx<T>(
    ConfigCategory category,
    String mode,
    Future<T> Function(ObjectStore store) fn,
  ) async {
    final db = await _open();
    final txn = db.transaction(category.folderName, mode);
    final store = txn.objectStore(category.folderName);
    final result = await fn(store);
    await txn.completed;
    return result;
  }

  Future<String?> read(ConfigCategory category, String id) async {
    final raw = await _tx<Object?>(
      category,
      idbModeReadOnly,
      (store) async => store.getObject(id),
    );
    return raw as String?;
  }

  Future<void> write(ConfigCategory category, String id, String json) async {
    await _tx<void>(
      category,
      idbModeReadWrite,
      (store) async => store.put(json, id),
    );
  }

  Future<List<String>> listIds(ConfigCategory category) async {
    final db = await _open();
    final txn = db.transaction(category.folderName, idbModeReadOnly);
    final store = txn.objectStore(category.folderName);
    final ids = <String>[];
    final cursor = store.openCursor(autoAdvance: false);
    await for (final c in cursor) {
      final key = c.key;
      if (key is String) ids.add(key);
      c.next();
    }
    await txn.completed;
    return ids;
  }

  Future<void> delete(ConfigCategory category, String id) async {
    await _tx<void>(
      category,
      idbModeReadWrite,
      (store) async => store.delete(id),
    );
  }
}
