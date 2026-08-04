import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/layout_engine/drag_resize/resize_handle.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/layout_engine/panel_host.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;
  late LayoutEngineController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_panel_host_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
    controller = LayoutEngineController(
      store,
      initialConfig: LayoutConfig.defaultConfig(id: 'test'),
    );
  });

  tearDown(() async {
    controller.dispose();
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders only visible regions', (tester) async {
    await tester.pumpWidget(
      wrap(
        PanelHost(
          controller: controller,
          regionBuilders: {
            PanelRegionIds.sidebarLeft: (_) => const Text('sidebar'),
            PanelRegionIds.main: (_) => const Text('main'),
            PanelRegionIds.floatingAi: (_) => const Text('ai'),
          },
        ),
      ),
    );

    expect(find.text('sidebar'), findsOneWidget);
    expect(find.text('main'), findsOneWidget);
    // floatingAi es invisible por defecto en LayoutConfig.defaultConfig().
    expect(find.text('ai'), findsNothing);
  });

  testWidgets('toggling visibility mounts/unmounts the region without '
      'throwing', (tester) async {
    await tester.pumpWidget(
      wrap(
        PanelHost(
          controller: controller,
          regionBuilders: {
            PanelRegionIds.sidebarLeft: (_) => const Text('sidebar'),
            PanelRegionIds.main: (_) => const Text('main'),
            PanelRegionIds.floatingAi: (_) => const Text('ai'),
          },
        ),
      ),
    );

    expect(find.text('sidebar'), findsOneWidget);

    controller.setVisible(PanelRegionIds.sidebarLeft, false);
    await tester.pump();
    expect(find.text('sidebar'), findsNothing);

    controller.setVisible(PanelRegionIds.floatingAi, true);
    await tester.pump();
    expect(find.text('ai'), findsOneWidget);

    // Deja que el debounce de persistencia termine antes de que el test
    // finalice (flutter_test falla si queda un Timer pendiente).
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('dragging the sidebar resize handle updates the controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PanelHost(
          controller: controller,
          regionBuilders: {
            PanelRegionIds.sidebarLeft: (_) => const ColoredBox(
              color: Colors.blue,
              child: SizedBox.expand(),
            ),
            PanelRegionIds.main: (_) => const SizedBox.expand(),
          },
        ),
      ),
    );

    final startWidth =
        controller.panelFor(PanelRegionIds.sidebarLeft)!.width!;

    final handle = find.byType(PanelResizeHandle);
    expect(handle, findsOneWidget);
    await tester.drag(handle, const Offset(30, 0));
    await tester.pump();

    final endWidth = controller.panelFor(PanelRegionIds.sidebarLeft)!.width!;
    expect(endWidth, greaterThan(startWidth));

    // Deja que el debounce de persistencia termine antes de que el test
    // finalice (flutter_test falla si queda un Timer pendiente).
    await tester.pump(const Duration(milliseconds: 500));
  });
}
