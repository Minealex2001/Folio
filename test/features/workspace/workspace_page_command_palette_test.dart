/// Fase C3 del rediseño UX del editor — Ctrl+K abre el Command Palette
/// desde el shell real de la app (`WorkspacePage`), no solo desde
/// `BlockEditor` en aislamiento. Antes de esta fase, el Palette existía
/// (Fase C2) pero no había ninguna forma de abrirlo desde la app corriendo
/// — exactamente el hueco que este test cierra.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/command_palette/command_palette_overlay.dart';
import 'package:folio/features/workspace/shell/workspace_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/services/cloud_account/cloud_account_controller.dart';
import 'package:folio/services/device_sync/device_sync_controller.dart';
import 'package:folio/services/folio_cloud/folio_cloud_entitlements.dart';
import 'package:folio/session/vault_session.dart';
import 'package:folio/theme_engine/theme_config_controller.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';
import 'package:folio/visual_packs/active_pack_controller.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;
  late Directory configTempDir;
  late VaultSession session;
  late AppSettings appSettings;
  late LayoutEngineController layoutEngineController;
  late DashboardGridController dashboardGridController;
  late ThemeConfigController themeConfigController;
  late ActivePackController activePackController;
  var searchOpened = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp(
      'folio_workspace_page_palette_test_',
    );
    configTempDir = await Directory.systemTemp.createTemp(
      'folio_workspace_page_palette_config_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempDir.path;
        });
    ConfigStoreBackend.debugRootOverride = configTempDir;

    const vaultId = 'workspace-page-palette-test-vault';
    VaultPaths.setActiveVaultId(vaultId);
    await VaultPaths.initVaultStorage(vaultId);

    session = VaultSession();
    session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
    session.addPage(parentId: null);
    // A diferencia de workspace_page_sidebar_layout_engine_test.dart, aquí
    // se deja la página seleccionada a propósito: hace falta un
    // BlockEditor real montado para que `_blockEditorKeyForPage(...)
    // .currentState` exista.

    appSettings = AppSettings();
    await appSettings.load();

    final store = await ConfigStore.open();
    layoutEngineController = LayoutEngineController(
      store,
      initialConfig: LayoutConfig.defaultConfig(),
      persistDebounce: const Duration(minutes: 10),
    );
    dashboardGridController = DashboardGridController(
      store,
      initialConfig: DashboardConfig(id: 'active', name: 'Inicio'),
      persistDebounce: const Duration(minutes: 10),
    );
    themeConfigController = ThemeConfigController(
      store,
      initialConfig: kFolioDefaultTheme,
      persistDebounce: const Duration(minutes: 10),
    );
    activePackController = ActivePackController(store);
    searchOpened = false;
  });

  tearDown(() async {
    layoutEngineController.dispose();
    dashboardGridController.dispose();
    themeConfigController.dispose();
    ConfigStoreBackend.debugRootOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    VaultPaths.clearActiveVaultId();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    if (configTempDir.existsSync()) await configTempDir.delete(recursive: true);
  });

  Future<void> pumpWorkspace(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WorkspacePage(
          session: session,
          appSettings: appSettings,
          layoutEngineController: layoutEngineController,
          dashboardGridController: dashboardGridController,
          themeConfigController: themeConfigController,
          activePackController: activePackController,
          deviceSyncController: DeviceSyncController(appSettings: appSettings),
          cloudAccountController: CloudAccountController(),
          folioCloudEntitlements: FolioCloudEntitlementsController(),
          onOpenSearch: ([q]) {
            searchOpened = true;
          },
          onOpenReleaseNotes: (context) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Ctrl+K abre el Command Palette con una página abierta', (
    tester,
  ) async {
    await pumpWorkspace(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(BlockEditor), findsOneWidget);
    expect(find.byType(CommandPaletteOverlay), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.byType(CommandPaletteOverlay), findsOneWidget);
    // La búsqueda antigua NO se dispara directamente — ahora es un comando
    // dentro del Palette, no la acción por defecto de Ctrl+K.
    expect(searchOpened, isFalse);

    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets(
    '"Buscar en la libreta" dentro del Palette sigue abriendo la búsqueda',
    (tester) async {
      await pumpWorkspace(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final paletteSearchField = find.descendant(
        of: find.byType(CommandPaletteOverlay),
        matching: find.byType(TextField),
      );
      await tester.enterText(paletteSearchField, 'buscar');
      await tester.pump();

      expect(find.text('Buscar en la libreta'), findsOneWidget);
      await tester.tap(find.text('Buscar en la libreta'));
      await tester.pumpAndSettle();

      expect(searchOpened, isTrue);
      expect(find.byType(CommandPaletteOverlay), findsNothing);

      await tester.pump(const Duration(minutes: 11));
    },
  );

  testWidgets(
    'Fase H1 — el buscador visible del sidebar abre el mismo Command '
    'Palette que Ctrl+K, en vez de la búsqueda antigua directamente '
    '(mismo gesto de "buscar", mismo resultado, sin importar el disparador)',
    (tester) async {
      await pumpWorkspace(tester);
      expect(find.byType(CommandPaletteOverlay), findsNothing);

      await tester.tap(find.byIcon(Icons.search_rounded).first);
      await tester.pump();

      expect(find.byType(CommandPaletteOverlay), findsOneWidget);
      expect(searchOpened, isFalse);

      await tester.pump(const Duration(minutes: 11));
    },
  );

  testWidgets('Ctrl+F sigue abriendo la búsqueda directamente (fallback ya '
      'existente, sin cambios)', (tester) async {
    await pumpWorkspace(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(searchOpened, isTrue);
    expect(find.byType(CommandPaletteOverlay), findsNothing);

    await tester.pump(const Duration(minutes: 11));
  });
}
