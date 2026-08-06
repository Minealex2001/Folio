import 'package:flutter/material.dart';

import '../../../../theme_engine/callout_style_presets.dart';

enum BlockCalloutTone { neutral, info, success, warning, danger }

BlockCalloutTone calloutToneForIcon(String? icon) {
  switch (icon) {
    case '💡':
    case 'ℹ️':
      return BlockCalloutTone.info;
    case '✅':
    case '🎉':
    case '🟢':
      return BlockCalloutTone.success;
    case '⚠️':
    case '🟡':
      return BlockCalloutTone.warning;
    case '🚨':
    case '⛔':
    case '❗':
    case '🔴':
      return BlockCalloutTone.danger;
    default:
      return BlockCalloutTone.neutral;
  }
}

/// [preset] modula el alfa base (Fase 27) — `kCalloutStyleNotion` (default)
/// tiene `backgroundAlphaScale: 1.0`, así que sin pasar preset el resultado
/// es idéntico al literal de hoy.
Color calloutBackgroundForTone(
  ColorScheme scheme,
  BlockCalloutTone tone, {
  CalloutStylePreset preset = kCalloutStyleNotion,
}) {
  final base = switch (tone) {
    BlockCalloutTone.info => scheme.primaryContainer.withValues(alpha: 0.26),
    BlockCalloutTone.success => scheme.tertiaryContainer.withValues(alpha: 0.26),
    BlockCalloutTone.warning => scheme.secondaryContainer.withValues(alpha: 0.34),
    BlockCalloutTone.danger => scheme.errorContainer.withValues(alpha: 0.3),
    BlockCalloutTone.neutral => scheme.surfaceContainerHighest.withValues(alpha: 0.5),
  };
  return base.withValues(
    alpha: (base.a * preset.backgroundAlphaScale).clamp(0.0, 1.0),
  );
}

/// Igual que [calloutBackgroundForTone]; `preset.showBorder == false`
/// devuelve un color totalmente transparente (el call site sigue pintando
/// un borde, solo que invisible — evita tener que ramificar el call site).
Color calloutBorderForTone(
  ColorScheme scheme,
  BlockCalloutTone tone, {
  CalloutStylePreset preset = kCalloutStyleNotion,
}) {
  if (!preset.showBorder) return Colors.transparent;
  final base = switch (tone) {
    BlockCalloutTone.info => scheme.primary.withValues(alpha: 0.45),
    BlockCalloutTone.success => scheme.tertiary.withValues(alpha: 0.45),
    BlockCalloutTone.warning => scheme.secondary.withValues(alpha: 0.5),
    BlockCalloutTone.danger => scheme.error.withValues(alpha: 0.5),
    BlockCalloutTone.neutral => scheme.outlineVariant.withValues(alpha: 0.5),
  };
  return base.withValues(
    alpha: (base.a * preset.borderAlphaScale).clamp(0.0, 1.0),
  );
}

Color calloutChipForTone(
  ColorScheme scheme,
  BlockCalloutTone tone, {
  CalloutStylePreset preset = kCalloutStyleNotion,
}) {
  final base = switch (tone) {
    BlockCalloutTone.info => scheme.primaryContainer.withValues(alpha: 0.75),
    BlockCalloutTone.success => scheme.tertiaryContainer.withValues(alpha: 0.75),
    BlockCalloutTone.warning => scheme.secondaryContainer.withValues(alpha: 0.85),
    BlockCalloutTone.danger => scheme.errorContainer.withValues(alpha: 0.85),
    BlockCalloutTone.neutral => scheme.surfaceContainerHighest.withValues(alpha: 0.85),
  };
  return base.withValues(
    alpha: (base.a * preset.chipAlphaScale).clamp(0.0, 1.0),
  );
}
