import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
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

  testWidgets(
    'on desktop, dragging an instance moves it WITHOUT waiting for the '
    'long-press timeout — bug real reportado: en desktop el arrastre no '
    'parecía funcionar porque LongPressDraggable exige mantener pulsado '
    '~500ms, algo que un click-and-drag de ratón normal nunca dispara',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

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
      // Deliberadamente SIN el pump de kLongPressTimeout del test anterior
      // — un click-and-drag de escritorio real nunca espera ese tiempo.
      await gesture.moveTo(tester.getCenter(dropTarget));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.instanceFor('a')!.regionId, 'right');

      await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'color/opacity/corner-radius overrides written by the visual editor '
    'inspector (WidgetInstanceConfig.settings) are actually rendered — bug '
    'real reportado: el inspector guardaba los valores pero nada los leía '
    'de vuelta, así que editarlos no cambiaba nada visible',
    (tester) async {
      controller.setInstanceSettings('a', {
        'colorOverrideArgb': 0xFFFF0000,
        'opacityOverride': 0.4,
        'cornerRadiusOverride': 20.0,
      });

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

      final opacityWidget = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('plugin:clock:a'),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(opacityWidget.opacity, 0.4);

      expect(
        find.ancestor(
          of: find.text('plugin:clock:a'),
          matching: find.byType(ClipRRect),
        ),
        findsWidgets,
      );

      final coloredContainer = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('plugin:clock:a'),
              matching: find.byType(Container),
            ),
          )
          .where((c) => (c.decoration as BoxDecoration?)?.color == const Color(0xFFFF0000));
      expect(coloredContainer, isNotEmpty);

      await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
    },
  );

  testWidgets(
    'the "Añadir widget" button lists catalog plugins and adds the chosen '
    'one to the first column — bug real reportado: el editor de dashboard '
    'no tenía forma de añadir un widget nuevo',
    (tester) async {
      registry.register(const _LabelPlugin('weather'));

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

      final before = controller.config.widgets.length;

      await tester.tap(find.text('Añadir widget'));
      await tester.pumpAndSettle();

      // El diálogo lista ambos plugins registrados (clock ya está en el
      // dashboard pero allowMultipleInstances es true por defecto).
      expect(find.text('weather'), findsOneWidget);
      await tester.tap(find.text('weather'));
      await tester.pumpAndSettle();

      expect(controller.config.widgets.length, before + 1);
      final added = controller.config.widgets.last;
      expect(added.pluginId, 'weather');
      expect(added.regionId, 'left'); // primera columna por defecto

      await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
    },
  );

  testWidgets(
    'a plugin with allowMultipleInstances=false already placed is hidden '
    'from the "Añadir widget" picker',
    (tester) async {
      registry.register(const _SingleInstancePlugin('search'));
      controller.addInstance('search', 'left');

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

      await tester.tap(find.text('Añadir widget'));
      await tester.pumpAndSettle();

      // 'search' ya está colocado y no admite duplicados — no debe listarse
      // de nuevo, pero 'clock' (allowMultipleInstances: true) sí.
      expect(find.text('search'), findsNothing);
      expect(find.text('clock'), findsOneWidget);

      await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
    },
  );
}

class _SingleInstancePlugin extends FolioWidgetPlugin {
  const _SingleInstancePlugin(this.id);

  @override
  final String id;

  @override
  String displayName(BuildContext context) => id;

  @override
  IconData get icon => Icons.search_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) => Text('plugin:$id:${instance.instanceId}');
}
