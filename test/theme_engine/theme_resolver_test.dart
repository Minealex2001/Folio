import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/folio_brand_palette.dart';
import 'package:folio/app/ui_tokens.dart';
import 'package:folio/config/models/theme_color_tokens.dart';
import 'package:folio/config/models/theme_config.dart';
import 'package:folio/config/models/theme_shape_tokens.dart';
import 'package:folio/config/models/theme_typography_tokens.dart';
import 'package:folio/theme_engine/theme_color_resolver.dart';
import 'package:folio/theme_engine/theme_config_defaults.dart';
import 'package:folio/theme_engine/theme_resolver.dart';

/// NOTA IMPORTANTE sobre alcance: no se puede invocar
/// `GoogleFonts.outfitTextTheme` (usada tanto por el `folio_theme.dart`
/// legacy como por `resolveThemeData` cuando `typography.fontFamily` es
/// null) en este sandbox de test — el paquete intenta buscar la fuente
/// primero en assets y, si falla, hacer fetch por red; ninguna de las dos
/// vías está disponible aquí, y falla igual para el código legacy que para
/// el nuevo (no hay ningún test preexistente en el repo que ejercite
/// `folio_theme.dart` por la misma razón). Por eso estos tests usan un
/// `ThemeConfig` con `typography.fontFamily` explícito (evita por completo
/// la carga de Google Fonts, vía `TextTheme.apply`) para verificar TODO lo
/// demás — radios, espaciado, elevación, ColorScheme — contra los valores
/// hardcodeados hoy en `ui_tokens.dart`/`folio_theme.dart`. La rama por
/// defecto (fontFamily null -> GoogleFonts.outfitTextTheme) es la MISMA
/// llamada, con el MISMO argumento, que ya existía en
/// `_folioThemeFromBase` — puede verificarse por inspección de
/// `theme_resolver.dart` sin necesitar ejecutarla aquí.
void main() {
  const seedArgb = 0xFF3366CC;
  final testTheme = kFolioDefaultTheme.copyWith(
    accentMode: 'custom',
    light: ThemeColorTokens(seedArgb: seedArgb),
    dark: ThemeColorTokens(seedArgb: seedArgb),
    typography: ThemeTypographyTokens(fontFamily: 'Roboto'),
  );

  ColorScheme expectedScheme(Brightness brightness) => ColorScheme.fromSeed(
    seedColor: const Color(seedArgb),
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );

  group('resolveThemeData matches today\'s hardcoded tokens', () {
    test('light theme: colors, shape, spacing, elevation', () {
      final theme = resolveThemeData(testTheme, Brightness.light);

      expect(theme.colorScheme, expectedScheme(Brightness.light));
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      expect(
        theme.visualDensity,
        const VisualDensity(horizontal: -1, vertical: -1),
      );
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);

      final appBar = theme.appBarTheme;
      expect(appBar.elevation, FolioElevation.none);
      expect(appBar.scrolledUnderElevation, FolioElevation.appBarScrolled);
      expect(appBar.toolbarHeight, 64);
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.foregroundColor, theme.colorScheme.onSurface);

      final card = theme.cardTheme;
      expect(card.elevation, FolioElevation.none);
      expect(card.color, theme.colorScheme.surfaceContainerLow);
      expect(
        (card.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(FolioRadius.md),
      );

      final filled = theme.filledButtonTheme.style!;
      expect(
        (filled.shape?.resolve({}) as RoundedRectangleBorder?)?.borderRadius,
        BorderRadius.circular(FolioRadius.xl),
      );
      expect(
        filled.padding?.resolve({}),
        const EdgeInsets.symmetric(
          horizontal: FolioSpace.lg,
          vertical: FolioSpace.sm,
        ),
      );

      final input = theme.inputDecorationTheme;
      expect(
        (input.border as OutlineInputBorder?)?.borderRadius,
        BorderRadius.circular(FolioRadius.md),
      );

      final popup = theme.popupMenuTheme;
      expect(popup.elevation, FolioElevation.menu);

      final tooltip = theme.tooltipTheme;
      expect(tooltip.waitDuration, FolioMotion.short2);

      final scrollbar = theme.scrollbarTheme;
      expect(scrollbar.radius, const Radius.circular(FolioRadius.sm));
    });

    test('dark theme: colorScheme matches ColorScheme.fromSeed(dark)', () {
      final theme = resolveThemeData(testTheme, Brightness.dark);
      expect(theme.colorScheme, expectedScheme(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('OLED: surface overrides match folioOledTheme\'s literal values', () {
      final oledTheme = testTheme.copyWith(
        dark: ThemeColorTokens(seedArgb: seedArgb, surfaceStyle: 'oled'),
      );
      final theme = resolveThemeData(oledTheme, Brightness.dark);

      expect(theme.colorScheme.surface, Colors.black);
      expect(theme.colorScheme.surfaceDim, const Color(0xFF000000));
      expect(theme.colorScheme.surfaceBright, const Color(0xFF101010));
      expect(
        theme.colorScheme.surfaceContainerLowest,
        const Color(0xFF000000),
      );
      expect(theme.colorScheme.surfaceContainerLow, const Color(0xFF050505));
      expect(theme.colorScheme.surfaceContainer, const Color(0xFF0A0A0A));
      expect(theme.colorScheme.surfaceContainerHigh, const Color(0xFF0F0F0F));
      expect(
        theme.colorScheme.surfaceContainerHighest,
        const Color(0xFF141414),
      );
      expect(theme.scaffoldBackgroundColor, Colors.black);

      // Fuera de OLED, la superficie no debe forzarse a negro.
      final standardDark = resolveThemeData(testTheme, Brightness.dark);
      expect(standardDark.scaffoldBackgroundColor, isNot(Colors.black));
    });

    test('componentRadiusOverrides overrides a single component without '
        'affecting others (Retro-pack style escape hatch, Fase 8)', () {
      final overridden = testTheme.copyWith(
        shape: ThemeShapeTokens(
          radiusXs: testTheme.shape.radiusXs,
          radiusSm: testTheme.shape.radiusSm,
          radiusMd: testTheme.shape.radiusMd,
          radiusLg: testTheme.shape.radiusLg,
          radiusXl: testTheme.shape.radiusXl,
          radiusXxl: testTheme.shape.radiusXxl,
          componentRadiusOverrides: const {'card': 0},
        ),
      );
      final theme = resolveThemeData(overridden, Brightness.light);
      expect(
        (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(0),
      );
      // El resto de componentes no declarados en el override no cambian.
      final filledShape =
          theme.filledButtonTheme.style!.shape?.resolve({})
              as RoundedRectangleBorder?;
      expect(filledShape?.borderRadius, BorderRadius.circular(FolioRadius.xl));
    });
  });

  group('kFolioDefaultTheme mirrors ui_tokens.dart exactly (drift guard)', () {
    test('shape tokens', () {
      expect(kFolioDefaultTheme.shape.radiusXs, FolioRadius.xs);
      expect(kFolioDefaultTheme.shape.radiusSm, FolioRadius.sm);
      expect(kFolioDefaultTheme.shape.radiusMd, FolioRadius.md);
      expect(kFolioDefaultTheme.shape.radiusLg, FolioRadius.lg);
      expect(kFolioDefaultTheme.shape.radiusXl, FolioRadius.xl);
      expect(kFolioDefaultTheme.shape.radiusXxl, FolioRadius.xxl);
    });

    test('spacing tokens', () {
      expect(kFolioDefaultTheme.spacing.xxs, FolioSpace.xxs);
      expect(kFolioDefaultTheme.spacing.xs, FolioSpace.xs);
      expect(kFolioDefaultTheme.spacing.sm, FolioSpace.sm);
      expect(kFolioDefaultTheme.spacing.md, FolioSpace.md);
      expect(kFolioDefaultTheme.spacing.lg, FolioSpace.lg);
      expect(kFolioDefaultTheme.spacing.xl, FolioSpace.xl);
    });

    test('elevation tokens', () {
      expect(kFolioDefaultTheme.elevation.none, FolioElevation.none);
      expect(
        kFolioDefaultTheme.elevation.appBarScrolled,
        FolioElevation.appBarScrolled,
      );
      expect(kFolioDefaultTheme.elevation.menu, FolioElevation.menu);
    });

    test('motion tokens', () {
      expect(kFolioDefaultTheme.motion.short2Ms, FolioMotion.short2.inMilliseconds);
    });

    test('default accent mode is followSystem (matches AppSettings default)', () {
      expect(kFolioDefaultTheme.accentMode, 'followSystem');
    });

    test('does not throw when resolved through the real followSystem/'
        'GoogleFonts path (smoke test only, no fixed expected output)', () {
      expect(
        () => resolveThemeData(kFolioDefaultTheme, Brightness.light),
        returnsNormally,
      );
    });
  });

  group('resolveColorScheme / resolveAccentSeedColor', () {
    test('folioDefault mode returns FolioBrandPalette regardless of seed', () {
      final theme = kFolioDefaultTheme.copyWith(accentMode: 'folioDefault');
      expect(
        resolveColorScheme(theme, brightness: Brightness.light),
        FolioBrandPalette.light,
      );
      expect(
        resolveColorScheme(theme, brightness: Brightness.dark),
        FolioBrandPalette.dark,
      );
    });

    test('custom mode uses ColorScheme.fromSeed with the configured seed', () {
      final theme = kFolioDefaultTheme.copyWith(
        accentMode: 'custom',
        light: ThemeColorTokens(seedArgb: seedArgb),
      );
      expect(
        resolveColorScheme(theme, brightness: Brightness.light),
        expectedScheme(Brightness.light),
      );
      expect(
        resolveAccentSeedColor(theme),
        const Color(seedArgb),
      );
    });
  });

  group('resolveMotionCurve', () {
    test('maps known names to their Curve, defaults to easeOutCubic', () {
      expect(resolveMotionCurve('linear'), Curves.linear);
      expect(resolveMotionCurve('easeOutCubic'), Curves.easeOutCubic);
      // easeOutExpo: usada por el pack Cyberpunk (Fase 8) para su curva
      // rápida/aguda — faltaba antes de la Fase 9 y caía silenciosamente al
      // default, perdiendo la distinción de movimiento del pack.
      expect(resolveMotionCurve('easeOutExpo'), Curves.easeOutExpo);
      expect(resolveMotionCurve('unknown'), Curves.easeOutCubic);
    });
  });
}
