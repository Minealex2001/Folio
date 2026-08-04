import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_bootstrap.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'folio_app_settings_dashboard_hook_test',
    );
    ConfigStoreBackend.debugRootOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> wireHook(AppSettings appSettings, ConfigStore store) async {
    appSettings.onWorkspaceHomeDashboardChanged = () {
      unawaited(
        store.saveDashboard(
          ConfigBootstrap.dashboardConfigFromAppSettings(appSettings),
        ),
      );
    };
  }

  /// El hook dispara un save fire-and-forget; sondea en vez de un delay fijo
  /// para no ser frágil ante I/O lento/transitorio.
  Future<DashboardConfig> waitForDashboard(ConfigStore store) async {
    for (var i = 0; i < 20; i++) {
      final dashboard = await store.loadDashboard(
        ConfigBootstrap.activeDashboardId,
      );
      if (dashboard != null) return dashboard;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    fail('DashboardConfig was not persisted within the expected time');
  }

  test('toggling a section visibility re-derives and persists the '
      'DashboardConfig', () async {
    final appSettings = AppSettings();
    await appSettings.load();
    final store = await ConfigStore.open();
    await wireHook(appSettings, store);

    await appSettings.setWorkspaceHomeShowTasksSection(false);
    final dashboard = await waitForDashboard(store);
    final tasksWidget = dashboard.widgets.firstWhere(
      (w) => w.pluginId == WorkspaceHomeSectionIds.tasks,
    );
    expect(tasksWidget.visible, isFalse);
  });

  test('reordering the left section list is reflected in the persisted '
      'DashboardConfig order', () async {
    final appSettings = AppSettings();
    await appSettings.load();
    final store = await ConfigStore.open();
    await wireHook(appSettings, store);

    final reordered = [
      WorkspaceHomeSectionIds.recents,
      WorkspaceHomeSectionIds.folioCloud,
      WorkspaceHomeSectionIds.vaultStatus,
      WorkspaceHomeSectionIds.onboarding,
      WorkspaceHomeSectionIds.whatsNew,
      WorkspaceHomeSectionIds.search,
      WorkspaceHomeSectionIds.rootPages,
      WorkspaceHomeSectionIds.miniStats,
    ];
    await appSettings.setWorkspaceHomeLeftSectionOrder(reordered);
    final dashboard = await waitForDashboard(store);
    final left =
        dashboard.widgets.where((w) => w.regionId == DashboardRegionIds.left).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    expect(left.first.pluginId, WorkspaceHomeSectionIds.recents);
  });

  test('changing the column layout updates DashboardConfig.columns',
      () async {
    final appSettings = AppSettings();
    await appSettings.load();
    final store = await ConfigStore.open();
    await wireHook(appSettings, store);

    await appSettings.setWorkspaceHomeColumnLayout(
      WorkspaceHomeColumnLayout.single,
    );
    final dashboard = await waitForDashboard(store);
    expect(dashboard.columns, 1);
  });

  test('without the hook registered, dashboard setters behave exactly as '
      'before (no crash, no ConfigStore dependency)', () async {
    final appSettings = AppSettings();
    await appSettings.load();

    await appSettings.setWorkspaceHomeShowTip(false);

    expect(appSettings.workspaceHomeShowTip, isFalse);
  });
}
