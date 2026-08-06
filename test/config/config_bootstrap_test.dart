import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_bootstrap.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'folio_config_bootstrap_test',
    );
    ConfigStoreBackend.debugRootOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
    'migrates legacy AppSettings values into an equivalent ConfigStore state',
    () async {
      final appSettings = AppSettings();
      await appSettings.load();

      await appSettings.setWorkspaceSidebarWidth(340);
      await appSettings.setAccentColorMode(FolioAccentColorMode.custom);
      await appSettings.setCustomAccentArgb(0xFF112233);
      await appSettings.setThemeMode(FolioThemeMode.oled);
      await appSettings.setWorkspaceHomeShowFolioCloudCard(false);
      await appSettings.setWorkspaceHomeLeftSectionOrder([
        WorkspaceHomeSectionIds.recents,
        WorkspaceHomeSectionIds.folioCloud,
      ]);

      final store = await ConfigStore.open();
      await ConfigBootstrap.migrateLegacyAppSettings(appSettings, store);

      final layout = await store.loadLayout(ConfigBootstrap.activeLayoutId);
      expect(layout, isNotNull);
      expect(layout!.panels[PanelRegionIds.sidebarLeft]!.width, 340);

      final theme = await store.loadTheme(ConfigBootstrap.activeThemeId);
      expect(theme, isNotNull);
      expect(theme!.light.seedArgb, 0xFF112233);
      expect(theme.dark.surfaceStyle, 'oled');

      final dashboard = await store.loadDashboard(
        ConfigBootstrap.activeDashboardId,
      );
      expect(dashboard, isNotNull);
      final leftWidgets = dashboard!.widgets
          .where((w) => w.regionId == DashboardRegionIds.left)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      // El reloj se siembra siempre primero en la migración (bug real
      // reportado: antes era chrome fijo de la cabecera, imposible de
      // quitar — ahora es un widget del catálogo más, removible).
      expect(leftWidgets.first.pluginId, 'clock');
      expect(leftWidgets[1].pluginId, WorkspaceHomeSectionIds.recents);
      expect(leftWidgets[2].pluginId, WorkspaceHomeSectionIds.folioCloud);
      expect(leftWidgets[2].visible, isFalse); // showFolioCloudCard = false

      // Fase 28: la migración también siembra un WorkspaceConfig, con los
      // mismos defaults sensatos que el resto (sin señal legacy fiable que
      // traducir para focus mode/paneles abiertos).
      final workspaceState = await store.loadWorkspaceState();
      expect(workspaceState, isNotNull);
      expect(workspaceState!.activeDashboardId, ConfigBootstrap.activeDashboardId);
      expect(workspaceState.focusMode, isFalse);
      expect(workspaceState.aiPanelOpen, isFalse);
    },
  );

  test('does not overwrite personalization made after the first migration', () async {
    final appSettings = AppSettings();
    await appSettings.load();
    final store = await ConfigStore.open();

    await ConfigBootstrap.migrateLegacyAppSettings(appSettings, store);

    // El usuario personaliza dentro del nuevo sistema...
    final customDashboard = DashboardConfig(
      id: ConfigBootstrap.activeDashboardId,
      name: 'Personalizado',
      columns: 4,
    );
    await store.saveDashboard(customDashboard);

    // ...y luego AppSettings legacy cambia por otra vía (no debería pisar
    // la personalización nueva al re-ejecutar la migración).
    await appSettings.setWorkspaceHomeShowFolioCloudCard(false);
    await ConfigBootstrap.migrateLegacyAppSettings(appSettings, store);

    final dashboard = await store.loadDashboard(
      ConfigBootstrap.activeDashboardId,
    );
    expect(dashboard!.name, 'Personalizado');
    expect(dashboard.columns, 4);
  });
}
