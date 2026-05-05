import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

import 'app/app_settings.dart';
import 'config/folio_local_secrets.dart';
import 'app/folio_app.dart';
import 'app/folio_runtime_config.dart';
import 'firebase_options.dart';
import 'services/app_log_file_sink.dart';
import 'services/app_logger.dart';
import 'services/folio_diagnostic_reporter.dart';
import 'services/folio_telemetry.dart';
import 'services/folio_firestore_sync.dart';
import 'services/cloud_account/cloud_account_controller.dart';
import 'services/env/local_env_loader.dart';
import 'services/env/local_env.dart';
import 'services/folio_cloud/folio_cloud_entitlements.dart';
import 'services/platform/launch_arguments.dart';
import 'session/vault_session.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (!kIsWeb) AppLogger.setSink(await AppLogFileSink.init());

      // Opcional: `.env` en disco (solo dart:io). Los secretos habituales van en
      // `lib/config/folio_local_secrets.dart` (y en web solo eso o --dart-define).
      if (!kIsWeb) {
        try {
          final res = await LocalEnvLoader.loadLocalEnv(filename: '.env');
          if (res.loaded) {
            AppLogger.info(
              'local env file loaded',
              tag: 'env',
              context: {'path': res.path ?? '—'},
            );
            // No loguear valores; solo presencia.
            AppLogger.info(
              'local env keys present',
              tag: 'env',
              context: {
                'hasClientId': _hasJiraClientId(),
                'hasClientSecret': _hasJiraClientSecret(),
              },
            );
            // ignore: avoid_print
            print(
              '[folio.env] keys present hasClientId=${_hasJiraClientId()} '
              'hasClientSecret=${_hasJiraClientSecret()}',
            );
          } else {
            AppLogger.warn('local env file not found', tag: 'env');
          }
        } catch (e, st) {
          AppLogger.warn('local env load failed', tag: 'env', context: {'error': '$e'});
          AppLogger.debug('local env load stack', tag: 'env', context: {'stack': '$st'});
          // ignore: avoid_print
          print('[folio.env] load failed error=$e');
        }
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'Flutter framework error',
          tag: 'crash',
          error: details.exception,
          stackTrace: details.stack,
          context: {
            'library': details.library,
            'context': details.context?.toDescription(),
          },
        );
        unawaited(
          FolioDiagnosticReporter.maybeReportCrash(
            details.exception,
            details.stack ?? StackTrace.empty,
          ),
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.error(
          'Uncaught PlatformDispatcher error',
          tag: 'crash',
          error: error,
          stackTrace: stackTrace,
        );
        unawaited(FolioDiagnosticReporter.maybeReportCrash(error, stackTrace));
        return true;
      };

      SystemTheme.fallbackColor = const Color(0xFF455A64);
      try {
        await SystemTheme.accentColor.load();
      } catch (e, st) {
        AppLogger.warn(
          'SystemTheme accent load failed',
          tag: 'theme',
          context: {'error': '$e'},
        );
        AppLogger.debug(
          'SystemTheme accent stack',
          tag: 'theme',
          context: {'stack': '$st'},
        );
      }

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e, st) {
        AppLogger.error(
          'Firebase init failed',
          tag: 'firebase',
          error: e,
          stackTrace: st,
        );
      }

      final cloudAccountController = CloudAccountController();
      final folioCloudEntitlements = FolioCloudEntitlementsController();
      final runtimeConfig = await FolioRuntimeConfig.load();
      final appSettings = AppSettings(
        integrationSecret: runtimeConfig.integrationSecret,
      );
      await appSettings.load();
      await FolioTelemetry.applyAfterSettingsLoaded(appSettings);
      FolioFirestoreSync.initialize();
      final session = VaultSession(titleLocale: appSettings.locale);
      final initialLaunchArgs =
          await PlatformLaunchArguments.initialArguments();
      runApp(
        FolioApp(
          session: session,
          appSettings: appSettings,
          cloudAccountController: cloudAccountController,
          folioCloudEntitlements: folioCloudEntitlements,
          initialLaunchArgs: initialLaunchArgs,
        ),
      );
    },
    (error, stackTrace) {
      AppLogger.error(
        'Uncaught zoned error',
        tag: 'crash',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(
        FolioDiagnosticReporter.maybeReportCrash(error, stackTrace),
      );
    },
  );
}

bool _hasJiraClientId() {
  if (const String.fromEnvironment('JIRA_OAUTH_CLIENT_ID').trim().isNotEmpty) {
    return true;
  }
  if (FolioLocalSecrets.valueForDefineKey('JIRA_OAUTH_CLIENT_ID')
      .trim()
      .isNotEmpty) {
    return true;
  }
  return LocalEnv.has('JIRA_OAUTH_CLIENT_ID');
}

bool _hasJiraClientSecret() {
  if (const String.fromEnvironment('JIRA_OAUTH_CLIENT_SECRET')
      .trim()
      .isNotEmpty) {
    return true;
  }
  if (FolioLocalSecrets.valueForDefineKey('JIRA_OAUTH_CLIENT_SECRET')
      .trim()
      .isNotEmpty) {
    return true;
  }
  return LocalEnv.has('JIRA_OAUTH_CLIENT_SECRET');
}
