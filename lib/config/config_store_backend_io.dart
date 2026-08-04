import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/storage/atomic_file_writer.dart';
import 'config_paths.dart';

/// Implementación nativa (dart:io) de almacenamiento de [ConfigStore]:
/// `Folio/config/<categoría>/<id>.json` bajo el directorio sandbox de la
/// app, mismo patrón que `vault_storage_io.dart`.
class ConfigStoreBackend {
  ConfigStoreBackend._();
  static final ConfigStoreBackend instance = ConfigStoreBackend._();

  /// Override para tests: si no es null, se usa en vez de
  /// `getApplicationSupportDirectory()`. No usar en código de producción.
  @visibleForTesting
  static Directory? debugRootOverride;

  Future<Directory> _root() async {
    if (debugRootOverride != null) return debugRootOverride!;
    return getApplicationSupportDirectory();
  }

  Future<Directory> _categoryDir(ConfigCategory category) async {
    final root = await _root();
    final dir = Directory(
      p.join(root.path, kFolioConfigContainer, category.folderName),
    );
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> read(ConfigCategory category, String id) async {
    final dir = await _categoryDir(category);
    final f = File(p.join(dir.path, '$id.json'));
    if (!f.existsSync()) return null;
    return f.readAsString();
  }

  Future<void> write(ConfigCategory category, String id, String json) async {
    final dir = await _categoryDir(category);
    final f = File(p.join(dir.path, '$id.json'));
    await AtomicFileWriter.writeAtomic(
      f,
      Uint8List.fromList(utf8.encode(json)),
    );
  }

  Future<List<String>> listIds(ConfigCategory category) async {
    final dir = await _categoryDir(category);
    final ids = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (!base.endsWith('.json')) continue;
      ids.add(base.substring(0, base.length - '.json'.length));
    }
    return ids;
  }

  Future<void> delete(ConfigCategory category, String id) async {
    final dir = await _categoryDir(category);
    final f = File(p.join(dir.path, '$id.json'));
    if (f.existsSync()) await f.delete();
    final bak = File(AtomicFileWriter.backupPathFor(f.path));
    if (bak.existsSync()) await bak.delete();
  }
}
