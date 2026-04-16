import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:system_theme/system_theme.dart';

import 'app/app_settings.dart';
import 'app/folio_app.dart';
import 'app/folio_runtime_config.dart';
import 'firebase_options.dart';
import 'services/app_log_file_sink.dart';
import 'services/app_logger.dart';
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
      AppLogger.setSink(await AppLogFileSink.init());

      // Cargar variables locales (no versionadas) desde `.env`.
      try {
        final res = await LocalEnvLoader.loadLocalEnv(filename: '.env');
        if (res.loaded) {
          AppLogger.info(
            'dotenv loaded',
            tag: 'env',
            context: {'path': res.path ?? '—'},
          );
          // No loguear valores; solo presencia.
          AppLogger.info(
            'dotenv keys present',
            tag: 'env',
            context: {
              'hasClientId':
                  LocalEnv.has('JIRA_OAUTH_CLIENT_ID') ||
                      (dotenv.env['JIRA_OAUTH_CLIENT_ID'] ?? '').trim().isNotEmpty,
              'hasClientSecret':
                  LocalEnv.has('JIRA_OAUTH_CLIENT_SECRET') ||
                      (dotenv.env['JIRA_OAUTH_CLIENT_SECRET'] ?? '').trim().isNotEmpty,
            },
          );
          // ignore: avoid_print
          print(
            '[folio.env] keys present hasClientId='
            '${LocalEnv.has('JIRA_OAUTH_CLIENT_ID') || (dotenv.env['JIRA_OAUTH_CLIENT_ID'] ?? '').trim().isNotEmpty} '
            'hasClientSecret='
            '${LocalEnv.has('JIRA_OAUTH_CLIENT_SECRET') || (dotenv.env['JIRA_OAUTH_CLIENT_SECRET'] ?? '').trim().isNotEmpty}',
          );
        } else {
          AppLogger.warn('dotenv not found', tag: 'env');
        }
      } catch (e, st) {
        AppLogger.warn('dotenv load failed', tag: 'env', context: {'error': '$e'});
        AppLogger.debug('dotenv load stack', tag: 'env', context: {'stack': '$st'});
        // ignore: avoid_print
        print('[folio.env] load failed error=$e');
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
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.error(
          'Uncaught PlatformDispatcher error',
          tag: 'crash',
          error: error,
          stackTrace: stackTrace,
        );
        return true;
      };

      SystemTheme.fallbackColor = const Color(0xFF455A64);
      await SystemTheme.accentColor.load();

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
    },
  );
}
