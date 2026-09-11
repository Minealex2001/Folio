import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_region_ids.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/layout_engine/layout_engine_controller.dart';
import 'package:folio/theme_engine/theme_color_resolver.dart';
import 'package:folio/theme_engine/theme_config_controller.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';
import 'package:folio/visual_packs/active_pack_controller.dart';
import 'package:folio/visual_packs/builtin/builtin_visual_packs.dart';
import 'package:folio/visual_packs/visual_pack.dart';
import 'package:folio/visual_packs/visual_pack_export.dart';
import 'package:folio/visual_packs/visual_pack_installer.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;
  late LayoutEngineController layoutEngineController;
  late ThemeConfigController themeConfigController;
  late DashboardGridController dashboardGridController;
  late ActivePackController activePackController;
  late VisualPackInstaller installer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_visual_pack_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
    VaultPaths.setActiveVaultId('visual-pack-test-vault');
    store = await ConfigStore.open();

    layoutEngineController = LayoutEngineController(
      store,
      initialConfig: LayoutConfig.defaultConfig(),
      persistDebounce: const Duration(minutes: 10),
    );
    themeConfigController = ThemeConfigController(
      store,
      initialConfig: kFolioDefaultTheme,
      persistDebounce: const Duration(minutes: 10),
    );
    dashboardGridController = DashboardGridController(
      store,
      initialConfig: DashboardConfig(id: 'active', name: 'Inicio'),
      persistDebounce: const Duration(minutes: 10),
    );
    activePackController = ActivePackController(store);
    installer = VisualPackInstaller(
      layoutEngineController: layoutEngineController,
      themeConfigController: themeConfigController,
      dashboardGridController: dashboardGridController,
      activePackController: activePackController,
    );
  });

  tearDown(() async {
    layoutEngineController.dispose();
    themeConfigController.dispose();
    dashboardGridController.dispose();
    ConfigStoreBackend.debugRootOverride = null;
    VaultPaths.clearActiveVaultId();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('exactly 11 builtin packs exist, with unique ids', () {
    final packs = builtinVisualPacks();
    expect(packs, hasLength(11));
    expect(packs.map((p) => p.manifest.id).toSet(), hasLength(11));
  });

  test(
    'every non-material3 pack sets accentMode to custom so its seedArgb is '
    "actually used — regression for the bug where every pack's color "
    'silently fell back to the OS accent color',
    () {
      for (final pack in builtinVisualPacks()) {
        if (pack.manifest.id == 'material3') {
          // Material 3 es el baseline/reset — debe seguir followSystem,
          // igual que kFolioDefaultTheme.
          expect(pack.theme.accentMode, 'followSystem');
          continue;
        }
        if (pack.manifest.id == 'minealex_games') {
          // Marca: FolioBrandPalette (cyan+magenta), no fromSeed.
          expect(pack.theme.accentMode, 'folioDefault');
          expect(resolveAccentSeedColor(pack.theme), const Color(0xFF00F3FF));
          continue;
        }
        expect(
          pack.theme.accentMode,
          'custom',
          reason:
              '${pack.manifest.id}: accentMode debe ser custom, si no '
              'resolveAccentSeedColor ignora light.seedArgb por completo',
        );
        final resolvedSeed = resolveAccentSeedColor(pack.theme);
        expect(
          resolvedSeed,
          Color(pack.theme.light.seedArgb),
          reason:
              '${pack.manifest.id}: el color resuelto debe ser el seedArgb '
              'del pack, no el acento del sistema',
        );
      }
    },
  );

  test('applying a pack replaces theme/layout/dashboard while keeping the '
      'active ids, and records it as the active pack', () async {
    final obsidian = builtinVisualPacks().firstWhere(
      (p) => p.manifest.id == 'obsidian',
    );
    final activeThemeId = themeConfigController.config.id;

    await installer.apply(obsidian);

    // La id activa se conserva — el pack aporta contenido, no una id nueva.
    expect(themeConfigController.config.id, activeThemeId);
    expect(
      themeConfigController.config.light.seedArgb,
      obsidian.theme.light.seedArgb,
    );
    expect(layoutEngineController.config.id, 'default');
    expect(
      layoutEngineController.panelFor(PanelRegionIds.sidebarLeft)!.width,
      obsidian.layout.panels[PanelRegionIds.sidebarLeft]!.width,
    );
    expect(dashboardGridController.config.id, 'active');
    expect(dashboardGridController.config.columns, obsidian.dashboard.columns);
    expect(activePackController.activePackId, 'obsidian');

    await layoutEngineController.persist();
    await themeConfigController.persist();
    await dashboardGridController.persist();
  });

  test('exporting the current setup and re-importing it round-trips theme/'
      'layout/dashboard', () async {
    final cyberpunk = builtinVisualPacks().firstWhere(
      (p) => p.manifest.id == 'cyberpunk',
    );
    await installer.apply(cyberpunk);

    final export = VisualPackExport(
      layoutEngineController: layoutEngineController,
      themeConfigController: themeConfigController,
      dashboardGridController: dashboardGridController,
    );
    final json = export.exportAsJson(
      id: 'my_export',
      name: 'Mi setup',
      author: 'Alejandro',
    );

    final reimported = VisualPack.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );

    expect(reimported.manifest.name, 'Mi setup');
    expect(reimported.manifest.author, 'Alejandro');
    expect(
      reimported.theme.light.seedArgb,
      cyberpunk.theme.light.seedArgb,
    );
    expect(reimported.layout.panels.keys, cyberpunk.layout.panels.keys);
    expect(reimported.dashboard.widgets.length, cyberpunk.dashboard.widgets.length);

    await layoutEngineController.persist();
    await themeConfigController.persist();
    await dashboardGridController.persist();
  });
}
