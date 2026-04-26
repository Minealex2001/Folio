import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_settings.dart';
import '../firebase_options.dart';
import 'app_logger.dart';
import 'folio_cloud/folio_cloud_callable.dart';
import 'folio_telemetry.dart';

/// Informes de diagnóstico (opt-in) hacia [folioReportDiagnostic] en Cloud Functions.
class FolioDiagnosticReporter {
  FolioDiagnosticReporter._();

  static AppSettings? _appSettings;
  static var _autoReportsThisSession = 0;
  static var _telemetryCrashLogged = false;
  static const _maxAutoReportsPerSession = 3;

  static void bindAppSettings(AppSettings? settings) {
    _appSettings = settings;
  }

  static Uri? _reportUri() {
    if (Firebase.apps.isEmpty) return null;
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return Uri.parse(
      'https://$kFolioCloudFunctionsRegion-$projectId.cloudfunctions.net/folioReportDiagnostic',
    );
  }

  static Future<String> _readLogTail({int maxBytes = 16000}) async {
    try {
      final base = await getApplicationSupportDirectory();
      final file = File(
        '${base.path}${Platform.pathSeparator}logs${Platform.pathSeparator}folio.log',
      );
      if (!await file.exists()) return '';
      final len = await file.length();
      if (len <= maxBytes) {
        return (await file.readAsString()).trim();
      }
      final raf = await file.open();
      try {
        await raf.setPosition(len - maxBytes);
        final bytes = await raf.read(maxBytes);
        return utf8.decode(bytes, allowMalformed: true).trim();
      } finally {
        await raf.close();
      }
    } catch (_) {
      return '';
    }
  }

  static Future<void> maybeReportCrash(
    Object error,
    StackTrace stackTrace,
  ) async {
    final settings = _appSettings;
    if (settings == null || !settings.autoCrashReports) return;
    if (_autoReportsThisSession >= _maxAutoReportsPerSession) return;
    _autoReportsThisSession++;
    if (settings.telemetryEnabled &&
        !_telemetryCrashLogged &&
        _autoReportsThisSession == 1) {
      _telemetryCrashLogged = true;
      unawaited(
        FolioTelemetry.logError(
          settings,
          error,
          'auto_crash_report',
          stackTrace: stackTrace,
        ),
      );
    }
    await submit(
      kind: 'crash',
      userNote: '',
      settings: settings,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<bool> submit({
    required String kind,
    required String userNote,
    required AppSettings settings,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final uri = _reportUri();
    if (uri == null) {
      AppLogger.warn(
        'Diagnostic report skipped (Firebase not initialized)',
        tag: 'diagnostics',
      );
      return false;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final installId = await FolioTelemetry.anonymousInstallId();
      final buf = StringBuffer();
      if (error != null) buf.writeln(error.toString());
      if (stackTrace != null) buf.writeln(stackTrace.toString());
      final logTail = await _readLogTail();
      final excerpt = [
        if (buf.isNotEmpty) buf.toString(),
        if (logTail.isNotEmpty) '--- log tail ---\n$logTail',
      ].join('\n').trim();
      final body = jsonEncode({
        'installId': installId,
        'kind': kind.trim().isEmpty ? 'manual' : kind.trim(),
        'appVersion': '${info.version}+${info.buildNumber}',
        'platform': defaultTargetPlatform.name,
        'channel': AppSettings.distributionChannelFromEnvironment.trim(),
        'telemetryEnabled': settings.telemetryEnabled,
        'userNote': userNote.trim().length > 2000
            ? userNote.trim().substring(0, 2000)
            : userNote.trim(),
        'logExcerpt': excerpt.length > 12000
            ? excerpt.substring(excerpt.length - 12000)
            : excerpt,
      });
      final resp = await http
          .post(
            uri,
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: body,
          )
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        AppLogger.warn(
          'Diagnostic report failed',
          tag: 'diagnostics',
          context: {'status': resp.statusCode, 'body': resp.body},
        );
        return false;
      }
      AppLogger.info('Diagnostic report sent', tag: 'diagnostics');
      return true;
    } catch (e, st) {
      AppLogger.warn(
        'Diagnostic report error',
        tag: 'diagnostics',
        context: {'error': '$e'},
      );
      AppLogger.debug('Diagnostic stack', tag: 'diagnostics', context: {'stack': '$st'});
      return false;
    }
  }
}
