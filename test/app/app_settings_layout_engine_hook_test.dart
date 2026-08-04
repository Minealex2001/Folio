import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_bootstrap.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'folio_app_settings_layout_hook_test',
    );
    ConfigStoreBackend.debugRootOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
    'setWorkspaceSidebarWidth keeps the LayoutEngineController in sync when '
    'the hook is registered (bootstrap wiring in main.dart)',
    () async {
      final appSettings = AppSettings();
      await appSettings.load();

      final store = await ConfigStore.open();
      final controller = await LayoutEngineController.load(
        store,
        id: ConfigBootstrap.activeLayoutId,
      );
      appSettings.onWorkspaceSidebarWidthChanged = (width) {
        controller.setSize(PanelRegionIds.sidebarLeft, width: width);
      };

      await appSettings.setWorkspaceSidebarWidth(410);

      expect(appSettings.workspaceSidebarWidth, 410);
      expect(
        controller.panelFor(PanelRegionIds.sidebarLeft)!.width,
        410,
      );
    },
  );

  test('without the hook registered, setWorkspaceSidebarWidth behaves '
      'exactly as before (no crash, no dependency on ConfigStore)', () async {
    final appSettings = AppSettings();
    await appSettings.load();

    await appSettings.setWorkspaceSidebarWidth(300);

    expect(appSettings.workspaceSidebarWidth, 300);
  });
}
