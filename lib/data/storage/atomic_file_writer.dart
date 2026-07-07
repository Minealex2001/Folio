import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

/// Escritura atómica en disco: tmp → flush → rotar .bak → rename.
class AtomicFileWriter {
  AtomicFileWriter._();

  static const _uuid = Uuid();

  static String backupPathFor(String filePath) => '$filePath.bak';

  static Future<void> writeAtomic(File target, Uint8List data) async {
    final parent = target.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    final tmp = File('${target.path}.tmp.${_uuid.v4()}');
    try {
      await tmp.writeAsBytes(data, flush: true);
      if (target.existsSync()) {
        final bak = File(backupPathFor(target.path));
        if (bak.existsSync()) {
          await bak.delete();
        }
        await target.copy(bak.path);
        await target.delete();
      }
      await tmp.rename(target.path);
    } catch (e) {
      if (tmp.existsSync()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Restaura [target] desde su copia `.bak` si existe.
  static Future<bool> restoreFromBackup(File target) async {
    final bak = File(backupPathFor(target.path));
    if (!bak.existsSync()) return false;
    if (target.existsSync()) {
      await target.delete();
    }
    await bak.copy(target.path);
    return true;
  }
}
