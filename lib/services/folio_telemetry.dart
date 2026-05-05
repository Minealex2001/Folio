import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../app/app_settings.dart';
import 'app_logger.dart';
import 'folio_firestore_sync.dart';
import 'telemetry_models.dart';

/// Telemetría opcional (Firebase Analytics). Respeta [AppSettings.telemetryEnabled].
class FolioTelemetry {
  FolioTelemetry._();

  /// En Windows/Linux el binario de Flutter no registra el plugin de Analytics
  /// (no aparece en `generated_plugin_registrant.cc`); las llamadas Pigeon fallan
  /// con `channel-error` y no deben ejecutarse.
  static bool get _canUseFirebaseAnalytics {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        true,
      _ => false,
    };
  }

  static const _installIdKey = 'folio_anonymous_install_id';
  /// Ping único a GA4 por instalación (independiente del interruptor de telemetría).
  static const _installPingKey = 'folio_install_ping_sent_v1';

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
    if (Firebase.apps.isEmpty) return;
    if (!_canUseFirebaseAnalytics) return;
    try {
      await _recordMinimalInstallIfNeeded(settings);

      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        settings.telemetryEnabled,
      );
      if (!settings.telemetryEnabled) return;

      final id = await anonymousInstallId();
      await FirebaseAnalytics.instance.setUserId(id: id);

      final channel = AppSettings.distributionChannelFromEnvironment.trim();
      if (channel.isNotEmpty) {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'distribution_channel',
          value: channel.length > 36 ? channel.substring(0, 36) : channel,
        );
      }
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

  /// Un evento [folio_install] por instalación (GA4), aunque la telemetría opcional esté desactivada.
  static Future<void> _recordMinimalInstallIfNeeded(
    AppSettings settings,
  ) async {
    if (!_canUseFirebaseAnalytics || Firebase.apps.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_installPingKey) ?? false) return;

    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      final id = await anonymousInstallId();
      await FirebaseAnalytics.instance.setUserId(id: id);

      final info = await PackageInfo.fromPlatform();
      await FirebaseAnalytics.instance.logEvent(
        name: 'folio_install',
        parameters: {
          'app_version': info.version,
          'build_number': info.buildNumber,
          'folio_platform': _analyticsPlatformLabel(),
        },
      );
      await prefs.setBool(_installPingKey, true);
    } catch (e, st) {
      AppLogger.warn(
        'Minimal install telemetry failed',
        tag: 'telemetry',
        context: {'error': '$e'},
      );
      AppLogger.debug(
        'Minimal install telemetry stack',
        tag: 'telemetry',
        context: {'stack': '$st'},
      );
    } finally {
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
          settings.telemetryEnabled,
        );
      } catch (_) {}
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

  static Future<void> logFeatureUsed(
    AppSettings settings,
    String featureName,
  ) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    final name = featureName.trim();
    if (name.isEmpty) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'feature_used',
        parameters: {
          'feature': name.length > 40 ? name.substring(0, 40) : name,
        },
      );
      // También registrar en Firestore para análisis más detallado
      _logEventToFirestore(
        FeatureEvent(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          featureName: name,
        ),
      );
    } catch (_) {}
  }

  /// Log: Feature abierto/usado
  static Future<void> logFeatureOpened(
    AppSettings settings,
    String featureName,
  ) async {
    await logFeatureUsed(settings, featureName);
  }

  /// Log: Acción sobre contenido (crear, editar, eliminar, ver)
  static Future<void> logContentAction(
    AppSettings settings,
    String action,
    String contentType, {
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'content_action',
        parameters: {
          'action': action.trim(),
          'content_type': contentType.trim(),
        },
      );
      _logEventToFirestore(
        ContentActionEvent(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          action: action.trim(),
          contentType: contentType.trim(),
          metadata: metadata,
        ),
      );
    } catch (_) {}
  }

  /// Log: Navegación entre pantallas
  static Future<void> logNavigation(
    AppSettings settings,
    String fromScreen,
    String toScreen,
  ) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'screen_view',
        parameters: {
          'screen_class': toScreen.trim(),
          'from_screen': fromScreen.trim(),
        },
      );
      _logEventToFirestore(
        NavigationEvent(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          fromScreen: fromScreen.trim(),
          toScreen: toScreen.trim(),
        ),
      );
    } catch (_) {}
  }

  /// Log: Búsqueda/filtrado
  static Future<void> logSearch(
    AppSettings settings,
    String queryType,
    int resultCount, {
    int? durationMs,
  }) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'search',
        parameters: {
          'search_term': queryType.trim(),
          'result_count': resultCount,
          'duration_ms': ?durationMs,
        },
      );
      _logEventToFirestore(
        SearchEvent(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          queryType: queryType.trim(),
          resultCount: resultCount,
          durationMs: durationMs,
        ),
      );
    } catch (_) {}
  }

  /// Log: Sincronización
  static Future<void> logSyncEvent(
    AppSettings settings,
    String syncType,
    bool success, {
    String? errorMessage,
    int? durationMs,
  }) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'sync_event',
        parameters: {
          'sync_type': syncType.trim(),
          'success': success,
          if (errorMessage != null && errorMessage.isNotEmpty)
            'error': errorMessage,
          'duration_ms': ?durationMs,
        },
      );
      _logEventToFirestore(
        SyncEvent(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          syncType: syncType.trim(),
          success: success,
          errorMessage: errorMessage,
          durationMs: durationMs,
        ),
      );
    } catch (_) {}
  }

  /// Log: Rendimiento de operación
  static Future<void> logPerformance(
    AppSettings settings,
    String operationName,
    int durationMs, {
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'performance',
        parameters: {
          'operation': operationName.trim(),
          'duration_ms': durationMs,
        },
      );
      _logEventToFirestore(
        PerformanceEvent(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          operationName: operationName.trim(),
          durationMs: durationMs,
          metadata: metadata,
        ),
      );
    } catch (_) {}
  }

  /// Log: Error o excepción
  static Future<void> logError(
    AppSettings settings,
    dynamic exception,
    String context, {
    StackTrace? stackTrace,
  }) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      final errorType = exception.runtimeType.toString();
      final errorMsg = exception.toString();

      await FirebaseAnalytics.instance.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType.length > 100
              ? errorType.substring(0, 100)
              : errorType,
          'context': context.length > 100 ? context.substring(0, 100) : context,
        },
      );
      _logEventToFirestore(
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
    } catch (_) {}
  }

  /// Log: Estadísticas de uso (cantidad de notas, tamaño, etc.)
  static Future<void> logUsageStats(
    AppSettings settings,
    Map<String, dynamic> stats,
  ) async {
    if (!_canUseFirebaseAnalytics ||
        !settings.telemetryEnabled ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      // Enviar solo subset de stats a Firebase Analytics (límite de propiedades)
      final analyticsStats = <String, Object>{};
      var count = 0;
      for (final entry in stats.entries) {
        if (count >= 10) break; // Máximo 10 propiedades
        if (entry.value is int ||
            entry.value is String ||
            entry.value is bool) {
          analyticsStats[entry.key] = entry.value as Object;
          count++;
        }
      }

      await FirebaseAnalytics.instance.logEvent(
        name: 'usage_stats',
        parameters: analyticsStats,
      );
      _logEventToFirestore(
        UsageStatsEvent(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          stats: stats,
        ),
      );
    } catch (_) {}
  }

  /// Último evento registrado localmente (Analytics + snapshot para Firestore si aplica).
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

  // ============ PRIVADOS ============

  static const _lastEventSnapshotKey = 'folio_last_event_snapshot';

  static void _logEventToFirestore(TelemetryEvent event) {
    unawaited(_saveLastEventSnapshot(event));
    if (FirebaseAuth.instance.currentUser == null) return;
    FolioFirestoreSync.addEvent(event);
  }

  static Future<void> _saveLastEventSnapshot(TelemetryEvent event) async {
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
