import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../app/app_settings.dart';
import 'app_logger.dart';
import 'telemetry_models.dart';

/// Telemetría opcional (stub tras Fase 30 — sin GA4 / Firebase Analytics).
///
/// Conserva la API pública y un snapshot local del último evento para el
/// dashboard de diagnóstico. No envía datos a ningún backend.
class FolioTelemetry {
  FolioTelemetry._();

  static const _installIdKey = 'folio_anonymous_install_id';
  static const _installPingKey = 'folio_install_ping_sent_v1';
  static const _lastEventSnapshotKey = 'folio_last_event_snapshot';

  static Future<String> anonymousInstallId() async {
    final p = await SharedPreferences.getInstance();
    var id = (p.getString(_installIdKey) ?? '').trim();
    if (id.isEmpty) {
      id =
          'u_${DateTime.now().millisecondsSinceEpoch}_${kDebugMode ? 'd' : 'r'}';
      await p.setString(_installIdKey, id);
    }
    return id;
  }

  static Future<void> applyAfterSettingsLoaded(AppSettings settings) async {
    // No-op: sin Analytics. Marcamos install ping local una sola vez.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_installPingKey) ?? false) return;
      await anonymousInstallId();
      await PackageInfo.fromPlatform();
      await prefs.setBool(_installPingKey, true);
      AppLogger.debug(
        'Telemetry stub ready (no GA4)',
        tag: 'telemetry',
        context: {
          'enabled': settings.telemetryEnabled,
          'platform': _analyticsPlatformLabel(),
        },
      );
    } catch (e, st) {
      AppLogger.warn(
        'Telemetry init failed',
        tag: 'telemetry',
        context: {'error': '$e'},
      );
      AppLogger.debug(
        'Telemetry stack',
        tag: 'telemetry',
        context: {'stack': '$st'},
      );
    }
  }

  static String _analyticsPlatformLabel() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'other',
    };
  }

  static Future<void> onSettingsChanged(AppSettings settings) async {
    await applyAfterSettingsLoaded(settings);
  }

  static Future<void> _logOnboardingCloudEvent(String name) async {
    // No-op (sin GA4).
    AppLogger.debug('onboarding telemetry', tag: 'telemetry', context: {'name': name});
  }

  static Future<void> logOnboardingCloudPitchViewed() =>
      _logOnboardingCloudEvent('onboarding_cloud_pitch_viewed');

  static Future<void> logOnboardingCloudSignInTapped() =>
      _logOnboardingCloudEvent('onboarding_cloud_sign_in_tapped');

  static Future<void> logOnboardingCloudCheckoutTapped() =>
      _logOnboardingCloudEvent('onboarding_cloud_checkout_tapped');

  static Future<void> logOnboardingCloudSkipped() =>
      _logOnboardingCloudEvent('onboarding_cloud_skipped');

  static Future<void> logFeatureUsed(
    AppSettings settings,
    String featureName,
  ) async {
    if (!settings.telemetryEnabled) return;
    final name = featureName.trim();
    if (name.isEmpty) return;
    _saveLocalSnapshot(
      FeatureEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        featureName: name,
      ),
    );
  }

  static Future<void> logFeatureOpened(
    AppSettings settings,
    String featureName,
  ) async {
    await logFeatureUsed(settings, featureName);
  }

  static Future<void> logContentAction(
    AppSettings settings,
    String action,
    String contentType, {
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!settings.telemetryEnabled) return;
    _saveLocalSnapshot(
      ContentActionEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        action: action.trim(),
        contentType: contentType.trim(),
        metadata: metadata,
      ),
    );
  }

  static Future<void> logNavigation(
    AppSettings settings,
    String fromScreen,
    String toScreen,
  ) async {
    if (!settings.telemetryEnabled) return;
    _saveLocalSnapshot(
      NavigationEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        fromScreen: fromScreen.trim(),
        toScreen: toScreen.trim(),
      ),
    );
  }

  static Future<void> logSearch(
    AppSettings settings,
    String queryType,
    int resultCount, {
    int? durationMs,
  }) async {
    if (!settings.telemetryEnabled) return;
    _saveLocalSnapshot(
      SearchEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        queryType: queryType.trim(),
        resultCount: resultCount,
        durationMs: durationMs,
      ),
    );
  }

  static Future<void> logSyncEvent(
    AppSettings settings,
    String syncType,
    bool success, {
    String? errorMessage,
    int? durationMs,
  }) async {
    if (!settings.telemetryEnabled) return;
    _saveLocalSnapshot(
      SyncEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        syncType: syncType.trim(),
        success: success,
        errorMessage: errorMessage,
        durationMs: durationMs,
      ),
    );
  }

  static Future<void> logPerformance(
    AppSettings settings,
    String operationName,
    int durationMs, {
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!settings.telemetryEnabled) return;
    _saveLocalSnapshot(
      PerformanceEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        operationName: operationName.trim(),
        durationMs: durationMs,
        metadata: metadata,
      ),
    );
  }

  static Future<void> logError(
    AppSettings settings,
    dynamic exception,
    String context, {
    StackTrace? stackTrace,
  }) async {
    if (!settings.telemetryEnabled) return;
    final errorType = exception.runtimeType.toString();
    final errorMsg = exception.toString();
    _saveLocalSnapshot(
      ErrorEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        errorType: errorType,
        errorMessage: errorMsg.length > 500
            ? errorMsg.substring(0, 500)
            : errorMsg,
        context: context,
        stackTrace: stackTrace?.toString(),
      ),
    );
  }

  static Future<void> logUsageStats(
    AppSettings settings,
    Map<String, dynamic> stats,
  ) async {
    if (!settings.telemetryEnabled) return;
    _saveLocalSnapshot(
      UsageStatsEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        stats: stats,
      ),
    );
  }

  static Future<Map<String, dynamic>?> getLastEventSnapshot() async {
    try {
      final p = await SharedPreferences.getInstance();
      final lastEventJson = p.getString(_lastEventSnapshotKey);
      if (lastEventJson == null) return null;
      final decoded = jsonDecode(lastEventJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), _jsonDecodeValue(v)),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static dynamic _jsonDecodeValue(dynamic v) {
    if (v is Map) {
      return v.map(
        (k, val) => MapEntry(k.toString(), _jsonDecodeValue(val)),
      );
    }
    if (v is List) {
      return v.map(_jsonDecodeValue).toList();
    }
    return v;
  }

  static void _saveLocalSnapshot(TelemetryEvent event) {
    unawaited(_persistLastEventSnapshot(event));
  }

  static Future<void> _persistLastEventSnapshot(TelemetryEvent event) async {
    try {
      final p = await SharedPreferences.getInstance();
      final snapshot = {
        'timestamp': event.timestamp.toIso8601String(),
        'type': event.type.toString().split('.').last,
        'data': event.toDataMap(),
      };
      await p.setString(_lastEventSnapshotKey, jsonEncode(snapshot));
    } catch (_) {}
  }
}
