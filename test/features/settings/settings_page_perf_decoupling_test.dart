// Fase 4 · Paso 1 — Cambio 1 (desacoplar Settings de VaultSession/AppSettings)
// + Cambio 2 (cachear el uso de disco).
//
// Demuestra:
//  1. `VaultSession.notifyListeners()` NO re-ejecuta `_SettingsPageState.build()`.
//  2. `AppSettings.notifyListeners()` NO re-ejecuta `_SettingsPageState.build()`
//     (appbar/rail/chrome); solo repinta el contenido — comportamiento
//     deliberadamente conservado este paso.
//  3. El `Future` de uso de disco se crea una vez y se reutiliza en cada
//     rebuild normal (no se recorre `repo/` + `versions/` de nuevo).
//  4. Cambiar la libreta activa invalida el cache (nuevo Future).
//  5. Un refresh explícito crea un Future nuevo.
//  6. Settings renderiza en signed-out (desktop + móvil) sin excepciones.
//  7. Las secciones Cloud y Vault/Backup siguen renderizando sus datos.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const packageInfoChannel =
      MethodChannel('dev.fluttercommunity.plus/package_info');

  late VaultSession session;
  late AppSettings appSettings;
  late Directory supportDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDir = Directory.systemTemp.createTempSync('folio_settings_perf_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => supportDir.path,
    );
    messenger.setMockMethodCallHandler(packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'Folio',
          'packageName': 'com.folio.test',
          'version': '9.9.9',
          'buildNumber': '999',
        };
      }
      return null;
    });
    VaultPaths.setActiveVaultId('perf-decouple-vault');
    await VaultPaths.initVaultStorage('perf-decouple-vault');
    SettingsPage.debugBuildCount = 0;
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
    messenger.setMockMethodCallHandler(packageInfoChannel, null);
    VaultPaths.clearActiveVaultId();
    try {
      supportDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<SettingsPage> buildPage({String? initialSection}) async {
    appSettings = AppSettings();
    session = VaultSession();
    final configStore = await ConfigStore.open();
    return SettingsPage(
      session: session,
      appSettings: appSettings,
      layoutEngineController: LayoutEngineController(
        configStore,
        initialConfig: LayoutConfig.defaultConfig(),
      ),
      themeConfigController: ThemeConfigController(
        configStore,
        initialConfig: kFolioDefaultTheme,
      ),
      dashboardGridController: DashboardGridController(
        configStore,
        initialConfig: DashboardConfig(id: 'active', name: 'Inicio'),
      ),
      activePackController: ActivePackController(configStore),
      deviceSyncController: DeviceSyncController(appSettings: appSettings),
      cloudAccountController: CloudAccountController(),
      folioCloudEntitlements: FolioCloudEntitlementsController(),
      initialSection: initialSection,
    );
  }

  Future<void> pumpSettings(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    String? initialSection,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: await buildPage(initialSection: initialSection),
      ),
    );
    await tester.pumpAndSettle();
  }

  dynamic settingsState(WidgetTester tester) =>
      tester.state(find.byType(SettingsPage));

  testWidgets('1 · VaultSession.notifyListeners no re-ejecuta build()',
      (tester) async {
    await pumpSettings(tester, initialSection: 'vault');
    expect(SettingsPage.debugBuildCount, greaterThanOrEqualTo(2),
        reason: 'sanity: el build pesado se ejecutó al menos una vez');

    final buildsBefore = SettingsPage.debugBuildCount;
    final futRefBefore = settingsState(tester).debugDiskUsageFutureRef;

    for (var i = 0; i < 5; i++) {
      session.notifyListeners();
      await tester.pump();
    }

    expect(SettingsPage.debugBuildCount, buildsBefore,
        reason: 'un notify de sesión NO re-ejecuta _SettingsPageState.build()');
    expect(identical(settingsState(tester).debugDiskUsageFutureRef, futRefBefore),
        isTrue,
        reason: 'y por tanto NO recrea el Future de uso de disco');
    expect(tester.takeException(), isNull);
  });

  testWidgets('2 · AppSettings.notifyListeners no re-ejecuta build() (chrome)',
      (tester) async {
    await pumpSettings(tester);
    expect(SettingsPage.debugBuildCount, greaterThanOrEqualTo(2));
    final buildsBefore = SettingsPage.debugBuildCount;

    for (var i = 0; i < 5; i++) {
      appSettings.notifyListeners();
      await tester.pump();
    }

    expect(SettingsPage.debugBuildCount, buildsBefore,
        reason: 'AppSettings solo repinta el contenido (AnimatedBuilder); '
            'appbar/rail/PopScope (construidos en build()) no se rehacen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('3 · el Future de uso de disco se reutiliza en rebuilds normales',
      (tester) async {
    await pumpSettings(tester, initialSection: 'vault');
    final futRef = settingsState(tester).debugDiskUsageFutureRef;
    expect(futRef, isNotNull, reason: 'se creó una vez al abrir Settings');

    session.notifyListeners();
    await tester.pump();
    appSettings.notifyListeners();
    await tester.pump();
    tester.view.physicalSize = const Size(1360, 900);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(identical(settingsState(tester).debugDiskUsageFutureRef, futRef),
        isTrue,
        reason: 'ningún rebuild normal recrea el Future (ni recorre el FS)');
  });

  testWidgets('4 · cambiar de libreta invalida el cache', (tester) async {
    await pumpSettings(tester, initialSection: 'vault');
    final futRef = settingsState(tester).debugDiskUsageFutureRef;
    expect(futRef, isNotNull);

    VaultPaths.setActiveVaultId('perf-decouple-vault-OTHER');
    appSettings.notifyListeners(); // rebuild del contenido
    await tester.pumpAndSettle();

    expect(identical(settingsState(tester).debugDiskUsageFutureRef, futRef),
        isFalse,
        reason: 'nueva libreta activa -> nuevo Future');
  });

  testWidgets('5 · refresh explícito recrea el Future', (tester) async {
    await pumpSettings(tester, initialSection: 'vault');
    final futRef = settingsState(tester).debugDiskUsageFutureRef;
    expect(futRef, isNotNull);

    settingsState(tester).debugRefreshDiskUsage();
    await tester.pumpAndSettle();

    expect(identical(settingsState(tester).debugDiskUsageFutureRef, futRef),
        isFalse,
        reason: 'refresh explícito -> nuevo Future (recalcula el walk)');
  });

  testWidgets('6 · renderiza en signed-out (desktop y móvil) sin excepciones',
      (tester) async {
    await pumpSettings(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpSettings(tester, size: const Size(390, 844));
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('7 · las secciones Cloud y Vault/Backup siguen renderizando',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));

    await pumpSettings(tester); // Cloud por defecto en escritorio
    expect(SettingsPage.debugBuildCount, greaterThanOrEqualTo(2));
    expect(find.textContaining('Cloud'), findsWidgets,
        reason: 'la sección Cloud renderiza su contenido (independiente de locale)');
    expect(tester.takeException(), isNull);

    await pumpSettings(tester, initialSection: 'vault');
    expect(SettingsPage.debugBuildCount, greaterThanOrEqualTo(2));
    expect(find.text(l10n.settingsSectionVault), findsWidgets,
        reason: 'la sección Vault/Backup renderiza (hero + rail)');
    expect(settingsState(tester).debugDiskUsageFutureRef, isNotNull,
        reason: 'la sección Vault disparó el cálculo de uso de disco (cacheado)');
    expect(tester.takeException(), isNull);
  });

  // ----- Cambio 3: coalescencia de cargas diferidas -----

  testWidgets(
      '8 · entrada a Settings: pocos builds + ventana de coalescencia cerrada',
      (tester) async {
    await pumpSettings(tester, initialSection: 'vault');

    // La ventana de coalescencia se abre en _runDeferredInitIfNeeded y se
    // cierra cuando el grupo local rápido resuelve.
    expect(settingsState(tester).debugCoalescingRebuilds, isFalse,
        reason: 'la ventana de coalescencia se cierra al terminar la entrada');

    // La entrada completa (frame ligero + pesado + flush consolidado + cargas
    // lentas) se mantiene en pocos builds del State.
    expect(SettingsPage.debugBuildCount, lessThanOrEqualTo(8),
        reason: 'entrar en Settings genera pocos rebuilds de _SettingsPageState');
    expect(tester.takeException(), isNull);
  });

  testWidgets('9 · las cargas diferidas completan su estado correctamente',
      (tester) async {
    await pumpSettings(tester, initialSection: 'about');

    final st = settingsState(tester);
    // _loadInstalledVersionInfo (grupo local coalescido) aplicó su estado.
    expect(st.debugInstalledVersionLabel, isNot('...'),
        reason: 'la carga diferida de versión completó y aplicó su estado');
    // _ensureDiskUsageFuture (Cambio 2) también.
    expect(st.debugDiskUsageFutureRef, isNotNull);
    expect(tester.takeException(), isNull);
  });

  // ----- Cambio 4: construcción perezosa de secciones -----

  testWidgets('10 · una sección no activa NO se construye', (tester) async {
    await pumpSettings(tester, initialSection: 'cloud');

    expect(find.byIcon(Icons.cloud_circle_outlined), findsWidgets,
        reason: 'la sección activa (Cloud) SÍ se construye');
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing,
        reason: 'la sección Vault (no activa) NO se instancia');
    expect(tester.takeException(), isNull);
  });

  testWidgets('11 · cambiar de sección construye la nueva y descarta la anterior',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    await pumpSettings(tester, initialSection: 'cloud');
    expect(find.byIcon(Icons.cloud_circle_outlined), findsWidgets);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);

    // En 'cloud', "Libreta" solo aparece en el rail -> finder único.
    await tester.tap(find.text(l10n.settingsSectionVault));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_book_outlined), findsWidgets,
        reason: 'la nueva sección (Vault) se construye al seleccionarla');
    expect(find.byIcon(Icons.cloud_circle_outlined), findsNothing,
        reason: 'la sección anterior (Cloud) se descarta');
    expect(settingsState(tester).debugDiskUsageFutureRef, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
