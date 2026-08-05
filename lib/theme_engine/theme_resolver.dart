import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/ui_tokens.dart';
import '../config/models/theme_config.dart';
import '../config/models/accessibility_config.dart';
import 'accessibility_resolver.dart';
import 'component_state_resolver.dart';
import 'component_style_resolver.dart';
import 'design_tokens_resolver.dart';
import 'layer_style_resolver.dart';
import 'semantic_colors_resolver.dart';
import 'theme_color_resolver.dart';
import 'visual_style_resolver.dart';

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
  /// Resuelve referencias `@color.xxx`/`@var.xxx` dentro de
  /// [ThemeConfig.semanticColors] (Fase 14) contra [DesignTokens]/
  /// [DesignVariables] persistidos aparte. `null` (default) es exactamente
  /// el comportamiento de hoy: cualquier referencia no resuelta cae al
  /// mismo default derivado de [ColorScheme] que un campo `null`.
  DesignTokensResolver? tokensResolver,
  /// Preferencias de accesibilidad (Fase 22) — categoría propia de
  /// [ConfigStore], no un campo de [ThemeConfig]. `null` (default) es
  /// exactamente el comportamiento de hoy.
  AccessibilityConfig? accessibility,
}) {
  var colorScheme = resolveColorScheme(
    config,
    brightness: brightness,
    androidDynamicAccent: androidDynamicAccent,
  );
  if (accessibility != null) {
    colorScheme = applyContrast(colorScheme, accessibility.contrast);
  }

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
  final motion = accessibility == null
      ? config.motion
      : applyReduceMotion(config.motion, accessibility.reduceMotion);
  final componentStyleResolver = ComponentStyleResolver(
    config.componentStyles,
    shape,
    tokensResolver: tokensResolver,
  );
  final componentStateResolver = ComponentStateResolver(
    config.componentStyles,
    tokensResolver: tokensResolver,
  );
  double radius(String component, double fallback) =>
      componentStyleResolver.radiusFor(component, fallback);

  // Fase 18: `layers == null` (default) preserva las elevaciones literales
  // de hoy (dialog=8.0, popupMenu=elevation.menu) exactamente — solo cuando
  // el usuario configura `layers.overlay` explícitamente, su flag `shadow`
  // decide si diálogo/menú tienen elevación o quedan planos. Caso especial
  // documentado: `shadow: true` no introduce un valor de elevación nuevo,
  // reproduce la magnitud literal que cada componente ya tenía.
  final overlayLayer = config.layers == null
      ? null
      : resolveLayer(config.layers!, 'overlay');
  final overlayHasShadow = overlayLayer?.shadow ?? true;

  // Tipografía: el path por defecto (sin fontFamily override) usa
  // GoogleFonts.outfitTextTheme igual que hoy — reproducir ese TextTheme
  // campo a campo a mano perdería fidelidad (GoogleFonts aplica su propio
  // fontFamilyFallback/altura por estilo). Un fontFamily explícito en
  // ThemeConfig usa TextTheme.apply, que sí es un lookup de datos puro.
  final baseText = config.typography.fontFamily == null
      ? GoogleFonts.outfitTextTheme(base.textTheme)
      : base.textTheme.apply(fontFamily: config.typography.fontFamily);
  var expressiveText = baseText.copyWith(
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

  // Siempre fusionar geometría M3: `apply(fontFamily)` deja inherit:true y
  // Outfit/englishLike dejan inherit:false — AnimatedTheme.lerp crashea al
  // cruzar packs (Paper↔Cozy). englishLike unifica inherit:false + sizes.
  final geometry = Typography.material2021().englishLike;
  expressiveText = geometry.merge(expressiveText);
  final sizeScale = config.typography.baseSizeScale.clamp(0.85, 1.2);
  if ((sizeScale - 1.0).abs() > 0.001) {
    expressiveText = expressiveText.apply(fontSizeFactor: sizeScale);
  }

  final surfaceAlpha = config.surfaceOpacity.clamp(0.0, 1.0);
  Color surfacePaint(Color c) =>
      surfaceAlpha >= 0.999 ? c : c.withValues(alpha: surfaceAlpha);

  // Fase 20: `visualStyle == null` (default) reproduce `VisualDensity(-1,-1)`
  // exactamente. `dialogGlassOpacity` cae a `surfaceAlpha` (el
  // `surfaceOpacity` global de siempre) cuando no está configurado.
  final visualDensity = resolveDensity(config.visualStyle);
  final dialogGlassOpacity = resolveGlassOpacity(
    config.visualStyle,
    'dialog',
    surfaceAlpha,
    tokensResolver: tokensResolver,
  );
  Color dialogPaint(Color c) =>
      dialogGlassOpacity >= 0.999 ? c : c.withValues(alpha: dialogGlassOpacity);

  var themeData = base.copyWith(
    textTheme: expressiveText,
    scaffoldBackgroundColor: colorScheme.surface,
    shadowColor: colorScheme.shadow.withValues(
      alpha: elevation.shadowOpacity.clamp(0.0, 1.0),
    ),
    visualDensity: visualDensity,
    iconTheme: resolveIconTheme(
      config.visualStyle,
      base.iconTheme,
      tokensResolver: tokensResolver,
    ),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    // Fase 21: `enabled && pageTransitionsEnabled` (default true/true, como
    // hoy) reproduce el mapa FadeForwards de siempre; desactivarlo cambia a
    // una transición instantánea en vez de quitar el mapa (que dejaría el
    // zoom-fade por defecto de Material 3, un cambio visible distinto).
    pageTransitionsTheme: (motion.enabled && motion.pageTransitionsEnabled)
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
            },
          )
        : const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _InstantPageTransitionsBuilder(),
              TargetPlatform.linux: _InstantPageTransitionsBuilder(),
              TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
              TargetPlatform.windows: _InstantPageTransitionsBuilder(),
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
        minimumSize: Size.square(minTapTarget(accessibility?.largeHitTargets ?? false)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius('iconButton', shape.radiusMd)),
        ),
        // `null` (sin `states` configurado) preserva el default de hoy:
        // IconButton no pinta fondo propio, solo hoverColor/highlightColor
        // arriba — Fase 17, primer consumidor real de ComponentStateStyle.
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => componentStateResolver.backgroundColorForState(
            'iconButton',
            states,
          ),
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
      color: surfacePaint(colorScheme.surfaceContainerLow),
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
      backgroundColor: dialogPaint(colorScheme.surfaceContainerLow),
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('dialog', shape.radiusXl)),
        // `border: null` (sin configurar) preserva el default de hoy (con
        // borde) — Fase 15, primer consumidor real de ComponentStyleEntry
        // más allá de radio.
        side: (componentStyleResolver.styleFor('dialog')?.border ?? true)
            ? BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      elevation: overlayHasShadow ? 8.0 : 0.0,
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
      elevation: overlayHasShadow ? elevation.menu : 0.0,
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
      backgroundColor: surfacePaint(colorScheme.surfaceContainerLow),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: surfacePaint(colorScheme.surfaceContainerLow),
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius('navigationRail', shape.radiusSm)),
      ),
      backgroundColor: surfacePaint(colorScheme.surfaceContainerLow),
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
        visualDensity: visualDensity,
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

  final semanticColors = resolveSemanticColors(
    config.semanticColors,
    colorScheme,
    tokensResolver: tokensResolver,
  );
  themeData = themeData.copyWith(extensions: [semanticColors]);

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
    case 'easeOutExpo':
      return Curves.easeOutExpo;
    case 'easeOutCubic':
    default:
      return Curves.easeOutCubic;
  }
}

/// Sin transición — el `child` se muestra directamente, ignorando las
/// animaciones de entrada/salida (Fase 21: `motion.enabled: false` /
/// `pageTransitionsEnabled: false`). No hay un builder "sin transición" en
/// el SDK de Flutter con ese nombre exacto, así que se define aquí.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
