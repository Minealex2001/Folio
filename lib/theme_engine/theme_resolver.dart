import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/ui_tokens.dart';
import '../config/models/theme_config.dart';
import 'theme_color_resolver.dart';

/// Resuelve un [ThemeConfig] + [Brightness] a un [ThemeData] completo.
/// Puerto data-driven de `_folioThemeFromBase`/`folioLightTheme`/
/// `folioDarkTheme`/`folioOledTheme` (`lib/app/folio_theme.dart`): cada
/// literal (`FolioRadius.md`, `FolioSpace.lg`, ...) pasa a ser un lookup en
/// los tokens de [config], con el valor de hoy como default en
/// [kFolioDefaultTheme] — así `resolveThemeData(kFolioDefaultTheme, ...)`
/// reproduce exactamente el `ThemeData` actual (verificado en
/// `theme_resolver_test.dart`).
///
/// OLED deja de ser una función aparte (`folioOledTheme`): es un dato
/// (`config.dark.surfaceStyle == 'oled'`) que este resolver aplica como un
/// conjunto de overrides de superficie — nunca una rama `if (theme == oled)`.
ThemeData resolveThemeData(
  ThemeConfig config,
  Brightness brightness, {
  Color? androidDynamicAccent,
}) {
  var colorScheme = resolveColorScheme(
    config,
    brightness: brightness,
    androidDynamicAccent: androidDynamicAccent,
  );

  final isOled = brightness == Brightness.dark && config.dark.isOled;
  if (isOled) {
    colorScheme = colorScheme.copyWith(
      surface: Colors.black,
      surfaceDim: const Color(0xFF000000),
      surfaceBright: const Color(0xFF101010),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF050505),
      surfaceContainer: const Color(0xFF0A0A0A),
      surfaceContainerHigh: const Color(0xFF0F0F0F),
      surfaceContainerHighest: const Color(0xFF141414),
      inverseSurface: const Color(0xFFE6E6E6),
      onInverseSurface: const Color(0xFF111111),
    );
  }

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
  );

  final shape = config.shape;
  final spacing = config.spacing;
  final elevation = config.elevation;
  final motion = config.motion;
  double radius(String component, double fallback) =>
      shape.componentRadiusOverrides?[component] ?? fallback;

  // Tipografía: el path por defecto (sin fontFamily override) usa
  // GoogleFonts.outfitTextTheme igual que hoy — reproducir ese TextTheme
  // campo a campo a mano perdería fidelidad (GoogleFonts aplica su propio
  // fontFamilyFallback/altura por estilo). Un fontFamily explícito en
  // ThemeConfig usa TextTheme.apply, que sí es un lookup de datos puro.
  final baseText = config.typography.fontFamily == null
      ? GoogleFonts.outfitTextTheme(base.textTheme)
      : base.textTheme.apply(fontFamily: config.typography.fontFamily);
  final expressiveText = baseText.copyWith(
    displayLarge: baseText.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    displayMedium: baseText.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: baseText.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  var themeData = base.copyWith(
    textTheme: expressiveText,
    scaffoldBackgroundColor: colorScheme.surface,
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: elevation.none,
      scrolledUnderElevation: elevation.appBarScrolled,
      toolbarHeight: 64,
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
      titleTextStyle: expressiveText.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        hoverColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surfaceContainerHigh,
        padding: EdgeInsets.all(spacing.xs),
        minimumSize: const Size(40, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius('iconButton', shape.radiusMd)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                radius('filledButton', shape.radiusXl),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.sm,
            ),
            elevation: elevation.none,
          ).copyWith(
            elevation: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) return 2.0;
              if (states.contains(WidgetState.pressed)) return elevation.none;
              return elevation.none;
            }),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            radius('outlinedButton', shape.radiusXl),
          ),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.sm,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            radius('textButton', shape.radiusXl),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.xxs,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: elevation.none,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('card', shape.radiusMd)),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: FolioAlpha.border),
        ),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      horizontalTitleGap: spacing.sm,
      minLeadingWidth: 40,
      minVerticalPadding: spacing.xs,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('snackBar', shape.radiusSm)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('dialog', shape.radiusXl)),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      elevation: 8.0,
      alignment: Alignment.center,
      titleTextStyle: expressiveText.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: expressiveText.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        height: 1.5,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainerHigh,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: elevation.menu,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('popupMenu', shape.radiusLg)),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: FolioAlpha.border),
        ),
      ),
      textStyle: expressiveText.bodyMedium?.copyWith(color: colorScheme.onSurface),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('navigationDrawer', shape.radiusSm)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('navigationRail', shape.radiusSm)),
      ),
      backgroundColor: colorScheme.surfaceContainerLow,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(radius('tooltip', shape.radiusSm)),
      ),
      textStyle: expressiveText.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      margin: EdgeInsets.all(spacing.sm),
      waitDuration: Duration(milliseconds: motion.short2Ms),
      preferBelow: false,
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: Radius.circular(radius('scrollbar', shape.radiusSm)),
      thickness: const WidgetStatePropertyAll(10),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return colorScheme.primary.withValues(alpha: FolioAlpha.thumbHover);
        }
        if (states.contains(WidgetState.hovered)) {
          return colorScheme.onSurfaceVariant.withValues(alpha: FolioAlpha.thumbHover);
        }
        return colorScheme.onSurfaceVariant.withValues(alpha: FolioAlpha.thumb);
      }),
      trackColor: WidgetStatePropertyAll(
        colorScheme.surfaceContainerHighest.withValues(alpha: FolioAlpha.track),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('chip', shape.radiusXl)),
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
      labelStyle: expressiveText.labelLarge?.copyWith(color: colorScheme.onSurface),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              radius('segmentedButton', shape.radiusLg),
            ),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: FolioAlpha.track),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius('input', shape.radiusMd)),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius('input', shape.radiusMd)),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius('input', shape.radiusMd)),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius('input', shape.radiusMd)),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius('input', shape.radiusMd)),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      helperStyle: expressiveText.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        height: 1.3,
      ),
      errorStyle: expressiveText.bodySmall?.copyWith(
        color: colorScheme.error,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      labelStyle: expressiveText.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return colorScheme.primary;
        return colorScheme.onSurfaceVariant;
      }),
      suffixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return colorScheme.primary;
        if (states.contains(WidgetState.error)) return colorScheme.error;
        return colorScheme.onSurfaceVariant;
      }),
    ),
  );

  if (isOled) {
    themeData = themeData.copyWith(scaffoldBackgroundColor: Colors.black);
  }

  return themeData;
}

/// Resuelve el nombre de curva guardado en [ThemeMotionTokens.curveName] a
/// un [Curve] real. `ThemeData` no tiene un slot de "curva por defecto" que
/// sustituir en [resolveThemeData], pero paneles/dashboard (Fase 2/5/9) sí
/// leen `ThemeConfig.motion` directamente para sus propias animaciones — se
/// expone aquí para que ese código no reimplemente el mapeo.
Curve resolveMotionCurve(String curveName) {
  switch (curveName) {
    case 'linear':
      return Curves.linear;
    case 'easeOut':
      return Curves.easeOut;
    case 'easeIn':
      return Curves.easeIn;
    case 'easeInOut':
      return Curves.easeInOut;
    case 'easeOutCubic':
    default:
      return Curves.easeOutCubic;
  }
}
