import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/folio_brand_palette.dart';
import 'package:folio/app/ui_tokens.dart';
import 'package:folio/config/models/accessibility_config.dart';
import 'package:folio/config/models/component_state_style.dart';
import 'package:folio/config/models/component_style_tokens.dart';
import 'package:folio/config/models/semantic_color_tokens.dart';
import 'package:folio/config/models/theme_color_tokens.dart';
import 'package:folio/config/models/theme_config.dart';
import 'package:folio/config/models/theme_elevation_tokens.dart';
import 'package:folio/config/models/theme_shape_tokens.dart';
import 'package:folio/config/models/theme_typography_tokens.dart';
import 'package:folio/config/models/theme_layer_tokens.dart';
import 'package:folio/config/models/theme_motion_tokens.dart';
import 'package:folio/config/models/token_ref.dart';
import 'package:folio/config/models/visual_style.dart';
import 'package:folio/theme_engine/component_state_resolver.dart';
import 'package:folio/theme_engine/folio_semantic_colors.dart';
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

  group('ComponentStyleTokens (Fase 15) — superset of componentRadiusOverrides', () {
    test('componentStyles.radius produces the exact same result as the '
        'legacy componentRadiusOverrides escape hatch', () {
      final legacy = testTheme.copyWith(
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
      final viaComponentStyles = testTheme.copyWith(
        componentStyles: const ComponentStyleTokens(
          components: {'card': ComponentStyleEntry(radius: TokenRef.literal(0))},
        ),
      );

      final legacyTheme = resolveThemeData(legacy, Brightness.light);
      final newTheme = resolveThemeData(viaComponentStyles, Brightness.light);

      expect(
        (legacyTheme.cardTheme.shape as RoundedRectangleBorder).borderRadius,
        (newTheme.cardTheme.shape as RoundedRectangleBorder).borderRadius,
      );
    });

    test('componentStyles.radius takes precedence over the legacy override '
        'when both are configured for the same component', () {
      final themed = testTheme.copyWith(
        shape: ThemeShapeTokens(
          radiusXs: testTheme.shape.radiusXs,
          radiusSm: testTheme.shape.radiusSm,
          radiusMd: testTheme.shape.radiusMd,
          radiusLg: testTheme.shape.radiusLg,
          radiusXl: testTheme.shape.radiusXl,
          radiusXxl: testTheme.shape.radiusXxl,
          componentRadiusOverrides: const {'card': 4},
        ),
        componentStyles: const ComponentStyleTokens(
          components: {'card': ComponentStyleEntry(radius: TokenRef.literal(0))},
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      expect(
        (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(0),
      );
    });

    test('dialog border defaults to present when unconfigured (parity)', () {
      final theme = resolveThemeData(testTheme, Brightness.light);
      final side = (theme.dialogTheme.shape as RoundedRectangleBorder).side;
      expect(side, isNot(BorderSide.none));
    });

    test('components["dialog"].border = false removes the dialog border', () {
      final themed = testTheme.copyWith(
        componentStyles: const ComponentStyleTokens(
          components: {'dialog': ComponentStyleEntry(border: false)},
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      final side = (theme.dialogTheme.shape as RoundedRectangleBorder).side;
      expect(side, BorderSide.none);
    });
  });

  group('ComponentStateStyle (Fase 17) — scoped to interactive components', () {
    test('unconfigured iconButton background stays null (parity: no fill, '
        'only hover/highlight color)', () {
      final theme = resolveThemeData(testTheme, Brightness.light);
      final bg = theme.iconButtonTheme.style?.backgroundColor?.resolve({
        WidgetState.hovered,
      });
      expect(bg, isNull);
    });

    test('a configured hover background is applied to an interactive '
        'component (iconButton)', () {
      final themed = testTheme.copyWith(
        componentStyles: const ComponentStyleTokens(
          components: {
            'iconButton': ComponentStyleEntry(
              states: ComponentStateStyle(
                hover: ComponentStyleEntry(
                  backgroundColor: TokenRef.literal(0xFF00FF00),
                ),
              ),
            ),
          },
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      final bg = theme.iconButtonTheme.style?.backgroundColor?.resolve({
        WidgetState.hovered,
      });
      expect(bg, const Color(0xFF00FF00));
      // Sin el estado 'hovered' presente, no se aplica.
      final bgIdle = theme.iconButtonTheme.style?.backgroundColor?.resolve({});
      expect(bgIdle, isNull);
    });

    test('a states override on a non-interactive component (card) is '
        'ignored by the resolver', () {
      final resolver = ComponentStateResolver(
        const ComponentStyleTokens(
          components: {
            'card': ComponentStyleEntry(
              states: ComponentStateStyle(
                hover: ComponentStyleEntry(backgroundColor: TokenRef.literal(0xFFFF0000)),
              ),
            ),
          },
        ),
      );
      expect(
        resolver.styleForState('card', {WidgetState.hovered}),
        isNull,
      );
    });
  });

  group('ThemeLayerTokens (Fase 18) — 3-tier surface/panel/overlay', () {
    test('unconfigured layers preserves today\'s literal dialog/popup '
        'elevation (parity)', () {
      final theme = resolveThemeData(testTheme, Brightness.light);
      expect(theme.dialogTheme.elevation, 8.0);
      expect(theme.popupMenuTheme.elevation, FolioElevation.menu);
    });

    test('layers.overlay.shadow = false flattens both dialog and popup '
        'menu elevation — proving they share the overlay layer', () {
      final themed = testTheme.copyWith(
        layers: const ThemeLayerTokens(overlay: LayerStyle(shadow: false)),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      expect(theme.dialogTheme.elevation, 0.0);
      expect(theme.popupMenuTheme.elevation, 0.0);
    });

    test('layers.overlay.shadow = true keeps the same literal magnitude as '
        'the unconfigured default, not a new value', () {
      final themed = testTheme.copyWith(
        layers: const ThemeLayerTokens(overlay: LayerStyle(shadow: true)),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      expect(theme.dialogTheme.elevation, 8.0);
      expect(theme.popupMenuTheme.elevation, FolioElevation.menu);
    });
  });

  group('VisualStyle (Fase 20) — density/glass/border/window/cursor/icons', () {
    test('unconfigured visualStyle preserves compact VisualDensity(-1,-1) '
        '(parity)', () {
      final theme = resolveThemeData(testTheme, Brightness.light);
      expect(theme.visualDensity, const VisualDensity(horizontal: -1, vertical: -1));
    });

    test('densityMode comfortable/spacious map to (0,0)/(1,1)', () {
      final comfortable = resolveThemeData(
        testTheme.copyWith(
          visualStyle: const VisualStyle(densityMode: 'comfortable'),
        ),
        Brightness.light,
      );
      expect(comfortable.visualDensity, const VisualDensity(horizontal: 0, vertical: 0));

      final spacious = resolveThemeData(
        testTheme.copyWith(visualStyle: const VisualStyle(densityMode: 'spacious')),
        Brightness.light,
      );
      expect(spacious.visualDensity, const VisualDensity(horizontal: 1, vertical: 1));
    });

    test('unconfigured glassDialogOpacity falls back to surfaceOpacity '
        '(parity with pre-Fase-20 behavior)', () {
      final themed = testTheme.copyWith(surfaceOpacity: 0.65);
      final theme = resolveThemeData(themed, Brightness.light);
      expect(theme.dialogTheme.backgroundColor?.a, closeTo(0.65, 0.001));
    });

    test('a configured glassDialogOpacity overrides the global surfaceOpacity '
        'just for the dialog', () {
      final themed = testTheme.copyWith(
        surfaceOpacity: 1.0,
        visualStyle: const VisualStyle(
          glassDialogOpacity: TokenRef.literal(0.5),
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      expect(theme.dialogTheme.backgroundColor?.a, closeTo(0.5, 0.001));
      // card no configurado sigue en el surfaceOpacity global (1.0).
      expect(theme.cardTheme.color?.a, 1.0);
    });

    test('unconfigured iconSize leaves the Material-derived IconThemeData '
        'untouched (parity)', () {
      final base = resolveThemeData(testTheme, Brightness.light);
      final withNullStyle = resolveThemeData(
        testTheme.copyWith(visualStyle: const VisualStyle()),
        Brightness.light,
      );
      expect(withNullStyle.iconTheme.size, base.iconTheme.size);
    });

    test('a configured iconSize is applied to ThemeData.iconTheme', () {
      final themed = testTheme.copyWith(
        visualStyle: const VisualStyle(iconSize: TokenRef.literal(30)),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      expect(theme.iconTheme.size, 30);
    });
  });

  group('ThemeMotionTokens animation flags (Fase 21)', () {
    test('unconfigured motion.enabled/pageTransitionsEnabled (both default '
        'true) reproduces the FadeForwards builder map (parity)', () {
      final theme = resolveThemeData(testTheme, Brightness.light);
      final builder = theme.pageTransitionsTheme.builders[TargetPlatform.windows];
      expect(builder, isA<FadeForwardsPageTransitionsBuilder>());
    });

    test('motion.enabled = false swaps in the instant (no-op) transition '
        'builder', () {
      final themed = testTheme.copyWith(
        motion: ThemeMotionTokens(
          shortMs: testTheme.motion.shortMs,
          short2Ms: testTheme.motion.short2Ms,
          mediumMs: testTheme.motion.mediumMs,
          themeChangeMs: testTheme.motion.themeChangeMs,
          curveName: testTheme.motion.curveName,
          enabled: false,
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      final builder = theme.pageTransitionsTheme.builders[TargetPlatform.windows];
      expect(builder, isNot(isA<FadeForwardsPageTransitionsBuilder>()));
    });

    test('motion.pageTransitionsEnabled = false alone also swaps the '
        'builder, independent of motion.enabled', () {
      final themed = testTheme.copyWith(
        motion: ThemeMotionTokens(
          shortMs: testTheme.motion.shortMs,
          short2Ms: testTheme.motion.short2Ms,
          mediumMs: testTheme.motion.mediumMs,
          themeChangeMs: testTheme.motion.themeChangeMs,
          curveName: testTheme.motion.curveName,
          pageTransitionsEnabled: false,
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      final builder = theme.pageTransitionsTheme.builders[TargetPlatform.windows];
      expect(builder, isNot(isA<FadeForwardsPageTransitionsBuilder>()));
    });
  });

  group('AccessibilityConfig (Fase 22) — optional trailing param', () {
    test('omitting the accessibility argument entirely preserves today\'s '
        'exact output (golden parity)', () {
      final withoutArg = resolveThemeData(testTheme, Brightness.light);
      final withNullArg = resolveThemeData(
        testTheme,
        Brightness.light,
        accessibility: null,
      );
      expect(withoutArg.colorScheme, withNullArg.colorScheme);
      expect(
        withoutArg.iconButtonTheme.style?.minimumSize?.resolve({}),
        withNullArg.iconButtonTheme.style?.minimumSize?.resolve({}),
      );
    });

    test('accessibility.largeHitTargets = true grows the iconButton '
        'minimumSize', () {
      final theme = resolveThemeData(
        testTheme,
        Brightness.light,
        accessibility: AccessibilityConfig(largeHitTargets: true),
      );
      expect(
        theme.iconButtonTheme.style?.minimumSize?.resolve({}),
        const Size(56, 56),
      );
    });

    test('accessibility.reduceMotion = true swaps in the instant page '
        'transition builder, same mechanism as motion.enabled', () {
      final theme = resolveThemeData(
        testTheme,
        Brightness.light,
        accessibility: AccessibilityConfig(reduceMotion: true),
      );
      final builder = theme.pageTransitionsTheme.builders[TargetPlatform.windows];
      expect(builder, isNot(isA<FadeForwardsPageTransitionsBuilder>()));
    });

    test('accessibility.contrast = high changes the resolved colorScheme', () {
      final theme = resolveThemeData(
        testTheme,
        Brightness.light,
        accessibility: AccessibilityConfig(contrast: 'high'),
      );
      final base = resolveThemeData(testTheme, Brightness.light);
      expect(theme.colorScheme.onSurfaceVariant, isNot(base.colorScheme.onSurfaceVariant));
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

  group('surfaceOpacity / shadowOpacity / baseSizeScale', () {
    test('baseSizeScale scales textTheme font sizes', () {
      final scaled = testTheme.copyWith(
        typography: ThemeTypographyTokens(fontFamily: 'Roboto', baseSizeScale: 1.1),
      );
      final theme = resolveThemeData(scaled, Brightness.light);
      // Con scale ≠ 1 el resolver fusiona Typography.englishLike y aplica
      // fontSizeFactor; el tamaño esperado es el M3 geometry × 1.1.
      final geometrySize =
          Typography.material2021().englishLike.titleLarge?.fontSize;
      expect(geometrySize, isNotNull);
      expect(
        theme.textTheme.titleLarge?.fontSize,
        closeTo(geometrySize! * 1.1, 0.01),
      );
    });

    test('ThemeData.lerp between Georgia pack and scaled Outfit does not throw', () {
      // Regresión: AnimatedTheme crasheaba al cruzar packs con
      // apply(fontFamily) (inherit:true) y englishLike+scale (inherit:false).
      // Ambos usan fontFamily explícito para no tocar GoogleFonts en test.
      final georgia = resolveThemeData(
        testTheme.copyWith(
          typography: ThemeTypographyTokens(fontFamily: 'Georgia'),
        ),
        Brightness.dark,
      );
      final scaled = resolveThemeData(
        testTheme.copyWith(
          typography: ThemeTypographyTokens(
            fontFamily: 'Roboto',
            baseSizeScale: 1.03,
          ),
        ),
        Brightness.dark,
      );
      expect(georgia.textTheme.displayLarge?.inherit, isFalse);
      expect(scaled.textTheme.displayLarge?.inherit, isFalse);
      expect(() => ThemeData.lerp(georgia, scaled, 0.5), returnsNormally);
    });

    test('shadowOpacity paints ThemeData.shadowColor', () {
      final themed = testTheme.copyWith(
        elevation: ThemeElevationTokens(
          none: testTheme.elevation.none,
          appBarScrolled: testTheme.elevation.appBarScrolled,
          menu: testTheme.elevation.menu,
          shadowOpacity: 0.4,
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      expect(theme.shadowColor.a, closeTo(0.4, 0.001));
    });

    test('surfaceOpacity < 1 applies alpha to card background', () {
      final themed = testTheme.copyWith(surfaceOpacity: 0.65);
      final theme = resolveThemeData(themed, Brightness.light);
      expect(theme.cardTheme.color?.a, closeTo(0.65, 0.001));
      expect(theme.dialogTheme.backgroundColor?.a, closeTo(0.65, 0.001));
    });

    test('surfaceOpacity 1 keeps opaque card color (parity)', () {
      final theme = resolveThemeData(testTheme, Brightness.light);
      expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerLow);
      expect(theme.cardTheme.color?.a, 1.0);
    });
  });

  group('FolioSemanticColors extension (Fase 14)', () {
    test('is always attached, deriving from ColorScheme when unconfigured', () {
      final theme = resolveThemeData(testTheme, Brightness.light);
      final semantic = theme.extension<FolioSemanticColors>();
      expect(semantic, isNotNull);
      expect(semantic!.cardBackground, theme.colorScheme.surfaceContainerLow);
    });

    test('a configured literal override is reflected in the extension', () {
      final themed = testTheme.copyWith(
        semanticColors: const SemanticColorTokens(
          sidebarBackground: TokenRef.literal(0xFF112233),
        ),
      );
      final theme = resolveThemeData(themed, Brightness.light);
      final semantic = theme.extension<FolioSemanticColors>()!;
      expect(semantic.sidebarBackground, const Color(0xFF112233));
    });
  });
}
