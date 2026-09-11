import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/layout_engine/panel_host.dart';
import 'package:folio/visual_editor/inspector/property_inspector_panel.dart';
import 'package:folio/visual_editor/panel_selectable.dart';
import 'package:folio/visual_editor/visual_editor_controller.dart';
import 'package:folio/visual_editor/widget_instance_selectable.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_inspector_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows a placeholder when nothing is selected', (tester) async {
    final visualEditor = VisualEditorController();
    await tester.pumpWidget(
      wrap(PropertyInspectorPanel(controller: visualEditor)),
    );
    expect(find.text('Selecciona un elemento para editarlo'), findsOneWidget);
  });

  testWidgets('editing width for a selected panel updates the '
      'LayoutEngineController', (tester) async {
    final layout = LayoutEngineController(
      store,
      initialConfig: LayoutConfig.defaultConfig(id: 'test'),
      persistDebounce: const Duration(minutes: 10),
    );
    addTearDown(layout.dispose);
    final visualEditor = VisualEditorController()
      ..select(PanelSelectable(layout, PanelRegionIds.sidebarLeft));

    await tester.pumpWidget(
      wrap(
        PropertyInspectorPanel(controller: visualEditor, repaintOn: layout),
      ),
    );

    // No hay sección de color/opacidad/radio para paneles.
    expect(find.text('Color'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Ancho'), '333');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(layout.panelFor(PanelRegionIds.sidebarLeft)!.width, 333);
    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('editing a widget instance shows and updates color/opacity/'
      'corner radius sections', (tester) async {
    final dashboard = DashboardGridController(
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
    addTearDown(dashboard.dispose);
    final visualEditor = VisualEditorController()
      ..select(WidgetInstanceSelectable(dashboard, 'a'));

    await tester.pumpWidget(
      wrap(
        PropertyInspectorPanel(controller: visualEditor, repaintOn: dashboard),
      ),
    );

    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Radio de esquina'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Radio'), '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Fase 31: el inspector escribe al campo tipado `appearance`, no ya a
    // `settings['cornerRadiusOverride']`.
    expect(dashboard.instanceFor('a')!.appearance?.cornerRadius, 10);
    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('mounts as a real PanelHost floatingInspector region '
      '(dogfooding proof — the inspector reuses the general panel system, '
      'not a bespoke floating-panel implementation)', (tester) async {
    final layout = LayoutEngineController(
      store,
      initialConfig: LayoutConfig(
        id: 'test',
        name: 'Test',
        panels: {
          PanelRegionIds.main: PanelConfig(
            regionId: PanelRegionIds.main,
            visible: true,
          ),
          PanelRegionIds.floatingInspector: PanelConfig(
            regionId: PanelRegionIds.floatingInspector,
            visible: true,
            width: 260,
            height: 400,
            floatingX: 20,
            floatingY: 20,
          ),
        },
      ),
      persistDebounce: const Duration(minutes: 10),
    );
    addTearDown(layout.dispose);
    final visualEditor = VisualEditorController();

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 800,
          height: 600,
          child: PanelHost(
            controller: layout,
            regionBuilders: {
              PanelRegionIds.main: (_) => const SizedBox.expand(),
              PanelRegionIds.floatingInspector: (_) =>
                  PropertyInspectorPanel(controller: visualEditor),
            },
          ),
        ),
      ),
    );

    expect(find.text('Selecciona un elemento para editarlo'), findsOneWidget);
  });
}
