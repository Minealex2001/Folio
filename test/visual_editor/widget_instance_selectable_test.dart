import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/visual_editor/widget_instance_selectable.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;
  late DashboardGridController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_widget_selectable_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
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
          ),
        ],
      ),
      persistDebounce: const Duration(minutes: 10),
    );
  });

  tearDown(() async {
    controller.dispose();
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('WidgetInstanceSelectable (Fase 31 — typed appearance)', () {
    test('setColorArgb writes to the typed appearance field, not settings', () {
      final selectable = WidgetInstanceSelectable(controller, 'a');
      selectable.setColorArgb(0xFFFF0000);

      final instance = controller.instanceFor('a')!;
      expect(instance.appearance?.backgroundColorArgb, 0xFFFF0000);
      expect(instance.settings.containsKey('colorOverrideArgb'), isFalse);
    });

    test('setOpacity and setCornerRadius round-trip through the getters', () {
      final selectable = WidgetInstanceSelectable(controller, 'a');
      selectable.setOpacity(0.5);
      selectable.setCornerRadius(12);

      expect(selectable.opacity, 0.5);
      expect(selectable.cornerRadius, 12);
    });

    test('setting a value to null clears it from the typed field', () {
      final selectable = WidgetInstanceSelectable(controller, 'a');
      selectable.setColorArgb(0xFFFF0000);
      selectable.setColorArgb(null);

      expect(selectable.colorArgb, isNull);
      expect(controller.instanceFor('a')!.appearance?.backgroundColorArgb, isNull);
    });

    test('setting multiple fields preserves earlier ones (not overwritten '
        'by a fresh WidgetAppearanceConfig each time)', () {
      final selectable = WidgetInstanceSelectable(controller, 'a');
      selectable.setColorArgb(0xFFFF0000);
      selectable.setOpacity(0.7);

      expect(selectable.colorArgb, 0xFFFF0000);
      expect(selectable.opacity, 0.7);
    });

    test('legacy settings-based overrides are still readable (fallback for '
        'instances saved before Fase 31)', () {
      controller.setInstanceSettings('a', {
        'colorOverrideArgb': 0xFF00FF00,
        'opacityOverride': 0.3,
        'cornerRadiusOverride': 8.0,
      });
      final selectable = WidgetInstanceSelectable(controller, 'a');

      expect(selectable.colorArgb, 0xFF00FF00);
      expect(selectable.opacity, 0.3);
      expect(selectable.cornerRadius, 8.0);
    });

    test('the typed appearance field takes precedence over legacy settings '
        'when both are present', () {
      controller.setInstanceSettings('a', {'colorOverrideArgb': 0xFF00FF00});
      final selectable = WidgetInstanceSelectable(controller, 'a');
      selectable.setColorArgb(0xFFFF0000);

      expect(selectable.colorArgb, 0xFFFF0000);
    });
  });
}
