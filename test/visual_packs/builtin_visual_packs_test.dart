import 'package:flutter_test/flutter_test.dart';

import 'package:folio/visual_packs/builtin/builtin_visual_packs.dart';

void main() {
  test('builtinVisualPacks has 11 unique ids including minealex_games', () {
    final packs = builtinVisualPacks();
    expect(packs, hasLength(11));
    final ids = packs.map((p) => p.manifest.id).toList();
    expect(ids.toSet(), hasLength(11));
    expect(ids, contains('material3'));
    expect(ids, contains('minealex_games'));
  });

  test('no builtin dashboard uses stub plugin ids', () {
    const stubs = {'rss', 'books', 'ai'};
    for (final pack in builtinVisualPacks()) {
      for (final w in pack.dashboard.widgets) {
        expect(
          stubs.contains(w.pluginId),
          isFalse,
          reason: '${pack.manifest.id} includes stub plugin ${w.pluginId}',
        );
      }
    }
  });

  test('minealex_games uses FolioBrandPalette + OLED dark', () {
    final pack = builtinVisualPacks().firstWhere(
      (p) => p.manifest.id == 'minealex_games',
    );
    // folioDefault → cyan/magenta explícitos (no fromSeed).
    expect(pack.theme.accentMode, 'folioDefault');
    expect(pack.theme.light.seedArgb, 0xFF00F3FF);
    expect(pack.theme.dark.seedArgb, 0xFF00F3FF);
    expect(pack.theme.dark.surfaceStyle, 'oled');
    expect(pack.manifest.name, 'Minealex Games');
  });

  test('non-material packs use custom accentMode (except minealex brand)', () {
    for (final pack in builtinVisualPacks()) {
      if (pack.manifest.id == 'material3') continue;
      if (pack.manifest.id == 'minealex_games') {
        expect(pack.theme.accentMode, 'folioDefault');
        continue;
      }
      expect(
        pack.theme.accentMode,
        'custom',
        reason: pack.manifest.id,
      );
    }
  });

  test('each non-material3 pack declares a distinct fontFamily', () {
    final families = <String>[];
    for (final pack in builtinVisualPacks()) {
      if (pack.manifest.id == 'material3') continue;
      final family = pack.theme.typography.fontFamily;
      expect(
        family,
        isNotNull,
        reason: '${pack.manifest.id} should set an explicit fontFamily',
      );
      families.add(family!);
    }
    expect(
      families.toSet(),
      hasLength(families.length),
      reason: 'duplicate fonts: $families',
    );
  });
}
