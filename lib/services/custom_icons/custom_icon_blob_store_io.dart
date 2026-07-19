import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Native filesystem store for imported custom icon bytes.
class CustomIconBlobStore {
  CustomIconBlobStore._();
  static final CustomIconBlobStore instance = CustomIconBlobStore._();

  static const _dirName = 'custom_icons';

  Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _dirName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Writes [bytes] for [id] with [extension] (e.g. `.png`).
  /// Returns the absolute filesystem path used as [CustomIconEntry.filePath].
  Future<String> write({
    required String id,
    required String extension,
    required List<int> bytes,
  }) async {
    final dir = await _dir();
    final path = p.join(dir.path, '$id$extension');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<Uint8List?> read(String storageKey) async {
    final key = storageKey.trim();
    if (key.isEmpty) return null;
    final file = File(key);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<void> delete(String storageKey) async {
    final key = storageKey.trim();
    if (key.isEmpty) return;
    final file = File(key);
    if (!file.existsSync()) return;
    await file.delete();
  }
}
