// H2 · Settings → Quill: la carga de `TranscriptionHardwareProfile` ya NO
// bloquea el UI isolate en `build()`.
//
// ANTES: `_buildMeetingNoteSettingsBlock` llamaba
// `TranscriptionHardwareProfile.loadCached()` SÍNCRONO dentro de `build()`; en
// cache miss eso lanza PowerShell con `Process.runSync` (~305 ms medidos en
// dev) → congelón al abrir la sección Quill.
//
// AHORA: la lectura de RAM se hace async (`Process.run`) fuera de `build()`, en
// `_loadHardwareProfile` (grupo de cargas diferidas de la entrada a Settings).
// La sección pinta al instante con un fallback seguro y repinta al resolver.
//
// Mide: cache hit / miss, coste de obtención del perfil, primer build de
// Settings → Quill, y ausencia de lectura SÍNCRONA de RAM durante el build.
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
import 'package:folio/services/transcription_hardware_profile.dart';
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

  const snap16 = TranscriptionHardwareSnapshot(
    logicalCpuCount: 8,
    totalRamBytes: 16 * 1024 * 1024 * 1024,
    recommendedWhisperModelId: 'small',
    isLocalTranscriptionViable: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDir = Directory.systemTemp.createTempSync('folio_settings_h2_');
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
    VaultPaths.setActiveVaultId('h2-vault');
    await VaultPaths.initVaultStorage('h2-vault');
    SettingsPage.debugBuildCount = 0;
    TranscriptionHardwareProfile.debugResetForTests();
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
    messenger.setMockMethodCallHandler(packageInfoChannel, null);
    VaultPaths.clearActiveVaultId();
    TranscriptionHardwareProfile.debugResetForTests();
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
    String? initialSection = 'ai',
    Size size = const Size(1400, 900),
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
  }

  dynamic settingsState(WidgetTester tester) =>
      tester.state(find.byType(SettingsPage));

  // Override determinista para la lectura de RAM async: sin PowerShell real.
  void installOverride({
    Duration delay = const Duration(milliseconds: 40),
    int? ramBytes = 16 * 1024 * 1024 * 1024,
    bool throwErr = false,
  }) {
    TranscriptionHardwareProfile.debugRamReadOverride = () async {
      await Future<void>.delayed(delay);
      if (throwErr) throw StateError('powershell boom');
      return ramBytes;
    };
  }

  testWidgets('no hay lectura SÍNCRONA de RAM durante el build de Quill',
      (tester) async {
    installOverride();
    final swFirst = Stopwatch()..start();
    await pumpSettings(tester);
    await tester.pump(); // primer frame ligero
    swFirst.stop();

    // El build NO ejecutó la ruta síncrona (Process.runSync) ni una vez.
    expect(TranscriptionHardwareProfile.debugSyncRamReadCount, 0,
        reason: 'ningún Process.runSync en el camino de build()');
    // Y el primer build no esperó al perfil: aún no está.
    expect(settingsState(tester).debugHardwareSnapshot, isNull,
        reason: 'el primer build se construyó sin el perfil (estado seguro)');

    await tester.pumpAndSettle();

    // La carga async se disparó y resolvió; sigue sin haber lectura síncrona.
    expect(TranscriptionHardwareProfile.debugAsyncRamReadCount, greaterThan(0));
    expect(TranscriptionHardwareProfile.debugSyncRamReadCount, 0);
    expect(settingsState(tester).debugHardwareSnapshot, isNotNull,
        reason: 'tras resolver, el snapshot real está disponible');
    expect(tester.takeException(), isNull);

    // Referencia informativa del coste del primer build (con override rápido).
    // ignore: avoid_print
    print('H2 · primer build Settings→Quill (CPU, sin bloqueo RAM): '
        '${swFirst.elapsedMilliseconds} ms');
  });

  testWidgets('cache hit: no se relee la RAM (ni sync ni async)',
      (tester) async {
    TranscriptionHardwareProfile.debugSeedCache(snap16);
    installOverride();

    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(TranscriptionHardwareProfile.debugAsyncRamReadCount, 0,
        reason: 'cache válida -> loadCachedAsync devuelve sin leer');
    expect(TranscriptionHardwareProfile.debugSyncRamReadCount, 0);
    expect(settingsState(tester).debugHardwareSnapshot?.totalRamBytes,
        snap16.totalRamBytes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cache miss: exactamente UNA lectura async, sin duplicados',
      (tester) async {
    var overrideCalls = 0;
    TranscriptionHardwareProfile.debugRamReadOverride = () async {
      overrideCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      return 32 * 1024 * 1024 * 1024;
    };

    await pumpSettings(tester);
    // Rebuilds mientras la carga está en curso.
    for (var i = 0; i < 6; i++) {
      appSettings.notifyListeners();
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.pumpAndSettle();

    expect(overrideCalls, 1, reason: 'rebuilds concurrentes NO relanzan la carga');
    expect(TranscriptionHardwareProfile.debugAsyncRamReadCount, 1);
    expect(settingsState(tester).debugHardwareSnapshot?.totalRamBytes,
        32 * 1024 * 1024 * 1024);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallo de PowerShell (null): fallback RAM desconocida, sin crash',
      (tester) async {
    installOverride(ramBytes: null);

    await pumpSettings(tester);
    await tester.pumpAndSettle();

    final st = settingsState(tester);
    expect(st.debugHardwareSnapshot, isNotNull);
    expect(st.debugHardwareSnapshot?.totalRamBytes, isNull,
        reason: 'mismo fallback que antes cuando la lectura de RAM falla');
    expect(tester.takeException(), isNull);
  });

  testWidgets('excepción en la lectura async: capturada, fallback, sin crash',
      (tester) async {
    installOverride(throwErr: true);

    await pumpSettings(tester);
    await tester.pumpAndSettle();

    final st = settingsState(tester);
    expect(st.debugHardwareSnapshot, isNotNull);
    expect(st.debugHardwareSnapshot?.totalRamBytes, isNull);
    expect(TranscriptionHardwareProfile.debugSyncRamReadCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navegar fuera de Settings mientras carga: sin excepción ni fugas',
      (tester) async {
    var overrideCalls = 0;
    TranscriptionHardwareProfile.debugRamReadOverride = () async {
      overrideCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return 16 * 1024 * 1024 * 1024;
    };

    await pumpSettings(tester);
    await tester.pump(const Duration(milliseconds: 10)); // carga en curso

    // Reemplaza toda la app (equivale a salir de Settings): el State se
    // desmonta con la carga aún pendiente.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    // Deja que el override (120 ms) resuelva ya sin árbol montado: el guard
    // `if (!mounted) return` de `_loadHardwareProfile` debe absorberlo.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(overrideCalls, 1);
    expect(tester.takeException(), isNull,
        reason: 'el guard `if (!mounted) return` evita setState tras dispose');
  });

  testWidgets('entrar/salir/entrar mientras carga: no acumula cargas',
      (tester) async {
    installOverride(delay: const Duration(milliseconds: 80));

    await pumpSettings(tester);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 120)); // deja resolver la 1ª
    // Segunda entrada: nuevo State. La cache/in-flight es estática y compartida.
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    // A lo sumo 1 lectura async por ventana de 5 min (in-flight dedup + cache).
    expect(TranscriptionHardwareProfile.debugAsyncRamReadCount,
        lessThanOrEqualTo(1));
    expect(TranscriptionHardwareProfile.debugSyncRamReadCount, 0);
    expect(tester.takeException(), isNull);
  });

  test('coste de obtención del perfil: async vs sync (informativo)', () async {
    // Sin override: usa el mecanismo real. En Windows lanza PowerShell.
    TranscriptionHardwareProfile.debugResetForTests();
    final swAsync = Stopwatch()..start();
    final a = await TranscriptionHardwareProfile.loadCachedAsync();
    swAsync.stop();

    TranscriptionHardwareProfile.debugResetForTests();
    final swSync = Stopwatch()..start();
    final s = TranscriptionHardwareProfile.load();
    swSync.stop();

    // ignore: avoid_print
    print('H2 · obtención perfil — async(Process.run)=${swAsync.elapsedMilliseconds} ms '
        'sync(Process.runSync)=${swSync.elapsedMilliseconds} ms '
        'ram=${a.totalRamBytes} cpus=${a.logicalCpuCount}');

    // Mismo resultado funcional que el camino sync.
    expect(a.logicalCpuCount, s.logicalCpuCount);
    expect(a.totalRamBytes, s.totalRamBytes);
    expect(a.recommendedWhisperModelId, s.recommendedWhisperModelId);
    expect(a.isLocalTranscriptionViable, s.isLocalTranscriptionViable);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('cache hit vs cache miss: coste (informativo)', () async {
    TranscriptionHardwareProfile.debugResetForTests();
    final swMiss = Stopwatch()..start();
    await TranscriptionHardwareProfile.loadCachedAsync(); // miss: lee
    swMiss.stop();

    final swHit = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      TranscriptionHardwareProfile.cachedSnapshotOrNull;
    }
    swHit.stop();

    // ignore: avoid_print
    print('H2 · cache miss (1 lectura)=${swMiss.elapsedMilliseconds} ms  '
        'cache hit ×1000=${swHit.elapsedMicroseconds} us '
        '(${(swHit.elapsedMicroseconds / 1000).toStringAsFixed(2)} us/hit)');

    expect(TranscriptionHardwareProfile.cachedSnapshotOrNull, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
