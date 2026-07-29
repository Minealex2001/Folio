import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_settings.dart';
import '../config/folio_backend_config.dart';
import 'app_logger.dart';
import 'folio_cloud/folio_cloud_callable.dart';
import 'folio_telemetry.dart';

/// Informes de diagnóstico hacia `POST /api/v1/diagnostics/report` (Spring).
/// Activado por defecto (`AppSettings.autoCrashReports`); cubre tanto crashes
/// no capturados como cualquier `AppLogger.error(...)` (ver `setOnError` en
/// app_logger.dart) — no solo lo que tumba la app.
class FolioDiagnosticReporter {
  FolioDiagnosticReporter._();

  static AppSettings? _appSettings;
  /// Firmas ya reportadas en esta sesión de app — evita mandar el mismo
  /// error repetido (p. ej. un bucle de reintento cada pocos segundos) más
  /// de una vez. La deduplicación de verdad entre sesiones/dispositivos vive
  /// en el servidor (`folioReportDiagnostic` comenta el issue existente en
  /// vez de crear uno nuevo).
  static final Set<String> _reportedSignaturesThisSession = {};
  static var _telemetryCrashLogged = false;
  static const _maxAutoReportsPerSession = 25;

  static void bindAppSettings(AppSettings? settings) {
    _appSettings = settings;
  }

  /// Firma estable de un error para deduplicar: no es exacta (dos errores
  /// del mismo tipo con mensajes ligeramente distintos comparten firma a
  /// propósito), pero basta para no repetir el mismo bug una y otra vez.
  static String signatureFor({
    required String tag,
    required String message,
    Object? error,
  }) {
    final errorType = error?.runtimeType.toString() ?? '';
    final normalizedMessage =
        message.length > 60 ? message.substring(0, 60) : message;
    final raw = '$tag|$errorType|$normalizedMessage';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static Uri? _reportUri() {
    return Uri.parse('${FolioBackendConfig.apiV1Prefix}/diagnostics/report');
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

  /// Enganchado a `AppLogger.setOnError` — se llama para CUALQUIER
  /// `AppLogger.error(...)`, no solo crashes que tumban la app.
  static Future<void> maybeReportLoggedError(
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context,
  ) async {
    final settings = _appSettings;
    if (settings == null || !settings.autoCrashReports) return;
    final signature = signatureFor(tag: tag, message: message, error: error);
    if (_reportedSignaturesThisSession.contains(signature)) return;
    if (_reportedSignaturesThisSession.length >= _maxAutoReportsPerSession) {
      return;
    }
    _reportedSignaturesThisSession.add(signature);
    if (settings.telemetryEnabled && !_telemetryCrashLogged) {
      _telemetryCrashLogged = true;
      unawaited(
        FolioTelemetry.logError(
          settings,
          error ?? StateError(message),
          'auto_error_report',
          stackTrace: stackTrace,
        ),
      );
    }
    await submit(
      kind: tag == 'crash' ? 'crash' : 'error',
      userNote: '',
      settings: settings,
      error: error,
      stackTrace: stackTrace,
      signature: signature,
      loggedTag: tag,
      loggedMessage: message,
      loggedContext: context,
    );
  }

  static Future<bool> submit({
    required String kind,
    required String userNote,
    required AppSettings settings,
    Object? error,
    StackTrace? stackTrace,
    String? signature,
    String? loggedTag,
    String? loggedMessage,
    Map<String, Object?>? loggedContext,
  }) async {
    final uri = _reportUri();
    if (uri == null) {
      AppLogger.warn(
        'Diagnostic report skipped (backend not available)',
        tag: 'diagnostics',
        context: {'backend': FolioBackendConfig.modeLabel},
      );
      return false;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final installId = await FolioTelemetry.anonymousInstallId();
      final buf = StringBuffer();
      if (loggedMessage != null && loggedMessage.isNotEmpty) {
        buf.writeln('[${loggedTag ?? 'app'}] $loggedMessage');
        if (loggedContext != null && loggedContext.isNotEmpty) {
          buf.writeln('context: ${jsonEncode(loggedContext)}');
        }
      }
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
        'appVersion': info.version,
        'platform': defaultTargetPlatform.name,
        'channel': AppSettings.distributionChannelFromEnvironment.trim(),
        'telemetryEnabled': settings.telemetryEnabled,
        if (signature != null && signature.isNotEmpty) 'signature': signature,
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
