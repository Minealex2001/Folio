import 'package:flutter/material.dart';

/// Color de acento de marca Folio (Neon Cyan), usado como seed/swatch
/// cuando el modo de acento es [FolioAccentColorMode.folioDefault].
const int kFolioBrandPrimaryArgb = 0xFF00F3FF;

/// Primary neón de la paleta Minealex Games.
const Color kFolioBrandPrimary = Color(kFolioBrandPrimaryArgb);

/// Paleta de marca Folio (Minealex Games / futurista lowpoly).
///
/// Esquemas Material 3 explícitos — no derivados de [ColorScheme.fromSeed] —
/// alineados con los tokens de la web.
abstract final class FolioBrandPalette {
  FolioBrandPalette._();

  // --- Acentos neón (tema oscuro) ---
  static const Color primary = Color(0xFF00F3FF);
  static const Color onPrimary = Color(0xFF000000);
  static const Color primaryContainer = Color(0xFF004F55);
  static const Color onPrimaryContainer = Color(0xFFCCFCFF);

  static const Color secondary = Color(0xFFFF00FF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color secondaryContainer = Color(0xFF550055);
  static const Color onSecondaryContainer = Color(0xFFFFD6FA);

  static const Color tertiary = Color(0xFFCCFF00);
  static const Color onTertiary = Color(0xFF000000);
  static const Color tertiaryContainer = Color(0xFF445500);
  static const Color onTertiaryContainer = Color(0xFFF2FFC4);

  // --- Superficies Deep Space Blue ---
  static const Color surface = Color(0xFF050510);
  static const Color surfaceDim = Color(0xFF020208);
  static const Color surfaceBright = Color(0xFF101025);
  static const Color surfaceContainerLowest = Color(0xFF000000);
  static const Color surfaceContainerLow = Color(0xFF0A0A18);
  static const Color surfaceContainer = Color(0xFF101025);
  static const Color surfaceContainerHigh = Color(0xFF1A1A35);
  static const Color surfaceContainerHighest = Color(0xFF252545);

  static const Color onSurface = Color(0xFFE0E0FF);
  static const Color onSurfaceVariant = Color(0xFFA0A0B0);
  static const Color outline = Color(0xFF505060);
  static const Color outlineVariant = Color(0xFF303040);

  static const Color error = Color(0xFFFF4444);
  static const Color onError = Color(0xFF000000);
  static const Color errorContainer = Color(0xFF7F1D1D);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // --- Tema claro ---
  static const Color lightPrimary = Color(0xFF00A8B5);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFD0F8FF);
  static const Color lightOnPrimaryContainer = Color(0xFF002022);

  static const Color lightSecondary = Color(0xFFB000B5);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFFFD6FA);
  static const Color lightOnSecondaryContainer = Color(0xFF38003A);

  static const Color lightTertiary = Color(0xFF6B8A00);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFF2FFC4);
  static const Color lightOnTertiaryContainer = Color(0xFF1A2200);

  static const Color lightSurface = Color(0xFFE0E0E5);
  static const Color lightSurfaceDim = Color(0xFFD0D0D8);
  static const Color lightSurfaceBright = Color(0xFFF5F5FA);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFE8E8EE);
  static const Color lightSurfaceContainer = Color(0xFFEEEEF5);
  static const Color lightSurfaceContainerHigh = Color(0xFFE4E4EC);
  static const Color lightSurfaceContainerHighest = Color(0xFFDCDCE5);

  static const Color lightOnSurface = Color(0xFF050510);
  static const Color lightOnSurfaceVariant = Color(0xFF404050);
  static const Color lightOutline = Color(0xFF707080);
  static const Color lightOutlineVariant = Color(0xFFC0C0C8);

  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightOnErrorContainer = Color(0xFF410002);

  /// Esquema oscuro de marca (experiencia principal).
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE0E0FF),
    onInverseSurface: Color(0xFF050510),
    inversePrimary: lightPrimary,
    surfaceTint: primary,
  );

  /// Esquema claro de marca.
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: lightPrimary,
    onPrimary: lightOnPrimary,
    primaryContainer: lightPrimaryContainer,
    onPrimaryContainer: lightOnPrimaryContainer,
    secondary: lightSecondary,
    onSecondary: lightOnSecondary,
    secondaryContainer: lightSecondaryContainer,
    onSecondaryContainer: lightOnSecondaryContainer,
    tertiary: lightTertiary,
    onTertiary: lightOnTertiary,
    tertiaryContainer: lightTertiaryContainer,
    onTertiaryContainer: lightOnTertiaryContainer,
    error: lightError,
    onError: lightOnError,
    errorContainer: lightErrorContainer,
    onErrorContainer: lightOnErrorContainer,
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceDim: lightSurfaceDim,
    surfaceBright: lightSurfaceBright,
    surfaceContainerLowest: lightSurfaceContainerLowest,
    surfaceContainerLow: lightSurfaceContainerLow,
    surfaceContainer: lightSurfaceContainer,
    surfaceContainerHigh: lightSurfaceContainerHigh,
    surfaceContainerHighest: lightSurfaceContainerHighest,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
    outlineVariant: lightOutlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2F2F3A),
    onInverseSurface: Color(0xFFE0E0E5),
    inversePrimary: primary,
    surfaceTint: lightPrimary,
  );
}
