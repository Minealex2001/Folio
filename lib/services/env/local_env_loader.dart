import 'dart:io';

import '../app_logger.dart';
import 'local_env.dart';

class LocalEnvLoadResult {
  const LocalEnvLoadResult({
    required this.loaded,
    this.path,
    this.error,
  });

  final bool loaded;
  final String? path;
  final Object? error;
}

class LocalEnvLoader {
  const LocalEnvLoader._();

  static Future<LocalEnvLoadResult> loadLocalEnv({
    String filename = '.env',
    int maxSearchDepth = 30,
  }) async {
    // ignore: avoid_print
    print('[folio.env] probe start cwd=${Directory.current.path} script=${Platform.script}');
    AppLogger.info(
      'dotenv probe start',
      tag: 'env',
      context: {
        'cwd': Directory.current.path,
        'script': Platform.script.toString(),
      },
    );

    // 1) Try cwd.
    final cwd = Directory.current.path;
    final fromCwd = File(_join(cwd, filename));
    if (await fromCwd.exists()) {
      try {
        final raw = await fromCwd.readAsString();
        LocalEnv.setAll(parseDotEnv(raw));
        // ignore: avoid_print
        print('[folio.env] loaded from cwd path=${fromCwd.path}');
        return LocalEnvLoadResult(loaded: true, path: fromCwd.path);
      } catch (e) {
        // ignore: avoid_print
        print('[folio.env] load error from cwd path=${fromCwd.path} error=$e');
        return LocalEnvLoadResult(loaded: false, path: fromCwd.path, error: e);
      }
    }

    // 2) Try from script/executable directory (common in Windows runner).
    String? scriptDir;
    try {
      scriptDir = File(Platform.script.toFilePath()).parent.path;
      final fromScript = File(_join(scriptDir, filename));
      if (await fromScript.exists()) {
        try {
          final raw = await fromScript.readAsString();
          LocalEnv.setAll(parseDotEnv(raw));
          // ignore: avoid_print
          print('[folio.env] loaded from scriptDir path=${fromScript.path}');
          return LocalEnvLoadResult(loaded: true, path: fromScript.path);
        } catch (e) {
          // ignore: avoid_print
          print('[folio.env] load error from scriptDir path=${fromScript.path} error=$e');
          return LocalEnvLoadResult(loaded: false, path: fromScript.path, error: e);
        }
      }
    } catch (e) {
      // ignore, we'll keep searching.
      AppLogger.debug(
        'dotenv scriptDir probe failed',
        tag: 'env',
        context: {'error': '$e'},
      );
    }

    // 2.5) Try well-known per-user locations (most reliable for desktop dev).
    final userCandidates = <String>[];
    final appData = (Platform.environment['APPDATA'] ?? '').trim();
    final localAppData = (Platform.environment['LOCALAPPDATA'] ?? '').trim();
    final userProfile = (Platform.environment['USERPROFILE'] ?? '').trim();
    if (appData.isNotEmpty) userCandidates.add(_join(_join(appData, 'Folio'), filename));
    if (localAppData.isNotEmpty) {
      userCandidates.add(_join(_join(localAppData, 'Folio'), filename));
    }
    if (userProfile.isNotEmpty) {
      userCandidates.add(_join(_join(userProfile, '.folio'), filename));
    }
    AppLogger.info(
      'dotenv user candidates',
      tag: 'env',
      context: {'count': userCandidates.length},
    );
    for (final p in userCandidates) {
      final f = File(p);
      if (await f.exists()) {
        try {
          final raw = await f.readAsString();
          LocalEnv.setAll(parseDotEnv(raw));
          // ignore: avoid_print
          print('[folio.env] loaded from user candidate path=${f.path}');
          return LocalEnvLoadResult(loaded: true, path: f.path);
        } catch (e) {
          // ignore: avoid_print
          print('[folio.env] load error from user candidate path=${f.path} error=$e');
          return LocalEnvLoadResult(loaded: false, path: f.path, error: e);
        }
      }
    }

    // 3) Walk up from cwd / scriptDir looking for pubspec.yaml, then load .env beside it.
    final roots = <String>{
      Directory.current.path,
      ?scriptDir,
    };
    for (final root in roots) {
      var dir = Directory(root);
      for (var i = 0; i < maxSearchDepth; i++) {
        final pubspec = File(_join(dir.path, 'pubspec.yaml'));
        if (await pubspec.exists()) {
          final candidate = File(_join(dir.path, filename));
          if (await candidate.exists()) {
            try {
              final raw = await candidate.readAsString();
              LocalEnv.setAll(parseDotEnv(raw));
              // ignore: avoid_print
              print('[folio.env] loaded from pubspec root path=${candidate.path}');
              return LocalEnvLoadResult(loaded: true, path: candidate.path);
            } catch (e) {
              // ignore: avoid_print
              print('[folio.env] load error from pubspec root path=${candidate.path} error=$e');
              return LocalEnvLoadResult(loaded: false, path: candidate.path, error: e);
            }
          }
          return const LocalEnvLoadResult(loaded: false);
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }

    // ignore: avoid_print
    print('[folio.env] not found');
    return const LocalEnvLoadResult(loaded: false);
  }

  static String _join(String a, String b) {
    if (a.endsWith(Platform.pathSeparator)) return '$a$b';
    return '$a${Platform.pathSeparator}$b';
  }
}

