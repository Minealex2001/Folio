import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

import '../app/folio_brand_palette.dart';
import '../config/models/theme_config.dart';

/// Semilla de color para un [ThemeConfig] — puerto de
/// `AppSettings.resolveAccentSeedColor` como función pura, operando sobre
/// `config.accentMode`/`config.light.seedArgb` en vez de campos privados de
/// `AppSettings`. `androidDynamicAccent` sigue siendo un parámetro en vez de
/// un dato de `ThemeConfig`: es un valor de Material You leído en runtime
/// (Android 12+ vía `dynamic_color`), no algo persistible como preferencia.
Color resolveAccentSeedColor(
  ThemeConfig config, {
  Color? androidDynamicAccent,
}) {
  switch (config.accentMode) {
    case 'followSystem':
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          androidDynamicAccent != null) {
        return androidDynamicAccent;
      }
      return SystemTheme.accentColor.accent;
    case 'folioDefault':
      return kFolioBrandPrimary;
    case 'custom':
    default:
      // Mismo valor para light/dark hoy (AppSettings solo guarda un ARGB
      // global) — ThemeConfig.fallbackDefault siempre los sincroniza.
      return Color(config.light.seedArgb);
  }
}

/// Resuelve el [ColorScheme] completo — puerto de
/// `AppSettings.resolveColorScheme`.
ColorScheme resolveColorScheme(
  ThemeConfig config, {
  required Brightness brightness,
  Color? androidDynamicAccent,
}) {
  if (config.accentMode == 'folioDefault') {
    return brightness == Brightness.light
        ? FolioBrandPalette.light
        : FolioBrandPalette.dark;
  }
  return ColorScheme.fromSeed(
    seedColor: resolveAccentSeedColor(
      config,
      androidDynamicAccent: androidDynamicAccent,
    ),
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );
}
