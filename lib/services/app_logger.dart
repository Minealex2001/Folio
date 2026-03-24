import 'dart:convert';
import 'dart:developer' as developer;

enum AppLogLevel { debug, info, warn, error }

class AppLogger {
  const AppLogger._();

  static void debug(
    String message, {
    String tag = 'app',
    Map<String, Object?> context = const {},
  }) {
    _write(level: AppLogLevel.debug, message: message, tag: tag, context: context);
  }

  static void info(
    String message, {
    String tag = 'app',
    Map<String, Object?> context = const {},
  }) {
    _write(level: AppLogLevel.info, message: message, tag: tag, context: context);
  }

  static void warn(
    String message, {
    String tag = 'app',
    Map<String, Object?> context = const {},
  }) {
    _write(level: AppLogLevel.warn, message: message, tag: tag, context: context);
  }

  static void error(
    String message, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _write(
      level: AppLogLevel.error,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void _write({
    required AppLogLevel level,
    required String message,
    required String tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    final ctx = context.isEmpty ? '' : ' | ctx=${jsonEncode(context)}';
    developer.log(
      '[${level.name.toUpperCase()}] $message$ctx',
      name: 'folio.$tag',
      level: _toDeveloperLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _toDeveloperLevel(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.debug:
        return 500;
      case AppLogLevel.info:
        return 800;
      case AppLogLevel.warn:
        return 900;
      case AppLogLevel.error:
        return 1000;
    }
  }
}
