import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/config/models/panel_config.dart';
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

  testWidgets(
    'applies the responsive override for the current viewport width '
    '(Fase 7)',
    (tester) async {
      final responsiveController = LayoutEngineController(
        store,
        initialConfig: LayoutConfig(
          id: 'responsive-test',
          name: 'Responsive',
          panels: {
            PanelRegionIds.sidebarLeft: PanelConfig(
              regionId: PanelRegionIds.sidebarLeft,
              visible: true,
              width: 280,
            ),
            PanelRegionIds.main: PanelConfig(
              regionId: PanelRegionIds.main,
              visible: true,
            ),
          },
          responsiveOverrides: {
            'mobile': LayoutConfig(
              id: 'responsive-test-mobile',
              name: 'mobile',
              panels: {
                PanelRegionIds.sidebarLeft: PanelConfig(
                  regionId: PanelRegionIds.sidebarLeft,
                  visible: false,
                ),
              },
            ),
          },
        ),
      );
      addTearDown(responsiveController.dispose);

      Widget buildAt(double width) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 600,
            child: PanelHost(
              controller: responsiveController,
              regionBuilders: {
                PanelRegionIds.sidebarLeft: (_) => const Text('sidebar'),
                PanelRegionIds.main: (_) => const Text('main'),
              },
            ),
          ),
        ),
      );

      // Ancho desktop: sin override aplicable, sidebar visible.
      await tester.pumpWidget(buildAt(1000));
      expect(find.text('sidebar'), findsOneWidget);

      // Ancho mobile: el override de la Fase 7 oculta el sidebar.
      await tester.pumpWidget(buildAt(400));
      expect(find.text('sidebar'), findsNothing);
      expect(find.text('main'), findsOneWidget);
    },
  );

  group('band composition (Fase 24)', () {
    testWidgets('with no bands configured, the root widget is the same '
        'Stack as before Fase 24 — no unnecessary Column wrapper', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PanelHost(
            controller: controller,
            regionBuilders: {
              PanelRegionIds.sidebarLeft: (_) => const Text('sidebar'),
              PanelRegionIds.main: (_) => const Text('main'),
            },
          ),
        ),
      );

      // Localiza el PanelHost y confirma que su hijo directo (bajo
      // LayoutBuilder/AnimatedBuilder) sigue siendo un Stack, no un Column.
      expect(find.byType(Column), findsNothing);
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('a configured, visible topBand region renders above the '
        'docked body', (tester) async {
      final bandController = LayoutEngineController(
        store,
        initialConfig: LayoutConfig(
          id: 'band-test',
          name: 'Band test',
          panels: {
            PanelRegionIds.main: PanelConfig(
              regionId: PanelRegionIds.main,
              visible: true,
            ),
            PanelRegionIds.toolbarTop: PanelConfig(
              regionId: PanelRegionIds.toolbarTop,
              visible: true,
              height: 48,
            ),
          },
        ),
      );
      addTearDown(bandController.dispose);

      await tester.pumpWidget(
        wrap(
          PanelHost(
            controller: bandController,
            regionBuilders: {
              PanelRegionIds.main: (_) => const Text('main'),
              PanelRegionIds.toolbarTop: (_) => const Text('toolbar'),
            },
            topBandOrder: const [PanelRegionIds.toolbarTop],
          ),
        ),
      );

      expect(find.text('toolbar'), findsOneWidget);
      expect(find.text('main'), findsOneWidget);
      // El árbol ahora sí envuelve el body en un Column (banda presente).
      expect(find.byType(Column), findsWidgets);

      final toolbarY = tester.getTopLeft(find.text('toolbar')).dy;
      final mainY = tester.getTopLeft(find.text('main')).dy;
      expect(toolbarY, lessThan(mainY));
    });

    testWidgets('an invisible band region does not render, same as any '
        'other invisible panel', (tester) async {
      final bandController = LayoutEngineController(
        store,
        initialConfig: LayoutConfig(
          id: 'band-hidden-test',
          name: 'Band hidden test',
          panels: {
            PanelRegionIds.main: PanelConfig(
              regionId: PanelRegionIds.main,
              visible: true,
            ),
            PanelRegionIds.toolbarBottom: PanelConfig(
              regionId: PanelRegionIds.toolbarBottom,
              visible: false,
              height: 40,
            ),
          },
        ),
      );
      addTearDown(bandController.dispose);

      await tester.pumpWidget(
        wrap(
          PanelHost(
            controller: bandController,
            regionBuilders: {
              PanelRegionIds.main: (_) => const Text('main'),
              PanelRegionIds.toolbarBottom: (_) => const Text('status bar'),
            },
            bottomBandOrder: const [PanelRegionIds.toolbarBottom],
          ),
        ),
      );

      expect(find.text('status bar'), findsNothing);
      expect(find.text('main'), findsOneWidget);
      // Sin ninguna banda visible, no se envuelve en Column.
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('a band region referenced in the order list but missing '
        'from the config panels is skipped without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PanelHost(
            controller: controller,
            regionBuilders: {
              PanelRegionIds.main: (_) => const Text('main'),
            },
            topBandOrder: const [PanelRegionIds.toolbarTop],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('main'), findsOneWidget);
    });
  });
}
