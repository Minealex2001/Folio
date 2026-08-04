import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_layout_engine_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  // Debounce largo por defecto para que el Timer de persistencia nunca
  // dispare durante el cuerpo síncrono de un test que no lo está probando
  // explícitamente (evita que el timer sobreviva al tearDown y escriba en
  // un tempDir ya borrado). Los tests que sí verifican el debounce pasan su
  // propia duración corta y la esperan explícitamente.
  LayoutEngineController makeController({Duration? debounce}) {
    return LayoutEngineController(
      store,
      initialConfig: LayoutConfig.defaultConfig(id: 'test'),
      persistDebounce: debounce ?? const Duration(minutes: 10),
    );
  }

  test('setVisible updates in-memory config and notifies listeners', () {
    final controller = makeController();
    var notified = false;
    controller.addListener(() => notified = true);

    expect(controller.panelFor(PanelRegionIds.sidebarLeft)!.visible, isTrue);
    controller.setVisible(PanelRegionIds.sidebarLeft, false);

    expect(controller.panelFor(PanelRegionIds.sidebarLeft)!.visible, isFalse);
    expect(notified, isTrue);
  });

  test('resizeByDelta accumulates width and respects lock', () {
    final controller = makeController();
    final startWidth = controller.panelFor(PanelRegionIds.sidebarLeft)!.width!;

    controller.resizeByDelta(PanelRegionIds.sidebarLeft, 24);
    expect(
      controller.panelFor(PanelRegionIds.sidebarLeft)!.width,
      startWidth + 24,
    );

    controller.setLocked(PanelRegionIds.sidebarLeft, true);
    controller.resizeByDelta(PanelRegionIds.sidebarLeft, 24);
    // Bloqueado: el segundo resize no debe aplicarse.
    expect(
      controller.panelFor(PanelRegionIds.sidebarLeft)!.width,
      startWidth + 24,
    );
  });

  test('listenable(regionId) only fires for its own region', () {
    final controller = makeController();
    var sidebarNotifications = 0;
    var mainNotifications = 0;
    controller.listenable(PanelRegionIds.sidebarLeft).addListener(() {
      sidebarNotifications++;
    });
    controller.listenable(PanelRegionIds.main).addListener(() {
      mainNotifications++;
    });

    controller.resizeByDelta(PanelRegionIds.sidebarLeft, 10);

    expect(sidebarNotifications, 1);
    expect(mainNotifications, 0);
  });

  test('persist is debounced: rapid mutations only write once', () async {
    final controller = makeController(debounce: const Duration(milliseconds: 30));

    controller.resizeByDelta(PanelRegionIds.sidebarLeft, 1);
    controller.resizeByDelta(PanelRegionIds.sidebarLeft, 1);
    controller.resizeByDelta(PanelRegionIds.sidebarLeft, 1);

    // Antes de que venza el debounce, todavía no debería haber nada en disco.
    expect(await store.loadLayout('test'), isNull);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    final saved = await store.loadLayout('test');
    expect(saved, isNotNull);
    final startWidth = LayoutConfig.defaultConfig(
      id: 'test',
    ).panels[PanelRegionIds.sidebarLeft]!.width!;
    expect(saved!.panels[PanelRegionIds.sidebarLeft]!.width, startWidth + 3);
  });

  test('dispose flushes a pending unpersisted change', () async {
    final controller = makeController(debounce: const Duration(seconds: 10));
    controller.resizeByDelta(PanelRegionIds.sidebarLeft, 5);

    expect(await store.loadLayout('test'), isNull);
    controller.dispose();

    // El flush en dispose() es fire-and-forget; darle un tick para completar.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await store.loadLayout('test'), isNotNull);
  });

  test('saveAsPreset persists under a distinct id without touching the '
      'active layout', () async {
    final controller = makeController();
    await controller.saveAsPreset('my-preset', 'Mi Preset');

    final preset = await store.loadLayout('my-preset');
    expect(preset, isNotNull);
    expect(preset!.name, 'Mi Preset');
    expect(await store.loadLayout('test'), isNull);
  });

  test('loadPreset adopts panels but keeps the active layout id', () async {
    final controller = makeController();
    await store.saveLayout(
      LayoutConfig(
        id: 'other-preset',
        name: 'Otro',
        panels: {
          PanelRegionIds.sidebarLeft: PanelConfig(
            regionId: PanelRegionIds.sidebarLeft,
            visible: false,
            width: 999,
          ),
        },
      ),
    );

    await controller.loadPreset('other-preset');

    expect(controller.config.id, 'test'); // conserva la id activa
    expect(controller.panelFor(PanelRegionIds.sidebarLeft)!.width, 999);
    expect(controller.panelFor(PanelRegionIds.sidebarLeft)!.visible, isFalse);
  });

  test('resetToDefault restores default panel values for the same id', () async {
    final controller = makeController();
    controller.setVisible(PanelRegionIds.sidebarLeft, false);
    expect(controller.panelFor(PanelRegionIds.sidebarLeft)!.visible, isFalse);

    await controller.resetToDefault();

    expect(controller.config.id, 'test');
    expect(controller.panelFor(PanelRegionIds.sidebarLeft)!.visible, isTrue);
  });
}
