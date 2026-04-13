import 'package:flutter/material.dart';

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

Color calloutBackgroundForTone(ColorScheme scheme, BlockCalloutTone tone) {
  switch (tone) {
    case BlockCalloutTone.info:
      return scheme.primaryContainer.withValues(alpha: 0.26);
    case BlockCalloutTone.success:
      return scheme.tertiaryContainer.withValues(alpha: 0.26);
    case BlockCalloutTone.warning:
      return scheme.secondaryContainer.withValues(alpha: 0.34);
    case BlockCalloutTone.danger:
      return scheme.errorContainer.withValues(alpha: 0.3);
    case BlockCalloutTone.neutral:
      return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
  }
}

Color calloutBorderForTone(ColorScheme scheme, BlockCalloutTone tone) {
  switch (tone) {
    case BlockCalloutTone.info:
      return scheme.primary.withValues(alpha: 0.45);
    case BlockCalloutTone.success:
      return scheme.tertiary.withValues(alpha: 0.45);
    case BlockCalloutTone.warning:
      return scheme.secondary.withValues(alpha: 0.5);
    case BlockCalloutTone.danger:
      return scheme.error.withValues(alpha: 0.5);
    case BlockCalloutTone.neutral:
      return scheme.outlineVariant.withValues(alpha: 0.5);
  }
}

Color calloutChipForTone(ColorScheme scheme, BlockCalloutTone tone) {
  switch (tone) {
    case BlockCalloutTone.info:
      return scheme.primaryContainer.withValues(alpha: 0.75);
    case BlockCalloutTone.success:
      return scheme.tertiaryContainer.withValues(alpha: 0.75);
    case BlockCalloutTone.warning:
      return scheme.secondaryContainer.withValues(alpha: 0.85);
    case BlockCalloutTone.danger:
      return scheme.errorContainer.withValues(alpha: 0.85);
    case BlockCalloutTone.neutral:
      return scheme.surfaceContainerHighest.withValues(alpha: 0.85);
  }
}
