import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_settings.dart';
import '../config/folio_backend_config.dart';
import 'app_logger.dart';
import 'folio_cloud/folio_cloud_identity.dart';
import 'folio_telemetry.dart';

/// Resultado de `POST /diagnostics/report`.
class DiagnosticSubmitResult {
  const DiagnosticSubmitResult({
    required this.ok,
    this.savedToYouTrack = false,
    this.reportId,
    this.youtrackIssueId,
    this.idReadable,
  });

  final bool ok;
  final bool savedToYouTrack;
  final String? reportId;
  final String? youtrackIssueId;
  final String? idReadable;

  static const failed = DiagnosticSubmitResult(ok: false);
}

/// Reporte manual abierto del usuario (seguimiento en app).
class OpenDiagnosticReport {
  const OpenDiagnosticReport({
    required this.reportId,
    required this.kind,
    required this.errorSummary,
    required this.userNote,
    this.idReadable,
    this.youtrackIssueId,
    this.platform,
    this.appVersion,
    this.createdAt,
  });

  final String reportId;
  final String kind;
  final String errorSummary;
  final String userNote;
  final String? idReadable;
  final String? youtrackIssueId;
  final String? platform;
  final String? appVersion;
  final String? createdAt;

  factory OpenDiagnosticReport.fromJson(Map<String, dynamic> json) {
    return OpenDiagnosticReport(
      reportId: '${json['reportId'] ?? ''}',
      kind: '${json['kind'] ?? 'manual'}',
      errorSummary: '${json['errorSummary'] ?? ''}',
      userNote: '${json['userNote'] ?? ''}',
      idReadable: _emptyToNull('${json['idReadable'] ?? ''}'),
      youtrackIssueId: _emptyToNull('${json['youtrackIssueId'] ?? ''}'),
      platform: _emptyToNull('${json['platform'] ?? ''}'),
      appVersion: _emptyToNull('${json['appVersion'] ?? ''}'),
      createdAt: _emptyToNull('${json['createdAt'] ?? ''}'),
    );
  }

  static String? _emptyToNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}

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
  static const maxExcerptChars = 12000;
  static const maxStackChars = 8000;
  static const maxLogLines = 80;
  static const maxLogChars = 6000;
  static const maxErrorSummaryChars = 100;

  static void bindAppSettings(AppSettings? settings) {
    _appSettings = settings;
  }

  /// Firma estable de un error para deduplicar: no es exacta (dos errores
  /// del mismo tipo con mensajes ligeramente distintos comparten firma a
  /// propósito), pero basta para no repetir el mismo bug una y otra vez.
  /// Cross-platform a propósito (misma firma en Android/macOS → un issue).
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

  /// Firma única por envío manual (siempre issue nuevo en YouTrack).
  static String uniqueManualSignature({
    required String installOrUid,
  }) {
    final nonce =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    return sha256
        .convert(utf8.encode('manual|$installOrUid|$nonce'))
        .toString();
  }

  /// OS real del dispositivo (no `defaultTargetPlatform`, que refleja el
  /// target de UI y puede confundirse entre ocurrencias cross-platform).
  static String platformLabel({
    bool? isWeb,
    String? operatingSystem,
  }) {
    if (isWeb ?? kIsWeb) return 'web';
    final os = (operatingSystem ?? Platform.operatingSystem).trim().toLowerCase();
    return os.isEmpty ? 'unknown' : os;
  }

  /// Primera línea legible para el título de YouTrack.
  static String errorSummaryFor({
    String? loggedMessage,
    Object? error,
    int maxChars = maxErrorSummaryChars,
  }) {
    final type = error?.runtimeType.toString().trim() ?? '';
    String detail = '';
    if (error != null) {
      detail = error.toString().trim();
      final prefix = '$type:';
      if (type.isNotEmpty && detail.startsWith(prefix)) {
        detail = detail.substring(prefix.length).trim();
      }
    }
    if (detail.isEmpty && loggedMessage != null) {
      detail = loggedMessage.trim();
    }
    final combined = [
      if (type.isNotEmpty) type,
      if (detail.isNotEmpty) detail,
    ].join(': ');
    if (combined.isEmpty) return '';
    final oneLine = combined.split(RegExp(r'[\r\n]+')).first.trim();
    if (oneLine.length <= maxChars) return oneLine;
    return '${oneLine.substring(0, maxChars - 1)}…';
  }

  /// Descarta la primera línea incompleta tras un corte por bytes (seek).
  static String alignLogTailToLineStart(String raw) {
    if (raw.isEmpty) return '';
    final nl = raw.indexOf('\n');
    if (nl < 0) return raw.trim();
    return raw.substring(nl + 1).trimLeft();
  }

  /// Filtra DEBUG y limita líneas/tamaño de la cola de logs.
  static String filterLogTail(
    String raw, {
    int maxLines = maxLogLines,
    int maxChars = maxLogChars,
  }) {
    if (raw.isEmpty) return '';
    final kept = <String>[];
    for (final line in raw.split('\n')) {
      if (line.contains('[DEBUG]')) continue;
      kept.add(line);
    }
    var start = 0;
    if (kept.length > maxLines) {
      start = kept.length - maxLines;
    }
    var out = kept.sublist(start).join('\n').trim();
    if (out.length > maxChars) {
      final cut = out.substring(out.length - maxChars);
      final nl = cut.indexOf('\n');
      out = (nl >= 0 ? cut.substring(nl + 1) : cut).trimLeft();
    }
    return out;
  }

  /// Excerpt markdown: Error / Stack / Recent logs. Truncar solo logs.
  static String buildLogExcerpt({
    String? loggedTag,
    String? loggedMessage,
    Map<String, Object?>? loggedContext,
    Object? error,
    StackTrace? stackTrace,
    String logTail = '',
    int maxChars = maxExcerptChars,
  }) {
    final errorBuf = StringBuffer();
    if (loggedMessage != null && loggedMessage.isNotEmpty) {
      errorBuf.writeln('[${loggedTag ?? 'app'}] $loggedMessage');
      if (loggedContext != null && loggedContext.isNotEmpty) {
        errorBuf.writeln('context: ${jsonEncode(loggedContext)}');
      }
    }
    if (error != null) errorBuf.writeln(error.toString());
    var errorSection = errorBuf.toString().trim();

    var stackSection = stackTrace?.toString().trim() ?? '';
    if (stackSection.length > maxStackChars) {
      stackSection = '${stackSection.substring(0, maxStackChars)}\n…';
    }

    final logsSection = filterLogTail(logTail);

    String assemble(String logs) {
      final parts = <String>[];
      if (errorSection.isNotEmpty) {
        parts.add('## Error\n$errorSection');
      }
      if (stackSection.isNotEmpty) {
        parts.add('## Stack\n$stackSection');
      }
      if (logs.isNotEmpty) {
        parts.add('## Recent logs\n$logs');
      }
      return parts.join('\n\n').trim();
    }

    var excerpt = assemble(logsSection);
    if (excerpt.length <= maxChars) return excerpt;

    final headLen = assemble('').length;
    final budget = maxChars - headLen - '\n\n## Recent logs\n'.length;
    if (budget <= 0 || logsSection.isEmpty) {
      return assemble('').length <= maxChars
          ? assemble('')
          : assemble('').substring(0, maxChars);
    }
    var shrunkLogs = logsSection;
    if (shrunkLogs.length > budget) {
      final cut = shrunkLogs.substring(shrunkLogs.length - budget);
      final nl = cut.indexOf('\n');
      shrunkLogs = (nl >= 0 ? cut.substring(nl + 1) : cut).trimLeft();
    }
    excerpt = assemble(shrunkLogs);
    if (excerpt.length > maxChars) {
      return excerpt.substring(0, maxChars);
    }
    return excerpt;
  }

  static Uri? _apiUri(String path) {
    try {
      return Uri.parse('${FolioBackendConfig.apiV1Prefix}$path');
    } catch (_) {
      return null;
    }
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
        final raw = utf8.decode(bytes, allowMalformed: true);
        return alignLogTailToLineStart(raw).trim();
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

  static Future<DiagnosticSubmitResult> submit({
    required String kind,
    required String userNote,
    required AppSettings settings,
    Object? error,
    StackTrace? stackTrace,
    String? signature,
    String? loggedTag,
    String? loggedMessage,
    Map<String, Object?>? loggedContext,
    String? steps,
    bool attachAuthIfAvailable = true,
  }) async {
    final uri = _apiUri('/diagnostics/report');
    if (uri == null) {
      AppLogger.warn(
        'Diagnostic report skipped (backend not available)',
        tag: 'diagnostics',
        context: {'backend': FolioBackendConfig.modeLabel},
      );
      return DiagnosticSubmitResult.failed;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final installId = await FolioTelemetry.anonymousInstallId();
      final uid = folioCloudCurrentUid();
      final isManual = kind.trim().isEmpty || kind.trim() == 'manual';
      final effectiveSignature = signature ??
          (isManual
              ? uniqueManualSignature(installOrUid: uid ?? installId)
              : null);

      final noteParts = <String>[
        if (userNote.trim().isNotEmpty) userNote.trim(),
        if (steps != null && steps.trim().isNotEmpty)
          'Steps to reproduce:\n${steps.trim()}',
      ];
      final combinedNote = noteParts.join('\n\n');

      final logTail = await _readLogTail();
      final excerpt = buildLogExcerpt(
        loggedTag: loggedTag ?? (isManual ? 'manual' : null),
        loggedMessage: loggedMessage ??
            (isManual && userNote.trim().isNotEmpty ? userNote.trim() : null),
        loggedContext: loggedContext,
        error: error,
        stackTrace: stackTrace,
        logTail: logTail,
      );
      var summary = errorSummaryFor(
        loggedMessage: loggedMessage ?? userNote,
        error: error,
      );
      if (summary.isEmpty && userNote.trim().isNotEmpty) {
        summary = errorSummaryFor(loggedMessage: userNote.trim());
      }
      if (summary.isEmpty && isManual) {
        summary = 'Manual report';
      }

      String? bearer;
      if (attachAuthIfAvailable && folioCloudHasSession()) {
        bearer = await folioCloudBearerToken();
      }

      Future<http.Response> postOnce({String? token}) {
        return http
            .post(
              uri,
              headers: {
                'content-type': 'application/json; charset=utf-8',
                if (token != null && token.isNotEmpty)
                  'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'installId': installId,
                'kind': kind.trim().isEmpty ? 'manual' : kind.trim(),
                'appVersion': info.version,
                'platform': platformLabel(),
                'channel': AppSettings.distributionChannelFromEnvironment.trim(),
                'telemetryEnabled': settings.telemetryEnabled,
                if (effectiveSignature != null && effectiveSignature.isNotEmpty)
                  'signature': effectiveSignature,
                if (summary.isNotEmpty) 'errorSummary': summary,
                'userNote': combinedNote.length > 2000
                    ? combinedNote.substring(0, 2000)
                    : combinedNote,
                'logExcerpt': excerpt,
              }),
            )
            .timeout(const Duration(seconds: 25));
      }

      var resp = await postOnce(token: bearer);
      // Token caducado en ruta pública: reintentar anónimo.
      if (resp.statusCode == 401 && bearer != null) {
        resp = await postOnce();
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        AppLogger.warn(
          'Diagnostic report failed',
          tag: 'diagnostics',
          context: {'status': resp.statusCode, 'body': resp.body},
        );
        return DiagnosticSubmitResult.failed;
      }
      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}
      AppLogger.info('Diagnostic report sent', tag: 'diagnostics');
      return DiagnosticSubmitResult(
        ok: json['ok'] == true || json['ok'] == null,
        savedToYouTrack: json['savedToYouTrack'] == true,
        reportId: json['reportId']?.toString(),
        youtrackIssueId: json['youtrackIssueId']?.toString(),
        idReadable: json['idReadable']?.toString(),
      );
    } catch (e, st) {
      AppLogger.warn(
        'Diagnostic report error',
        tag: 'diagnostics',
        context: {'error': '$e'},
      );
      AppLogger.debug(
        'Diagnostic stack',
        tag: 'diagnostics',
        context: {'stack': '$st'},
      );
      return DiagnosticSubmitResult.failed;
    }
  }

  static Future<List<OpenDiagnosticReport>> listMyOpenReports() async {
    if (!folioCloudHasSession()) return const [];
    final uri = _apiUri('/diagnostics/my-open');
    if (uri == null) return const [];
    try {
      final token = await folioCloudBearerToken();
      if (token == null || token.isEmpty) return const [];
      final resp = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        AppLogger.warn(
          'listMyOpenReports failed',
          tag: 'diagnostics',
          context: {'status': resp.statusCode},
        );
        return const [];
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return const [];
      final reports = decoded['reports'];
      if (reports is! List) return const [];
      return reports
          .whereType<Map>()
          .map(
            (e) => OpenDiagnosticReport.fromJson(
              e.map((k, v) => MapEntry('$k', v)),
            ),
          )
          .where((r) => r.reportId.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.warn(
        'listMyOpenReports error',
        tag: 'diagnostics',
        context: {'error': '$e'},
      );
      return const [];
    }
  }

  static Future<bool> appendToReport({
    required String reportId,
    required String note,
  }) async {
    if (!folioCloudHasSession()) return false;
    final id = reportId.trim();
    final text = note.trim();
    if (id.isEmpty || text.isEmpty) return false;
    final uri = _apiUri('/diagnostics/my/$id/append');
    if (uri == null) return false;
    try {
      final token = await folioCloudBearerToken();
      if (token == null || token.isEmpty) return false;
      final resp = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'content-type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({'note': text.length > 2000 ? text.substring(0, 2000) : text}),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        AppLogger.warn(
          'appendToReport failed',
          tag: 'diagnostics',
          context: {'status': resp.statusCode, 'body': resp.body},
        );
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.warn(
        'appendToReport error',
        tag: 'diagnostics',
        context: {'error': '$e'},
      );
      return false;
    }
  }
}
