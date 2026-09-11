import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/theme_color_tokens.dart';
import 'package:folio/config/models/theme_shape_tokens.dart';
import 'package:folio/config/models/theme_variant.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';
import 'package:folio/theme_engine/theme_variant_resolver.dart';

void main() {
  group('applyVariant', () {
    test('a variant that only overrides dark.surfaceStyle leaves light and '
        'every other dark field untouched', () {
      final base = kFolioDefaultTheme.copyWith(
        dark: ThemeColorTokens(
          seedArgb: kFolioDefaultTheme.dark.seedArgb,
          surfaceStyle: 'standard',
        ),
      );
      final variant = ThemeVariant(
        id: 'night-oled',
        name: 'Night OLED',
        dark: ThemeColorTokens(
          seedArgb: base.dark.seedArgb,
          surfaceStyle: 'oled',
        ),
      );

      final result = applyVariant(base, variant);

      expect(result.dark.surfaceStyle, 'oled');
      expect(result.dark.seedArgb, base.dark.seedArgb);
      expect(result.light, base.light); // untouched
      expect(result.shape, base.shape); // untouched
      expect(result.id, base.id); // identity preserved
    });

    test('an unconfigured field on the variant falls back to the base '
        'value — the same ?? mechanism as any other copyWith call', () {
      final base = kFolioDefaultTheme;
      final variant = ThemeVariant(
        id: 'v1',
        name: 'V1',
        shape: ThemeShapeTokens(radiusLg: 99),
      );

      final result = applyVariant(base, variant);

      expect(result.shape.radiusLg, 99);
      expect(result.surfaceOpacity, base.surfaceOpacity);
      expect(result.accentMode, base.accentMode);
    });
  });

  group('findVariant / resolveActiveVariant', () {
    test('findVariant returns null when activeVariantId is null or unknown', () {
      final config = kFolioDefaultTheme.copyWith(
        variants: [const ThemeVariant(id: 'a', name: 'A')],
      );
      expect(findVariant(config, null), isNull);
      expect(findVariant(config, 'does-not-exist'), isNull);
      expect(findVariant(config, 'a')?.id, 'a');
    });

    test('resolveActiveVariant is a no-op when there is no active variant', () {
      final config = kFolioDefaultTheme;
      expect(resolveActiveVariant(config), config);
    });

    test('resolveActiveVariant applies the variant named by activeVariantId', () {
      final config = kFolioDefaultTheme.copyWith(
        variants: [
          ThemeVariant(id: 'warm', name: 'Warm', shape: ThemeShapeTokens(radiusLg: 2)),
        ],
        activeVariantId: 'warm',
      );
      final resolved = resolveActiveVariant(config);
      expect(resolved.shape.radiusLg, 2);
    });
  });
}
