import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_settings.dart';
import 'app_logger.dart';

/// Telemetría opcional (Firebase Analytics). Respeta [AppSettings.telemetryEnabled].
class FolioTelemetry {
  FolioTelemetry._();

  static const _installIdKey = 'folio_anonymous_install_id';
  static const _firstOpenKey = 'folio_first_open_logged_v1';

  static Future<String> anonymousInstallId() async {
    final p = await SharedPreferences.getInstance();
    var id = (p.getString(_installIdKey) ?? '').trim();
    if (id.isEmpty) {
      id = 'u_${DateTime.now().millisecondsSinceEpoch}_${kDebugMode ? 'd' : 'r'}';
      await p.setString(_installIdKey, id);
    }
    return id;
  }

  static Future<void> applyAfterSettingsLoaded(AppSettings settings) async {
    if (Firebase.apps.isEmpty) return;
    try {
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

      final p = await SharedPreferences.getInstance();
      if (p.getBool(_firstOpenKey) ?? false) return;
      await p.setBool(_firstOpenKey, true);
      final info = await PackageInfo.fromPlatform();
      await FirebaseAnalytics.instance.logEvent(
        name: 'first_open',
        parameters: {
          'app_version': info.version,
          'build_number': info.buildNumber,
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

  static Future<void> onSettingsChanged(AppSettings settings) async {
    await applyAfterSettingsLoaded(settings);
  }

  static Future<void> logFeatureUsed(
    AppSettings settings,
    String featureName,
  ) async {
    if (!settings.telemetryEnabled || Firebase.apps.isEmpty) return;
    final name = featureName.trim();
    if (name.isEmpty) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'feature_used',
        parameters: {
          'feature': name.length > 40 ? name.substring(0, 40) : name,
        },
      );
    } catch (_) {}
  }
}
