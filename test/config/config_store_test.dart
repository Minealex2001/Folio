import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_paths.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/accessibility_config.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/design_tokens.dart';
import 'package:folio/config/models/design_variables.dart';
import 'package:folio/config/models/editor_layout_tokens.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_config.dart';
import 'package:folio/config/models/theme_config.dart';
import 'package:folio/config/models/toolbar_config.dart';
import 'package:folio/config/models/widget_instance_config.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_config_store_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('ConfigStore round-trip', () {
    test('layout: save -> load -> equal fields', () async {
      final store = await ConfigStore.open();
      final layout = LayoutConfig(
        id: 'my-layout',
        name: 'My Layout',
        panels: {
          'sidebarLeft': PanelConfig(
            regionId: 'sidebarLeft',
            visible: true,
            width: 320,
            showDivider: false,
          ),
        },
      );

      await store.saveLayout(layout);
      final loaded = await store.loadLayout('my-layout');

      expect(loaded, isNotNull);
      expect(loaded!.id, layout.id);
      expect(loaded.name, layout.name);
      expect(loaded.panels['sidebarLeft']!.width, 320);
      expect(loaded.panels['sidebarLeft']!.visible, isTrue);
      expect(loaded.panels['sidebarLeft']!.showDivider, isFalse);
    });

    test('theme: save -> load -> equal fields', () async {
      final store = await ConfigStore.open();
      final theme = ThemeConfig.fallbackDefault(id: 'my-theme', oled: true);

      await store.saveTheme(theme);
      final loaded = await store.loadTheme('my-theme');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'my-theme');
      expect(loaded.dark.surfaceStyle, 'oled');
      expect(loaded.dark.isOled, isTrue);
    });

    test('dashboard: save -> load -> equal fields', () async {
      final store = await ConfigStore.open();
      final dashboard = DashboardConfig(
        id: 'my-dashboard',
        name: 'Inicio',
        columns: 3,
        gap: 20,
        widgets: [
          WidgetInstanceConfig(
            instanceId: 'w1',
            pluginId: 'tasks',
            regionId: 'left',
            order: 0,
          ),
        ],
      );

      await store.saveDashboard(dashboard);
      final loaded = await store.loadDashboard('my-dashboard');

      expect(loaded, isNotNull);
      expect(loaded!.columns, 3);
      expect(loaded.gap, 20);
      expect(loaded.widgets, hasLength(1));
      expect(loaded.widgets.first.pluginId, 'tasks');
    });

    test('layout with a ToolbarConfig: save -> load -> equal fields '
        '(Fase 25)', () async {
      final store = await ConfigStore.open();
      final layout = LayoutConfig(
        id: 'toolbar-layout',
        name: 'Toolbar layout',
        panels: {},
        toolbar: const ToolbarConfig(position: 'bottom', height: 48),
      );

      await store.saveLayout(layout);
      final loaded = await store.loadLayout('toolbar-layout');

      expect(loaded, isNotNull);
      expect(loaded!.toolbar, isNotNull);
      expect(loaded.toolbar!.position, 'bottom');
      expect(loaded.toolbar!.height, 48);
    });

    test('layout with EditorLayoutTokens: save -> load -> equal fields '
        '(Fase 27)', () async {
      final store = await ConfigStore.open();
      final layout = LayoutConfig(
        id: 'editor-layout',
        name: 'Editor layout',
        panels: {},
        editor: const EditorLayoutTokens(
          markdownSymbolVisibility: 'always',
          calloutStyle: 'obsidian',
        ),
      );

      await store.saveLayout(layout);
      final loaded = await store.loadLayout('editor-layout');

      expect(loaded, isNotNull);
      expect(loaded!.editor, isNotNull);
      expect(loaded.editor!.markdownSymbolVisibility, 'always');
      expect(loaded.editor!.calloutStyle, 'obsidian');
    });

    test('tokens: save -> load -> equal fields', () async {
      final store = await ConfigStore.open();
      final tokens = DesignTokens(
        id: 'my-tokens',
        radius: const {'lg': 16},
        color: const {'danger': 0xFFFF0000},
      );

      await store.saveTokens(tokens);
      final loaded = await store.loadTokens('my-tokens');

      expect(loaded, isNotNull);
      expect(loaded!.radius['lg'], 16);
      expect(loaded.color['danger'], 0xFFFF0000);
    });

    test('variables: save -> load -> equal fields', () async {
      final store = await ConfigStore.open();
      final variables = DesignVariables(
        id: 'my-variables',
        entries: const {'editorPadding': '@space.md'},
      );

      await store.saveVariables(variables);
      final loaded = await store.loadVariables('my-variables');

      expect(loaded, isNotNull);
      expect(loaded!.entries['editorPadding'], '@space.md');
    });

    test('accessibility: save -> load -> equal fields', () async {
      final store = await ConfigStore.open();
      await store.saveAccessibility(
        AccessibilityConfig(contrast: 'high', reduceMotion: true),
      );
      final loaded = await store.loadAccessibility();

      expect(loaded, isNotNull);
      expect(loaded!.contrast, 'high');
      expect(loaded.reduceMotion, isTrue);
    });

    test('loadAccessibility returns null when nothing is persisted yet', () async {
      final store = await ConfigStore.open();
      expect(await store.loadAccessibility(), isNull);
    });

    test('loading a non-existent id returns null', () async {
      final store = await ConfigStore.open();
      expect(await store.loadLayout('does-not-exist'), isNull);
      expect(await store.loadTheme('does-not-exist'), isNull);
      expect(await store.loadDashboard('does-not-exist'), isNull);
      expect(await store.loadTokens('does-not-exist'), isNull);
      expect(await store.loadVariables('does-not-exist'), isNull);
    });

    test('listLayoutIds reflects saved layouts', () async {
      final store = await ConfigStore.open();
      await store.saveLayout(LayoutConfig.defaultConfig(id: 'a'));
      await store.saveLayout(LayoutConfig.defaultConfig(id: 'b'));
      final ids = await store.listLayoutIds();
      expect(ids, containsAll(['a', 'b']));
    });

    test('deleteLayout removes the document', () async {
      final store = await ConfigStore.open();
      await store.saveLayout(LayoutConfig.defaultConfig(id: 'to-delete'));
      expect(await store.loadLayout('to-delete'), isNotNull);
      await store.deleteLayout('to-delete');
      expect(await store.loadLayout('to-delete'), isNull);
    });

    test('revision notifier bumps on save', () async {
      final store = await ConfigStore.open();
      final notifier = store.revisions[ConfigCategory.layouts]!;
      final before = notifier.value;
      await store.saveLayout(LayoutConfig.defaultConfig(id: 'rev-test'));
      expect(notifier.value, before + 1);
    });
  });

  group('ConfigStore export/import bundle', () {
    test('round-trips a layout+theme+dashboard bundle', () async {
      final store = await ConfigStore.open();
      await store.saveLayout(LayoutConfig.defaultConfig(id: 'bundle-layout'));
      await store.saveTheme(ThemeConfig.fallbackDefault(id: 'bundle-theme'));
      await store.saveDashboard(
        DashboardConfig(id: 'bundle-dashboard', name: 'Inicio'),
      );

      final bundle = await store.exportBundle(
        layoutIds: ['bundle-layout'],
        themeIds: ['bundle-theme'],
        dashboardIds: ['bundle-dashboard'],
      );

      // Simular reinstalación: borrar y reimportar desde el bundle exportado.
      await store.deleteLayout('bundle-layout');
      await store.deleteTheme('bundle-theme');
      await store.deleteDashboard('bundle-dashboard');
      expect(await store.loadLayout('bundle-layout'), isNull);

      await store.importBundle(bundle);

      expect(await store.loadLayout('bundle-layout'), isNotNull);
      expect(await store.loadTheme('bundle-theme'), isNotNull);
      expect(await store.loadDashboard('bundle-dashboard'), isNotNull);
    });
  });
}
