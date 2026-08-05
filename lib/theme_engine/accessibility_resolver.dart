import 'package:flutter/material.dart';

import '../config/models/theme_motion_tokens.dart';

/// Aumenta el contraste de los tonos "variant" (onSurfaceVariant/outline/
/// outlineVariant — los que más se usan para texto secundario y bordes
/// sutiles) empujándolos hacia el extremo de luminosidad opuesto a la
/// superficie, sin tocar los colores primarios/de marca. `contrast ==
/// 'normal'` (default) devuelve [scheme] sin cambios.
ColorScheme applyContrast(ColorScheme scheme, String contrast) {
  if (contrast != 'high') return scheme;

  Color pushContrast(Color c, {required bool towardsDark}) {
    final hsl = HSLColor.fromColor(c);
    final target = towardsDark ? 0.08 : 0.95;
    final nextLightness = towardsDark
        ? (hsl.lightness * 0.4 + target * 0.6)
        : (hsl.lightness * 0.4 + target * 0.6);
    return hsl.withLightness(nextLightness.clamp(0.0, 1.0)).toColor();
  }

  final isDark = scheme.brightness == Brightness.dark;
  return scheme.copyWith(
    onSurfaceVariant: pushContrast(scheme.onSurfaceVariant, towardsDark: !isDark),
    outline: pushContrast(scheme.outline, towardsDark: !isDark),
    outlineVariant: pushContrast(scheme.outlineVariant, towardsDark: !isDark),
  );
}

/// Fuerza `motion.enabled = false` cuando [reduceMotion] es true —
/// reutiliza el flag ya introducido en la Fase 21 en vez de inventar un
/// segundo mecanismo de "sin movimiento".
ThemeMotionTokens applyReduceMotion(ThemeMotionTokens motion, bool reduceMotion) {
  if (!reduceMotion) return motion;
  return ThemeMotionTokens(
    shortMs: motion.shortMs,
    short2Ms: motion.short2Ms,
    mediumMs: motion.mediumMs,
    themeChangeMs: motion.themeChangeMs,
    curveName: motion.curveName,
    enabled: false,
    pageTransitionsEnabled: motion.pageTransitionsEnabled,
    hoverEnabled: motion.hoverEnabled,
    selectionEffectEnabled: motion.selectionEffectEnabled,
  );
}

/// 56 (grande, WCAG-friendly) cuando `largeHitTargets` está activo, si no
/// el mínimo de Material de hoy (40, ver `iconButtonTheme.minimumSize` en
/// `theme_resolver.dart`).
double minTapTarget(bool largeHitTargets) => largeHitTargets ? 56 : 40;
