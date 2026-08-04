import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/app/folio_app.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/services/cloud_account/cloud_account_controller.dart';
import 'package:folio/services/folio_cloud/folio_cloud_entitlements.dart';
import 'package:folio/session/vault_session.dart';
import 'package:folio/theme_engine/theme_config_controller.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  testWidgets('MaterialApp de Folio se monta', (WidgetTester tester) async {
    final session = VaultSession();
    final appSettings = AppSettings();
    final cloudAccountController = CloudAccountController();
    final folioCloudEntitlements = FolioCloudEntitlementsController();
    final configStore = await ConfigStore.open();
    final layoutEngineController = LayoutEngineController(
      configStore,
      initialConfig: LayoutConfig.defaultConfig(),
    );
    final dashboardGridController = DashboardGridController(
      configStore,
      initialConfig: DashboardConfig(id: 'active', name: 'Inicio'),
    );
    final themeConfigController = ThemeConfigController(
      configStore,
      initialConfig: kFolioDefaultTheme,
    );
    await tester.pumpWidget(
      FolioApp(
        session: session,
        appSettings: appSettings,
        cloudAccountController: cloudAccountController,
        configStore: configStore,
        layoutEngineController: layoutEngineController,
        dashboardGridController: dashboardGridController,
        themeConfigController: themeConfigController,
        folioCloudEntitlements: folioCloudEntitlements,
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
