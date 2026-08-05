import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../app/app_settings.dart';
import 'config_store.dart';
import 'models/dashboard_config.dart';
import 'models/layout_config.dart';
import 'models/panel_config.dart';
import 'models/panel_region_ids.dart';
import 'models/theme_config.dart';
import 'models/widget_instance_config.dart';

const _uuid = Uuid();

/// Migra una vez la configuración legacy de [AppSettings] (sobre
/// `SharedPreferences`) hacia el nuevo [ConfigStore] (JSON), construyendo el
/// `LayoutConfig`/`ThemeConfig`/`DashboardConfig` "activo" equivalente.
///
/// Corre una sola vez por instalación (flag centinela en
/// `SharedPreferences`) para no pisar personalización que el usuario haga
/// después dentro del nuevo sistema. Los getters legacy de [AppSettings]
/// para los campos migrados se mantienen como passthrough deprecado durante
/// una versión de transición — ver Fases 2/3/4 del plan.
class ConfigBootstrap {
  ConfigBootstrap._();

  static const String _migratedFlagKey = 'folio_config_migrated_v1';
  static const String activeLayoutId = 'active';
  static const String activeThemeId = 'active';
  static const String activeDashboardId = 'active';

  static Future<void> migrateLegacyAppSettings(
    AppSettings appSettings,
    ConfigStore configStore,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlagKey) ?? false) return;

    await configStore.saveLayout(_layoutFromLegacy(appSettings));
    await configStore.saveTheme(themeConfigFromAppSettings(appSettings));
    await configStore.saveDashboard(
      _withDefaultClock(dashboardConfigFromAppSettings(appSettings)),
    );

    await prefs.setBool(_migratedFlagKey, true);
  }

  /// Añade un widget 'clock' real al principio de la columna izquierda,
  /// solo en la migración de una sola vez — bug real reportado: el reloj
  /// grande de la cabecera de inicio era chrome fijo, imposible de quitar.
  /// Ahora es una instancia de widget más (misma pieza que
  /// `ClockWidgetPlugin`), removible/re-añadible desde el editor de
  /// dashboard igual que cualquier otra. Deliberadamente NO se hace esto
  /// dentro de `dashboardConfigFromAppSettings` — esa función también la
  /// llama `AppSettings.onWorkspaceHomeDashboardChanged` en cada cambio de
  /// un toggle legacy, y reinsertar aquí crearía un reloj duplicado cada
  /// vez que eso disparase.
  static DashboardConfig _withDefaultClock(DashboardConfig config) {
    final shiftedLeft = [
      for (final w in config.widgets)
        if (w.regionId == DashboardRegionIds.left) w.copyWith(order: w.order + 1),
    ];
    final others = config.widgets.where(
      (w) => w.regionId != DashboardRegionIds.left,
    );
    return config.copyWith(
      widgets: [
        WidgetInstanceConfig(
          instanceId: _uuid.v4(),
          pluginId: 'clock',
          regionId: DashboardRegionIds.left,
          order: 0,
          // Alto explícito: el contenido (saludo + fecha + reloj grande +
          // titular + subtítulo) es bastante más alto que los 160px por
          // defecto de otros widgets — sin esto, RenderFlex se desborda.
          height: 300,
        ),
        ...shiftedLeft,
        ...others,
      ],
    );
  }

  static LayoutConfig _layoutFromLegacy(AppSettings appSettings) {
    final base = LayoutConfig.defaultConfig(id: activeLayoutId);
    final sidebar = base.panels[PanelRegionIds.sidebarLeft];
    if (sidebar == null) return base;
    final panels = Map<String, PanelConfig>.from(base.panels);
    panels[PanelRegionIds.sidebarLeft] = sidebar.copyWith(
      width: appSettings.workspaceSidebarWidth,
    );
    return base.copyWith(panels: panels);
  }

  /// Traduce el estado de tema actual de [AppSettings] (modo de acento,
  /// ARGB custom, OLED) a un [ThemeConfig]. Se llama una vez en la
  /// migración inicial, y de nuevo cada vez que
  /// `AppSettings.onThemeAccentChanged` dispara (ver `ThemeConfigController`
  /// — editor de temas). Cuando se provee [preserving], conserva todo lo
  /// demás de ese `ThemeConfig` (shape/spacing/motion/elevation/
  /// surfaceOpacity — los campos que el editor de temas nuevo edita
  /// directamente y que `AppSettings` nunca tuvo) y solo actualiza
  /// accentMode/light/dark.
  static ThemeConfig themeConfigFromAppSettings(
    AppSettings appSettings, {
    ThemeConfig? preserving,
  }) {
    final seedArgb = appSettings.accentColorMode == FolioAccentColorMode.custom
        ? appSettings.customAccentArgb
        : null; // null → ThemeConfig.fallbackDefault usa el seed de marca
    final accentMode = switch (appSettings.accentColorMode) {
      FolioAccentColorMode.followSystem => 'followSystem',
      FolioAccentColorMode.folioDefault => 'folioDefault',
      FolioAccentColorMode.custom => 'custom',
    };
    final derived = ThemeConfig.fallbackDefault(
      id: activeThemeId,
      seedArgb: seedArgb,
      oled: appSettings.oledThemeEnabled,
      accentMode: accentMode,
    );
    if (preserving == null) return derived;
    return preserving.copyWith(
      accentMode: derived.accentMode,
      light: derived.light,
      dark: derived.dark,
    );
  }

  /// Traduce el estado actual del dashboard de inicio en [AppSettings]
  /// (orden de secciones izq/der, toggles de visibilidad, layout de
  /// columnas) a un [DashboardConfig] equivalente. Público — se llama tanto
  /// en la migración de una sola vez como cada vez que
  /// `AppSettings.onWorkspaceHomeDashboardChanged` dispara (ver Fase 4).
  static DashboardConfig dashboardConfigFromAppSettings(
    AppSettings appSettings,
  ) {
    final columns = switch (appSettings.workspaceHomeColumnLayout) {
      WorkspaceHomeColumnLayout.single => 1,
      WorkspaceHomeColumnLayout.dual => 2,
      WorkspaceHomeColumnLayout.auto => 2,
    };

    final widgets = <WidgetInstanceConfig>[
      ..._widgetsFor(
        appSettings.workspaceHomeLeftSectionOrder,
        DashboardRegionIds.left,
        appSettings,
      ),
      ..._widgetsFor(
        appSettings.workspaceHomeRightSectionOrder,
        DashboardRegionIds.right,
        appSettings,
      ),
    ];

    return DashboardConfig(
      id: activeDashboardId,
      name: 'Inicio',
      columns: columns,
      widgets: widgets,
    );
  }

  static List<WidgetInstanceConfig> _widgetsFor(
    List<String> sectionOrder,
    String regionId,
    AppSettings appSettings,
  ) {
    final result = <WidgetInstanceConfig>[];
    for (var i = 0; i < sectionOrder.length; i++) {
      final sectionId = sectionOrder[i];
      result.add(
        WidgetInstanceConfig(
          instanceId: _uuid.v4(),
          pluginId: sectionId,
          regionId: regionId,
          order: i,
          visible: _legacyVisibilityFor(sectionId, appSettings),
        ),
      );
    }
    return result;
  }

  /// Mapea el id de sección legacy (`WorkspaceHomeSectionIds`) al booleano de
  /// visibilidad equivalente en `AppSettings`. Las secciones sin toggle
  /// propio (search/recents/createPage) siempre fueron visibles.
  static bool _legacyVisibilityFor(String sectionId, AppSettings appSettings) {
    switch (sectionId) {
      case WorkspaceHomeSectionIds.folioCloud:
        return appSettings.workspaceHomeShowFolioCloudCard;
      case WorkspaceHomeSectionIds.vaultStatus:
        return appSettings.workspaceHomeShowVaultStatus;
      case WorkspaceHomeSectionIds.onboarding:
        return appSettings.workspaceHomeShowOnboarding;
      case WorkspaceHomeSectionIds.whatsNew:
        return appSettings.workspaceHomeShowWhatsNew;
      case WorkspaceHomeSectionIds.rootPages:
        return appSettings.workspaceHomeShowRootPages;
      case WorkspaceHomeSectionIds.miniStats:
        return appSettings.workspaceHomeShowMiniStats;
      case WorkspaceHomeSectionIds.tasks:
        return appSettings.workspaceHomeShowTasksSection;
      case WorkspaceHomeSectionIds.quickActions:
        return appSettings.workspaceHomeShowQuickActions;
      case WorkspaceHomeSectionIds.tip:
        return appSettings.workspaceHomeShowTip;
      default:
        return true;
    }
  }
}
