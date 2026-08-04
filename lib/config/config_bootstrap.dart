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
    await configStore.saveTheme(_themeFromLegacy(appSettings));
    await configStore.saveDashboard(_dashboardFromLegacy(appSettings));

    await prefs.setBool(_migratedFlagKey, true);
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

  static ThemeConfig _themeFromLegacy(AppSettings appSettings) {
    final seedArgb = appSettings.accentColorMode == FolioAccentColorMode.custom
        ? appSettings.customAccentArgb
        : null; // null → ThemeConfig.fallbackDefault usa el seed de marca
    return ThemeConfig.fallbackDefault(
      id: activeThemeId,
      seedArgb: seedArgb,
      oled: appSettings.oledThemeEnabled,
    );
  }

  static DashboardConfig _dashboardFromLegacy(AppSettings appSettings) {
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
