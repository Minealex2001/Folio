import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/theme_color_tokens.dart';
import 'package:folio/config/models/theme_config.dart';
import 'package:folio/theme_engine/theme_config_controller.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_theme_controller_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  ThemeConfigController makeController({Duration? debounce}) {
    return ThemeConfigController(
      store,
      initialConfig: kFolioDefaultTheme.copyWith(),
      persistDebounce: debounce ?? const Duration(minutes: 10),
    );
  }

  test('setCornerRoundness scales all radii from the default, not '
      'cumulatively', () {
    final controller = makeController();
    final defaultRadiusMd = kFolioDefaultTheme.shape.radiusMd;

    controller.setCornerRoundness(2.0);
    expect(controller.config.shape.radiusMd, defaultRadiusMd * 2);

    controller.setCornerRoundness(2.0); // repetir no debe duplicar
    expect(controller.config.shape.radiusMd, defaultRadiusMd * 2);

    controller.setCornerRoundness(0.5);
    expect(controller.config.shape.radiusMd, defaultRadiusMd * 0.5);
  });

  test('setSpacingDensity scales all spacing values from the default', () {
    final controller = makeController();
    final defaultMd = kFolioDefaultTheme.spacing.md;

    controller.setSpacingDensity(1.5);
    expect(controller.config.spacing.md, defaultMd * 1.5);
  });

  test('setMotionSpeed shortens durations as speed increases', () {
    final controller = makeController();
    final defaultShort2 = kFolioDefaultTheme.motion.short2Ms;

    controller.setMotionSpeed(2.0); // 2x más rápido -> mitad de duración
    expect(controller.config.motion.short2Ms, defaultShort2 ~/ 2);
  });

  test('setSurfaceOpacity clamps to [0, 1]', () {
    final controller = makeController();
    controller.setSurfaceOpacity(1.5);
    expect(controller.config.surfaceOpacity, 1.0);
    controller.setSurfaceOpacity(-0.5);
    expect(controller.config.surfaceOpacity, 0.0);
    controller.setSurfaceOpacity(0.7);
    expect(controller.config.surfaceOpacity, 0.7);
  });

  test('resetToDefault restores shape/spacing/motion/surfaceOpacity but '
      'keeps the accent (light/dark/accentMode) untouched', () async {
    final customAccent = ThemeColorTokens(seedArgb: 0xFF123456);
    final controller = ThemeConfigController(
      store,
      initialConfig: kFolioDefaultTheme.copyWith(
        light: customAccent,
        dark: customAccent,
        accentMode: 'custom',
      ),
    );
    controller.setCornerRoundness(2.0);
    controller.setSurfaceOpacity(0.5);

    await controller.resetToDefault();

    expect(controller.config.shape.radiusMd, kFolioDefaultTheme.shape.radiusMd);
    expect(controller.config.surfaceOpacity, kFolioDefaultTheme.surfaceOpacity);
    expect(controller.config.accentMode, 'custom'); // conservado
    expect(controller.config.light.seedArgb, 0xFF123456); // conservado
  });

  test('replaceConfig adopts everything from the replacement but keeps the '
      'active theme id', () {
    final controller = makeController();
    controller.replaceConfig(
      ThemeConfig.fallbackDefault(id: 'unrelated', accentMode: 'custom'),
    );
    expect(controller.config.id, kFolioDefaultTheme.id); // conserva la id activa
    expect(controller.config.accentMode, 'custom');
  });

  test('mutations notify listeners and schedule persistence', () async {
    final controller = makeController(debounce: const Duration(milliseconds: 30));
    var notified = false;
    controller.addListener(() => notified = true);

    controller.setSurfaceOpacity(0.6);
    expect(notified, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    final saved = await store.loadTheme(controller.config.id);
    expect(saved!.surfaceOpacity, 0.6);
  });

  test('load() falls back to kFolioDefaultTheme when nothing is persisted '
      'yet', () async {
    final controller = await ThemeConfigController.load(store, id: 'fresh');
    expect(controller.config.shape.radiusMd, kFolioDefaultTheme.shape.radiusMd);
  });
}
