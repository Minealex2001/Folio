import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/features/settings/settings_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/services/cloud_account/cloud_account_controller.dart';
import 'package:folio/services/device_sync/device_sync_controller.dart';
import 'package:folio/services/folio_cloud/folio_cloud_entitlements.dart';
import 'package:folio/session/vault_session.dart';

/// Blocking prerequisite for the v0.8.0 settings_page.dart decomposition:
/// this file had zero widget-test coverage despite being one of the
/// largest/riskiest files in the app (5,601 lines, a single ~4,860-line
/// build() method). Nothing here should regress across the extraction
/// passes that follow.
void main() {
  tearDown(VaultPaths.clearActiveVaultId);

  Future<SettingsPage> buildPage() async {
    SharedPreferences.setMockInitialValues({});
    VaultPaths.setActiveVaultId('smoke-test-vault');
    final appSettings = AppSettings();
    return SettingsPage(
      session: VaultSession(),
      appSettings: appSettings,
      deviceSyncController: DeviceSyncController(appSettings: appSettings),
      cloudAccountController: CloudAccountController(),
      folioCloudEntitlements: FolioCloudEntitlementsController(),
    );
  }

  testWidgets('renders without throwing on a desktop-width viewport', (
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
        home: await buildPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('renders without throwing on a mobile-width viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: await buildPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
