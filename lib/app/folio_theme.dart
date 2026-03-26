import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui_tokens.dart';

ThemeData folioLightTheme(Color seedColor) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.light,
  );
  return _folioThemeFromBase(base, colorScheme);
}

ThemeData folioDarkTheme(Color seedColor) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.dark,
  );
  return _folioThemeFromBase(base, colorScheme);
}

ThemeData _folioThemeFromBase(ThemeData base, ColorScheme colorScheme) {
  final expressiveText = GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );
  return base.copyWith(
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
      elevation: FolioElevation.none,
      scrolledUnderElevation: FolioElevation.appBarScrolled,
      toolbarHeight: 64,
      backgroundColor: Colors
          .transparent, // Let surface color show through or handle natively
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
        padding: const EdgeInsets.all(FolioSpace.xs),
        minimumSize: const Size(40, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.md),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.xl),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.lg,
              vertical: FolioSpace.sm,
            ),
            elevation: FolioElevation.none,
          ).copyWith(
            elevation: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return 2.0;
              }
              if (states.contains(WidgetState.pressed)) {
                return FolioElevation.none;
              }
              return FolioElevation.none;
            }),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            FolioRadius.xl,
          ), // Pill shape for M3
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(
          horizontal: FolioSpace.lg,
          vertical: FolioSpace.sm,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            FolioRadius.xl,
          ), // Pill shape for M3
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: FolioSpace.md,
          vertical: FolioSpace.xxs,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: FolioElevation.none,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md), // 12
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: FolioAlpha.border,
          ),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FolioSpace.md,
        vertical: FolioSpace.xs,
      ),
      horizontalTitleGap: FolioSpace.sm,
      minLeadingWidth: 40,
      minVerticalPadding: FolioSpace.xs,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.sm),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.xl),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
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
      elevation: FolioElevation.menu,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.lg),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: FolioAlpha.border,
          ),
        ),
      ),
      textStyle: expressiveText.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.sm),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.sm),
      ),
      backgroundColor: colorScheme.surfaceContainerLow,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(FolioRadius.sm),
      ),
      textStyle: expressiveText.bodySmall?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: FolioSpace.sm,
        vertical: FolioSpace.xs,
      ),
      margin: const EdgeInsets.all(FolioSpace.sm),
      waitDuration: FolioMotion.short2,
      preferBelow: false,
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(FolioRadius.sm),
      thickness: WidgetStatePropertyAll(10),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return colorScheme.primary.withValues(alpha: FolioAlpha.thumbHover);
        }
        if (states.contains(WidgetState.hovered)) {
          return colorScheme.onSurfaceVariant.withValues(
            alpha: FolioAlpha.thumbHover,
          );
        }
        return colorScheme.onSurfaceVariant.withValues(alpha: FolioAlpha.thumb);
      }),
      trackColor: WidgetStatePropertyAll(
        colorScheme.surfaceContainerHighest.withValues(alpha: FolioAlpha.track),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.xl),
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
      labelStyle: expressiveText.labelLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: FolioSpace.md,
            vertical: FolioSpace.sm,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FolioRadius.lg),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: FolioAlpha.track,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FolioSpace.md,
        vertical: FolioSpace.sm,
      ),
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
        if (states.contains(WidgetState.focused)) {
          return colorScheme.primary;
        }
        return colorScheme.onSurfaceVariant;
      }),
      suffixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return colorScheme.primary;
        }
        if (states.contains(WidgetState.error)) {
          return colorScheme.error;
        }
        return colorScheme.onSurfaceVariant;
      }),
    ),
  );
}
