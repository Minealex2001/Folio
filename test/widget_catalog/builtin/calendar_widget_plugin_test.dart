import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/config/models/widget_theme_tokens.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/session/vault_session.dart';
import 'package:folio/widget_catalog/builtin/calendar_widget_plugin.dart';
import 'package:folio/widget_catalog/widget_plugin_context.dart';

/// Fase 23 (Widget Theme Tokens): el calendario es el primer plugin
/// builtin que consume `ctx.widgetThemeFor` — este test prueba el
/// mecanismo de punta a punta, no solo el resolver puro.
void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_calendar_widget_test_');
    ConfigStoreBackend.debugRootOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
    VaultPaths.setActiveVaultId('calendar-widget-test-vault');
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    VaultPaths.clearActiveVaultId();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  const plugin = CalendarWidgetPlugin();
  final instance = WidgetInstanceConfig(
    instanceId: 'cal1',
    pluginId: 'calendar',
    regionId: 'left',
    order: 0,
  );

  Future<void> pump(WidgetTester tester, WidgetPluginContext ctx) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              height: 260,
              width: 320,
              child: plugin.build(context, instance, ctx),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('unconfigured widgetThemeTokens renders without a weekend '
      'color override (parity with pre-Fase-23 behavior)', (tester) async {
    final ctx = WidgetPluginContext(
      appSettings: AppSettings(),
      configStore: store,
      session: VaultSession(),
    );
    await pump(tester, ctx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a configured weekendColor in ThemeConfig.widgetThemes is '
      'applied to weekend day labels', (tester) async {
    final ctx = WidgetPluginContext(
      appSettings: AppSettings(),
      configStore: store,
      session: VaultSession(),
      widgetThemeTokens: const WidgetThemeTokens(
        widgets: {
          'calendar': {'weekendColor': 0xFFFF0000},
        },
      ),
    );
    await pump(tester, ctx);
    expect(tester.takeException(), isNull);

    final now = DateTime.now();
    final firstWeekendDay = Iterable<int>.generate(
      DateTime(now.year, now.month + 1, 0).day,
      (i) => i + 1,
    ).firstWhere(
      (d) =>
          DateTime(now.year, now.month, d).weekday >= DateTime.saturday &&
          d != now.day,
    );

    final textWidget = tester.widget<Text>(find.text('$firstWeekendDay').first);
    expect(textWidget.style?.color, const Color(0xFFFF0000));
  });
}
