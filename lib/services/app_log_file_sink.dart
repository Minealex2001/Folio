import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

class AppLogFileSink implements AppLogSink {
  AppLogFileSink._(this._file);

  factory AppLogFileSink.forFile(File file) => AppLogFileSink._(file);

  static const _maxBytes = 1024 * 1024; // 1 MiB
  static const _maxRotations = 3;

  final File _file;
  Future<void> _queue = Future<void>.value();

  static Future<AppLogFileSink> init() async {
    final base = await getApplicationSupportDirectory();
    final logsDir = Directory('${base.path}${Platform.pathSeparator}logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    final file = File('${logsDir.path}${Platform.pathSeparator}folio.log');
    return AppLogFileSink._(file);
  }

  @override
  Future<void> write(String line) {
    _queue = _queue.then((_) async {
      try {
        await _rotateIfNeeded();
        await _file.writeAsString(
          '$line\n',
          mode: FileMode.append,
          flush: false,
        );
      } catch (_) {
        // Si el sink falla, no debería crashear la app.
      }
    });
    return _queue;
  }

  Future<void> _rotateIfNeeded() async {
    try {
      if (await _file.exists()) {
        final len = await _file.length();
        if (len < _maxBytes) return;
      }
    } catch (_) {
      return;
    }

    // folio.log -> folio.1.log -> folio.2.log -> folio.3.log
    for (var i = _maxRotations; i >= 1; i--) {
      final src = File(_rotatedPath(i == 1 ? '' : '.${i - 1}'));
      final dst = File(_rotatedPath('.$i'));
      try {
        if (await src.exists()) {
          if (await dst.exists()) {
            await dst.delete();
          }
          await src.rename(dst.path);
        }
      } catch (_) {
        // best-effort
      }
    }
  }

  String _rotatedPath(String suffix) {
    final dir = _file.parent.path;
    final sep = Platform.pathSeparator;
    return '$dir${sep}folio$suffix.log';
  }
}
