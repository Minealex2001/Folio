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
    displayLarge: base.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    displayMedium: base.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
  return base.copyWith(
    textTheme: expressiveText,
    scaffoldBackgroundColor: colorScheme.surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.transparent, // Let surface color show through or handle natively 
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: FolioSpace.md,
          vertical: FolioSpace.sm,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.sm),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(
          horizontal: FolioSpace.md,
          vertical: FolioSpace.sm,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.sm),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      minLeadingWidth: 40,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.lg),
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.sm),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.sm),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FolioRadius.sm),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
  );
}
