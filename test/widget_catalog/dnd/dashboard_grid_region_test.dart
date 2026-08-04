import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_region.dart';
import 'package:folio/widget_catalog/folio_widget_plugin.dart';
import 'package:folio/widget_catalog/widget_catalog_registry.dart';
import 'package:folio/widget_catalog/widget_plugin_context.dart';
import 'package:folio/session/vault_session.dart';

class _LabelPlugin extends FolioWidgetPlugin {
  const _LabelPlugin(this.id);

  @override
  final String id;

  @override
  String displayName(BuildContext context) => id;

  @override
  IconData get icon => Icons.widgets;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) => Text('plugin:$id:${instance.instanceId}');
}

void main() {
  late Directory tempDir;
  late ConfigStore store;
  late DashboardGridController controller;
  late WidgetCatalogRegistry registry;
  late WidgetPluginContext pluginContext;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_grid_region_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
    registry = WidgetCatalogRegistry.instance..debugClear();
    registry.register(const _LabelPlugin('clock'));
    pluginContext = WidgetPluginContext(
      appSettings: AppSettings(),
      configStore: store,
      session: VaultSession(),
    );
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
          WidgetInstanceConfig(
            instanceId: 'b',
            pluginId: 'clock',
            regionId: 'right',
            order: 0,
          ),
        ],
      ),
      persistDebounce: const Duration(minutes: 10),
    );
  });

  tearDown(() async {
    controller.dispose();
    registry.debugClear();
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(height: 600, child: child)),
  );

  testWidgets('renders one widget per column via the registered plugin', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        DashboardGridRegion(
          controller: controller,
          pluginContext: pluginContext,
          registry: registry,
          columnRegionIds: const ['left', 'right'],
        ),
      ),
    );

    expect(find.text('plugin:clock:a'), findsOneWidget);
    expect(find.text('plugin:clock:b'), findsOneWidget);
  });

  testWidgets('an instance whose plugin is unregistered renders nothing '
      'without throwing', (tester) async {
    controller.dispose();
    controller = DashboardGridController(
      store,
      initialConfig: DashboardConfig(
        id: 'test',
        name: 'Test',
        widgets: [
          WidgetInstanceConfig(
            instanceId: 'a',
            pluginId: 'does_not_exist',
            regionId: 'left',
            order: 0,
          ),
        ],
      ),
      persistDebounce: const Duration(minutes: 10),
    );

    await tester.pumpWidget(
      wrap(
        DashboardGridRegion(
          controller: controller,
          pluginContext: pluginContext,
          registry: registry,
          columnRegionIds: const ['left'],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('an invisible instance is not rendered', (tester) async {
    controller.setInstanceVisible('a', false);
    await tester.pumpWidget(
      wrap(
        DashboardGridRegion(
          controller: controller,
          pluginContext: pluginContext,
          registry: registry,
          columnRegionIds: const ['left', 'right'],
        ),
      ),
    );

    expect(find.text('plugin:clock:a'), findsNothing);
    expect(find.text('plugin:clock:b'), findsOneWidget);

    // Deja que el debounce de persistencia termine antes de que el test
    // finalice (flutter_test falla si queda un Timer pendiente).
    await tester.pump(const Duration(minutes: 11));
  });

  testWidgets('dragging an instance to the other column DragTarget moves '
      'it there', (tester) async {
    await tester.pumpWidget(
      wrap(
        DashboardGridRegion(
          controller: controller,
          pluginContext: pluginContext,
          registry: registry,
          columnRegionIds: const ['left', 'right'],
        ),
      ),
    );

    expect(controller.instanceFor('a')!.regionId, 'left');

    final dragSource = find.text('plugin:clock:a');
    final dropTarget = find.text('plugin:clock:b');

    final gesture = await tester.startGesture(tester.getCenter(dragSource));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(dropTarget));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.instanceFor('a')!.regionId, 'right');

    // Deja que el debounce de persistencia termine antes de que el test
    // finalice (flutter_test falla si queda un Timer pendiente).
    await tester.pump(const Duration(minutes: 11));
  });
}
