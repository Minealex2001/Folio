import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/features/legal/third_party_license_detail_page.dart';
import 'package:folio/features/legal/third_party_licenses_page.dart';
import 'package:folio/features/settings/settings_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/legal/third_party_licenses_catalog.dart';
import 'package:folio/services/cloud_account/cloud_account_controller.dart';
import 'package:folio/services/device_sync/device_sync_controller.dart';
import 'package:folio/services/folio_cloud/folio_cloud_entitlements.dart';
import 'package:folio/session/vault_session.dart';
import 'package:folio/theme_engine/theme_config_controller.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';
import 'package:folio/visual_packs/active_pack_controller.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  tearDown(VaultPaths.clearActiveVaultId);

  Future<SettingsPage> buildSettingsPage() async {
    SharedPreferences.setMockInitialValues({});
    VaultPaths.setActiveVaultId('licenses-test-vault');
    final appSettings = AppSettings();
    final configStore = await ConfigStore.open();
    return SettingsPage(
      session: VaultSession(),
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
    );
  }

  testWidgets('licenses page lists curated entries and flutter licenses tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: ThirdPartyLicensesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open source & third-party licenses'), findsOneWidget);
    expect(find.textContaining('Folio uses open source software'), findsOneWidget);
    expect(find.text('Flutter & Dart package licenses'), findsOneWidget);
    expect(find.text('whisper.cpp'), findsOneWidget);
    expect(find.text('cupertino_icons'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Spring Boot (starters)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Backend (Folio Cloud)'), findsOneWidget);
    expect(find.text('Spring Boot (starters)'), findsOneWidget);
  });

  testWidgets('licenses search filters backend entries', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: ThirdPartyLicensesPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'stripe');
    await tester.pumpAndSettle();
    expect(find.text('stripe-java'), findsOneWidget);
    expect(find.text('cupertino_icons'), findsNothing);
  });

  testWidgets('license detail shows license text and source actions', (
    tester,
  ) async {
    final entry = ThirdPartyLicensesCatalog.findById('whisper-cpp')!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ThirdPartyLicenseDetailPage(entry: entry),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('whisper.cpp'), findsWidgets);
    expect(find.text('MIT'), findsOneWidget);
    expect(find.text('View license'), findsOneWidget);
    expect(find.text('Open repository'), findsOneWidget);

    await tester.tap(find.text('View license'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission is hereby granted'), findsOneWidget);
  });

  testWidgets('About section exposes licenses entry without breaking version tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: await buildSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsPage), findsOneWidget);

    // Navigate to About via rail label.
    final aboutTile = find.text('About');
    expect(aboutTile, findsWidgets);
    await tester.tap(aboutTile.first);
    await tester.pumpAndSettle();

    expect(find.text('Open source & third-party licenses'), findsOneWidget);
    expect(find.textContaining('Installed'), findsWidgets);

    await tester.tap(find.text('Open source & third-party licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(ThirdPartyLicensesPage), findsOneWidget);
  });

  testWidgets('licenses page respects dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const ThirdPartyLicensesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ThirdPartyLicensesPage), findsOneWidget);
  });

  testWidgets('Spanish localization resolves licenses strings', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es'),
        home: ThirdPartyLicensesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Software de código abierto y licencias de terceros'),
      findsOneWidget,
    );
  });
}
