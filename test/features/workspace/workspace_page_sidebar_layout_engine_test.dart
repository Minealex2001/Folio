/// Verifica la conexión hecha en Fase "conectar todo": el ancho efectivo
/// del sidebar en WorkspacePage ahora se lee del LayoutEngineController real
/// (no solo un dual-write espejo), y el widget se reconstruye cuando el
/// controller cambia por una vía externa a AppSettings (ej. el botón
/// "Restablecer layout" en Settings). No existía cobertura de widget-test
/// alguna para WorkspacePage antes de este archivo — es, junto con
/// settings_page.dart, de los archivos más grandes/riesgosos del repo.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/features/workspace/shell/workspace_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/services/cloud_account/cloud_account_controller.dart';
import 'package:folio/services/device_sync/device_sync_controller.dart';
import 'package:folio/services/folio_cloud/folio_cloud_entitlements.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;
  late Directory configTempDir;
  late VaultSession session;
  late AppSettings appSettings;
  late LayoutEngineController layoutEngineController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('folio_workspace_page_test_');
    configTempDir = await Directory.systemTemp.createTemp(
      'folio_workspace_page_config_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempDir.path;
        });
    ConfigStoreBackend.debugRootOverride = configTempDir;

    const vaultId = 'workspace-page-sidebar-test-vault';
    VaultPaths.setActiveVaultId(vaultId);
    await VaultPaths.initVaultStorage(vaultId);

    session = VaultSession();
    session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
    session.addPage(parentId: null);

    appSettings = AppSettings();
    await appSettings.load();

    final store = await ConfigStore.open();
    layoutEngineController = LayoutEngineController(
      store,
      initialConfig: LayoutConfig.defaultConfig(),
      persistDebounce: const Duration(minutes: 10),
    );
    appSettings.onWorkspaceSidebarWidthChanged = (width) {
      layoutEngineController.setSize(PanelRegionIds.sidebarLeft, width: width);
    };
  });

  tearDown(() async {
    layoutEngineController.dispose();
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
          deviceSyncController: DeviceSyncController(appSettings: appSettings),
          cloudAccountController: CloudAccountController(),
          folioCloudEntitlements: FolioCloudEntitlementsController(),
          onOpenSearch: ([q]) {},
          onOpenReleaseNotes: (context) async {},
        ),
      ),
    );
    // Un pump acotado (no pumpAndSettle): el workspace desencadena timers/
    // streams de fondo (auto-guardado, recordatorios) que nunca "settlean".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('renders without throwing with a real LayoutEngineController',
      (tester) async {
    await pumpWorkspace(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(WorkspacePage), findsOneWidget);
  });

  testWidgets(
    'rebuilds when the LayoutEngineController changes from outside '
    'AppSettings (e.g. the Settings "reset layout" button)',
    (tester) async {
      await pumpWorkspace(tester);
      expect(tester.takeException(), isNull);

      // Cambia el ancho directamente en el controller, sin pasar por
      // AppSettings.setWorkspaceSidebarWidth — simula la vía real por la
      // que Settings -> Personalización dispara el reset.
      layoutEngineController.setSize(PanelRegionIds.sidebarLeft, width: 401);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        layoutEngineController.panelFor(PanelRegionIds.sidebarLeft)!.width,
        401,
      );
      await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
    },
  );
}
