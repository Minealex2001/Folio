import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/visual_editor/panel_selectable.dart';
import 'package:folio/visual_editor/selectable.dart';
import 'package:folio/visual_editor/widget_instance_selectable.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_selectable_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('PanelSelectable', () {
    late LayoutEngineController controller;

    setUp(() {
      controller = LayoutEngineController(
        store,
        initialConfig: LayoutConfig.defaultConfig(id: 'test'),
        persistDebounce: const Duration(minutes: 10),
      );
    });

    tearDown(() => controller.dispose());

    test('kind is panel, id is the region id', () {
      final selectable = PanelSelectable(controller, PanelRegionIds.sidebarLeft);
      expect(selectable.kind, SelectableKind.panel);
      expect(selectable.id, PanelRegionIds.sidebarLeft);
    });

    test('reads width/locked from the underlying panel', () {
      final selectable = PanelSelectable(controller, PanelRegionIds.sidebarLeft);
      expect(selectable.width, controller.panelFor(PanelRegionIds.sidebarLeft)!.width);
      expect(selectable.locked, isFalse);
    });

    test('setSize writes through to the LayoutEngineController', () {
      final selectable = PanelSelectable(controller, PanelRegionIds.sidebarLeft);
      selectable.setSize(width: 333);
      expect(controller.panelFor(PanelRegionIds.sidebarLeft)!.width, 333);
    });

    test('setPosition writes through when both x and y are given', () {
      final selectable = PanelSelectable(controller, PanelRegionIds.floatingAi);
      selectable.setPosition(x: 10, y: 20);
      final panel = controller.panelFor(PanelRegionIds.floatingAi)!;
      expect(panel.floatingX, 10);
      expect(panel.floatingY, 20);
    });

    test('color/opacity/cornerRadius are always null and setters are no-ops', () {
      final selectable = PanelSelectable(controller, PanelRegionIds.sidebarLeft);
      expect(selectable.colorArgb, isNull);
      expect(selectable.opacity, isNull);
      expect(selectable.cornerRadius, isNull);
      // No throw, no observable effect.
      selectable.setColorArgb(0xFFFF0000);
      selectable.setOpacity(0.5);
      selectable.setCornerRadius(8);
    });
  });

  group('WidgetInstanceSelectable', () {
    late DashboardGridController controller;

    setUp(() {
      controller = DashboardGridController(
        store,
        initialConfig: DashboardConfig(
          id: 'test',
          name: 'Test',
          widgets: [
            WidgetInstanceConfig(
              instanceId: 'a',
              pluginId: 'clock',
              regionId: 'left',
              order: 0,
              width: 200,
              height: 100,
            ),
          ],
        ),
        persistDebounce: const Duration(minutes: 10),
      );
    });

    tearDown(() => controller.dispose());

    test('kind is widgetInstance, x/y are always null (v1 grid flow)', () {
      final selectable = WidgetInstanceSelectable(controller, 'a');
      expect(selectable.kind, SelectableKind.widgetInstance);
      expect(selectable.x, isNull);
      expect(selectable.y, isNull);
      expect(selectable.locked, isFalse);
    });

    test('setSize writes through to DashboardGridController.resizeInstance', () {
      final selectable = WidgetInstanceSelectable(controller, 'a');
      selectable.setSize(width: 300, height: 150);
      expect(controller.instanceFor('a')!.width, 300);
      expect(controller.instanceFor('a')!.height, 150);
    });

    test('color/opacity/cornerRadius round-trip through instance settings', () {
      final selectable = WidgetInstanceSelectable(controller, 'a');
      expect(selectable.colorArgb, isNull);

      selectable.setColorArgb(0xFF00FF00);
      expect(selectable.colorArgb, 0xFF00FF00);
      expect(controller.instanceFor('a')!.settings['colorOverrideArgb'], 0xFF00FF00);

      selectable.setOpacity(0.5);
      expect(selectable.opacity, 0.5);

      selectable.setCornerRadius(12);
      expect(selectable.cornerRadius, 12);

      // Clearing removes the key entirely rather than leaving a null.
      selectable.setColorArgb(null);
      expect(selectable.colorArgb, isNull);
      expect(
        controller.instanceFor('a')!.settings.containsKey('colorOverrideArgb'),
        isFalse,
      );
    });

    test('is a no-op for an unknown instance id (no throw)', () {
      final selectable = WidgetInstanceSelectable(controller, 'missing');
      expect(selectable.width, isNull);
      selectable.setSize(width: 100); // no throw
      selectable.setColorArgb(0xFFFFFFFF); // no throw
    });
  });
}
