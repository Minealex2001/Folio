import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

import 'app/app_settings.dart';
import 'config/config_bootstrap.dart';
import 'config/config_store.dart';
import 'config/folio_local_secrets.dart';
import 'config/models/dashboard_config.dart';
import 'config/models/layout_config.dart';
import 'config/models/panel_region_ids.dart';
import 'app/folio_app.dart';
import 'app/folio_runtime_config.dart';
import 'config/folio_backend_config.dart';
import 'config/folio_web_urls.dart';
import 'layout_engine/layout_engine_controller.dart';
import 'theme_engine/theme_config_controller.dart';
import 'widget_catalog/builtin/builtin_widget_plugins.dart';
import 'widget_catalog/dnd/dashboard_grid_controller.dart';
import 'features/web_public/folio_web_public_app.dart';
import 'services/app_log_file_sink.dart';
import 'services/app_logger.dart';
import 'services/folio_diagnostic_reporter.dart';
import 'services/folio_telemetry.dart';
import 'services/cloud_account/cloud_account_controller.dart';
import 'services/env/local_env_loader.dart';
import 'services/env/local_env.dart';
import 'services/folio_cloud/folio_cloud_entitlements.dart';
import 'meeting_worker/meeting_worker_main.dart';
import 'meeting_worker/meeting_worker_protocol.dart';
import 'services/platform/launch_arguments.dart';
import 'session/vault_session.dart';

Future<void> main(List<String> args) async {
  if (MeetingWorkerProtocol.isWorkerArgs(args)) {
    await runMeetingWorker(args);
    return;
  }

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (!kIsWeb) AppLogger.setSink(await AppLogFileSink.init());
      // Cualquier AppLogger.error(...) (crash o no) dispara un intento de
      // auto-report — ver FolioDiagnosticReporter.maybeReportLoggedError.
      AppLogger.setOnError(FolioDiagnosticReporter.maybeReportLoggedError);

      // Rutas públicas web (share, reset/verify email, verify estudiante): sin vault lock.
      if (kIsWeb) {
        final publicRoute = FolioWebPublicRoute.match(Uri.base);
        if (publicRoute != null) {
          FlutterError.onError = (details) {
            FlutterError.presentError(details);
            AppLogger.error(
              'Flutter framework error',
              tag: 'crash',
              error: details.exception,
              stackTrace: details.stack,
            );
          };
          runApp(FolioWebPublicApp(route: publicRoute));
          return;
        }
      }

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
          } else {
            AppLogger.warn('local env file not found', tag: 'env');
          }
        } catch (e, st) {
          AppLogger.error(
            'local env load failed',
            tag: 'env',
            error: e,
            stackTrace: st,
          );
        }
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        // AppLogger.setOnError ya dispara el auto-report para este error.
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
        // AppLogger.setOnError ya dispara el auto-report para este error.
        AppLogger.error(
          'Uncaught PlatformDispatcher error',
          tag: 'crash',
          error: error,
          stackTrace: stackTrace,
        );
        return true;
      };

      SystemTheme.fallbackColor = const Color(0xFF00F3FF);
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

      AppLogger.info(
        'Spring backend mode (Fase 30 — Firebase decomisionado)',
        tag: 'backend',
        context: {
          'baseUrl': FolioBackendConfig.baseUrl.isEmpty
              ? '(unset)'
              : FolioBackendConfig.baseUrl,
        },
      );

      final cloudAccountController = CloudAccountController();
      try {
        await cloudAccountController.ensureSpringSessionRestored();
      } catch (e, st) {
        AppLogger.error(
          'Spring session restore failed',
          tag: 'backend',
          error: e,
          stackTrace: st,
        );
      }
      final folioCloudEntitlements = FolioCloudEntitlementsController();
      folioCloudEntitlements.listenToCloudAccount(cloudAccountController);

      // A diferencia de las fases de arriba (env/.env, SystemTheme),
      // esta carga no estaba protegida: si algo aquí lanzaba, runApp() nunca se
      // ejecutaba y el proceso quedaba sin ventana visible en vez de degradar
      // con defaults (rompe el arranque-por-fases documentado en FEATURES.md).
      AppSettings appSettings;
      try {
        final runtimeConfig = await FolioRuntimeConfig.load();
        appSettings = AppSettings(
          integrationSecret: runtimeConfig.integrationSecret,
        );
        await appSettings.load();
        await FolioTelemetry.applyAfterSettingsLoaded(appSettings);
      } catch (e, st) {
        AppLogger.error(
          'App settings bootstrap failed; continuing with defaults',
          tag: 'bootstrap',
          error: e,
          stackTrace: st,
        );
        appSettings = AppSettings(integrationSecret: '');
        // Best effort: si el fallo fue después de construir AppSettings (p.ej.
        // en applyAfterSettingsLoaded), intenta igual cargar prefs guardadas.
        try {
          await appSettings.load();
        } catch (_) {}
      }

      // Sistema de personalización de UI (Fase 1): igual que AppSettings
      // arriba, un fallo aquí no debe bloquear runApp() — degrada a un
      // ConfigStore vacío (sin migración) en vez de tumbar el arranque.
      ConfigStore configStore;
      try {
        configStore = await ConfigStore.open();
        await ConfigBootstrap.migrateLegacyAppSettings(appSettings, configStore);
      } catch (e, st) {
        AppLogger.error(
          'Config store bootstrap/migration failed; continuing without it',
          tag: 'bootstrap',
          error: e,
          stackTrace: st,
        );
        configStore = await ConfigStore.open();
      }

      // Motor de layout (Fase 2): carga el LayoutConfig "activo" (poblado
      // por la migración de arriba) y conecta el hook de AppSettings para
      // que futuros resizes del sidebar también queden reflejados aquí.
      // El resto del shell (workspace_page.dart) todavía no LEE de este
      // controller — solo se mantiene sincronizado hacia adelante.
      LayoutEngineController layoutEngineController;
      try {
        layoutEngineController = await LayoutEngineController.load(
          configStore,
          id: ConfigBootstrap.activeLayoutId,
        );
        appSettings.onWorkspaceSidebarWidthChanged = (width) {
          layoutEngineController.setSize(
            PanelRegionIds.sidebarLeft,
            width: width,
          );
        };
      } catch (e, st) {
        AppLogger.error(
          'Layout engine controller bootstrap failed; continuing without it',
          tag: 'bootstrap',
          error: e,
          stackTrace: st,
        );
        layoutEngineController = LayoutEngineController(
          configStore,
          initialConfig: LayoutConfig.defaultConfig(
            id: ConfigBootstrap.activeLayoutId,
          ),
        );
      }

      // Motor de tema (Fase 3 + editor de temas): carga el ThemeConfig
      // "activo" y conecta el hook — el picker de acento/modo existente en
      // Settings sigue viviendo en AppSettings, esto solo mantiene
      // accentMode/light/dark del ThemeConfig sincronizados con él. Los
      // campos nuevos (radio/espaciado/opacidad/movimiento) los edita
      // directo el editor de temas, sin pasar por AppSettings.
      ThemeConfigController themeConfigController;
      try {
        themeConfigController = await ThemeConfigController.load(
          configStore,
          id: ConfigBootstrap.activeThemeId,
        );
        appSettings.onThemeAccentChanged = () {
          themeConfigController.replaceConfig(
            ConfigBootstrap.themeConfigFromAppSettings(
              appSettings,
              preserving: themeConfigController.config,
            ),
          );
        };
      } catch (e, st) {
        AppLogger.error(
          'Theme config controller bootstrap failed; continuing without it',
          tag: 'bootstrap',
          error: e,
          stackTrace: st,
        );
        themeConfigController = ThemeConfigController(
          configStore,
          initialConfig: ConfigBootstrap.themeConfigFromAppSettings(appSettings),
        );
      }

      // Catálogo de widgets de dashboard (Fase 4/5): carga el
      // DashboardConfig "activo" y conecta el hook — cualquier cambio a
      // orden/visibilidad/layout de columnas del dashboard de inicio (12
      // setters en AppSettings) re-deriva el DashboardConfig completo y lo
      // aplica al controller en vivo (no solo lo persiste), para que
      // workspace_home_view.dart -- que ya lee el orden de secciones desde
      // este controller -- vea el cambio de inmediato.
      DashboardGridController dashboardGridController;
      try {
        dashboardGridController = await DashboardGridController.load(
          configStore,
          id: ConfigBootstrap.activeDashboardId,
          name: 'Inicio',
        );
        appSettings.onWorkspaceHomeDashboardChanged = () {
          dashboardGridController.replaceConfig(
            ConfigBootstrap.dashboardConfigFromAppSettings(appSettings),
          );
        };
      } catch (e, st) {
        AppLogger.error(
          'Dashboard grid controller bootstrap failed; continuing without it',
          tag: 'bootstrap',
          error: e,
          stackTrace: st,
        );
        dashboardGridController = DashboardGridController(
          configStore,
          initialConfig: DashboardConfig(
            id: ConfigBootstrap.activeDashboardId,
            name: 'Inicio',
          ),
        );
      }

      VaultSession session;
      try {
        session = VaultSession(titleLocale: appSettings.locale);
      } catch (e, st) {
        AppLogger.error(
          'VaultSession construction failed; retrying with defaults',
          tag: 'bootstrap',
          error: e,
          stackTrace: st,
        );
        session = VaultSession();
      }
      var initialLaunchArgs = const <String>[];
      try {
        initialLaunchArgs = await PlatformLaunchArguments.initialArguments();
      } catch (e, st) {
        AppLogger.warn(
          'Reading initial launch arguments failed',
          tag: 'bootstrap',
          context: {'error': '$e', 'stack': '$st'},
        );
      }
      registerBuiltinWidgetPlugins();

      runApp(
        FolioApp(
          session: session,
          appSettings: appSettings,
          cloudAccountController: cloudAccountController,
          configStore: configStore,
          layoutEngineController: layoutEngineController,
          dashboardGridController: dashboardGridController,
          themeConfigController: themeConfigController,
          folioCloudEntitlements: folioCloudEntitlements,
          initialLaunchArgs: initialLaunchArgs,
        ),
      );
    },
    (error, stackTrace) {
      // AppLogger.setOnError ya dispara el auto-report para este error.
      AppLogger.error(
        'Uncaught zoned error',
        tag: 'crash',
        error: error,
        stackTrace: stackTrace,
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
