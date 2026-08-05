import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/session/vault_session.dart';
import 'package:folio/widget_catalog/builtin/bookmarks_widget_plugin.dart';
import 'package:folio/widget_catalog/builtin/builtin_widget_card.dart';
import 'package:folio/widget_catalog/builtin/weather_widget_plugin.dart';
import 'package:folio/widget_catalog/widget_plugin_context.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_widget_smoke_');
    ConfigStoreBackend.debugRootOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
    VaultPaths.setActiveVaultId('widget-smoke-vault');
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    VaultPaths.clearActiveVaultId();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  WidgetPluginContext ctx() {
    return WidgetPluginContext(
      appSettings: AppSettings(),
      configStore: store,
      session: VaultSession(),
    );
  }

  testWidgets('weather empty city shows configure hint', (tester) async {
    const plugin = WeatherWidgetPlugin();
    final instance = WidgetInstanceConfig(
      instanceId: 'w1',
      pluginId: 'weather',
      regionId: 'left',
      order: 0,
    );
    final pluginCtx = ctx();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return SizedBox(
                height: 160,
                width: 320,
                child: plugin.build(context, instance, pluginCtx),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Configura una ciudad en los ajustes del widget.'),
      findsOneWidget,
    );
    expect(find.byType(BuiltinWidgetEmpty), findsOneWidget);
  });

  testWidgets('bookmarks empty vault shows empty state', (tester) async {
    const plugin = BookmarksWidgetPlugin();
    final instance = WidgetInstanceConfig(
      instanceId: 'b1',
      pluginId: 'bookmarks',
      regionId: 'left',
      order: 0,
    );
    final pluginCtx = ctx();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return SizedBox(
                height: 160,
                width: 320,
                child: plugin.build(context, instance, pluginCtx),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('No hay bloques marcador en el vault.'),
      findsOneWidget,
    );
  });
}
