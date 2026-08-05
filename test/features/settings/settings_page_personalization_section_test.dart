import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/features/settings/settings_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/services/cloud_account/cloud_account_controller.dart';
import 'package:folio/services/device_sync/device_sync_controller.dart';
import 'package:folio/services/folio_cloud/folio_cloud_entitlements.dart';
import 'package:folio/session/vault_session.dart';
import 'package:folio/theme_engine/theme_config_controller.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';
import 'package:folio/visual_packs/active_pack_controller.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  late Directory tempDir;
  late LayoutEngineController layoutEngineController;
  late ThemeConfigController themeConfigController;
  late DashboardGridController dashboardGridController;
  late ActivePackController activePackController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'folio_settings_personalization_test',
    );
    ConfigStoreBackend.debugRootOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
    VaultPaths.setActiveVaultId('personalization-section-test-vault');
    final store = await ConfigStore.open();
    layoutEngineController = LayoutEngineController(
      store,
      initialConfig: LayoutConfig.defaultConfig(),
      persistDebounce: const Duration(minutes: 10),
    );
    themeConfigController = ThemeConfigController(
      store,
      initialConfig: kFolioDefaultTheme,
      persistDebounce: const Duration(minutes: 10),
    );
    dashboardGridController = DashboardGridController(
      store,
      initialConfig: DashboardConfig(id: 'active', name: 'Inicio'),
      persistDebounce: const Duration(minutes: 10),
    );
    activePackController = ActivePackController(store);
  });

  tearDown(() async {
    layoutEngineController.dispose();
    themeConfigController.dispose();
    dashboardGridController.dispose();
    ConfigStoreBackend.debugRootOverride = null;
    VaultPaths.clearActiveVaultId();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appSettings = AppSettings();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(
          session: VaultSession(),
          appSettings: appSettings,
          layoutEngineController: layoutEngineController,
          themeConfigController: themeConfigController,
          dashboardGridController: dashboardGridController,
          activePackController: activePackController,
          deviceSyncController: DeviceSyncController(appSettings: appSettings),
          cloudAccountController: CloudAccountController(),
          folioCloudEntitlements: FolioCloudEntitlementsController(),
          initialSection: 'personalization',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the personalization section with the live sidebar '
      'width from the real LayoutEngineController', (tester) async {
    await pumpSettings(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Personalización (beta)'), findsWidgets);

    final width = layoutEngineController
        .panelFor(PanelRegionIds.sidebarLeft)!
        .width!
        .toStringAsFixed(0);
    expect(find.textContaining('Ancho actual: $width px'), findsOneWidget);
  });

  testWidgets('locking the sidebar via the switch updates the real '
      'LayoutEngineController', (tester) async {
    await pumpSettings(tester);

    expect(
      layoutEngineController.panelFor(PanelRegionIds.sidebarLeft)!.locked,
      isFalse,
    );

    await tester.tap(find.text('Bloquear panel lateral'));
    await tester.pumpAndSettle();

    expect(
      layoutEngineController.panelFor(PanelRegionIds.sidebarLeft)!.locked,
      isTrue,
    );
    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('resetting the layout restores the default sidebar width', (
    tester,
  ) async {
    layoutEngineController.setSize(PanelRegionIds.sidebarLeft, width: 999);
    await pumpSettings(tester);

    expect(
      layoutEngineController.panelFor(PanelRegionIds.sidebarLeft)!.width,
      999,
    );

    await tester.tap(find.text('Restablecer layout de paneles'));
    await tester.pumpAndSettle();

    final defaultWidth = LayoutConfig.defaultConfig()
        .panels[PanelRegionIds.sidebarLeft]!
        .width;
    expect(
      layoutEngineController.panelFor(PanelRegionIds.sidebarLeft)!.width,
      defaultWidth,
    );
    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('dragging the corner-roundness slider updates the real '
      'ThemeConfigController', (tester) async {
    await pumpSettings(tester);

    expect(
      themeConfigController.config.shape.radiusMd,
      kFolioDefaultTheme.shape.radiusMd,
    );

    // Los 4 sliders del editor de tema, en orden: redondez, densidad,
    // velocidad, opacidad. Invocar onChanged directo evita la fragilidad de
    // simular una posición de drag exacta sobre el widget.
    final cornerSlider = tester.widget<Slider>(find.byType(Slider).first);
    cornerSlider.onChanged!(2.0);
    await tester.pump();

    expect(
      themeConfigController.config.shape.radiusMd,
      kFolioDefaultTheme.shape.radiusMd * 2,
    );
    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('the "Restablecer tema" button resets the real '
      'ThemeConfigController to defaults', (tester) async {
    themeConfigController.setSurfaceOpacity(0.6);
    await pumpSettings(tester);

    expect(themeConfigController.config.surfaceOpacity, 0.6);

    await tester.ensureVisible(find.text('Restablecer tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restablecer tema'));
    await tester.pumpAndSettle();

    expect(
      themeConfigController.config.surfaceOpacity,
      kFolioDefaultTheme.surfaceOpacity,
    );
    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets(
    'tapping "Aplicar" on the Obsidian pack card applies its real theme/'
    'layout/dashboard to the live controllers and marks it active',
    (tester) async {
      await pumpSettings(tester);

      final activeThemeId = themeConfigController.config.id;
      expect(find.text('Obsidian'), findsOneWidget);
      final obsidianCard = find
          .ancestor(of: find.text('Obsidian'), matching: find.byType(Container))
          .first;
      final applyButton = find.descendant(
        of: obsidianCard,
        matching: find.widgetWithText(FilledButton, 'Aplicar'),
      );
      expect(applyButton, findsOneWidget);

      await tester.ensureVisible(applyButton);
      await tester.pumpAndSettle();
      await tester.tap(applyButton);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Tema, layout y dashboard reales cambiaron de golpe — no una preview.
      expect(themeConfigController.config.id, activeThemeId);
      expect(themeConfigController.config.light.seedArgb, 0xFF7C5CFF);
      expect(
        layoutEngineController.panelFor(PanelRegionIds.sidebarLeft)!.locked,
        isTrue,
      );
      expect(find.text('Activo'), findsOneWidget);

      await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
    },
  );
}
