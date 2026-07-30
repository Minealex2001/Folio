import 'package:flutter/material.dart';

/// Paleta Folio Cloud status:
/// degradado → amarillo, caída parcial → naranja, caída total → rojo.
abstract final class FolioCloudStatusColors {
  static const Color ok = Color(0xFF2E9E6A);
  static const Color degraded = Color(0xFFE6C200);
  static const Color partial = Color(0xFFF08A24);
  static const Color down = Color(0xFFE24B4B);

  static Color foreground(String status) {
    return switch (status) {
      'ok' => ok,
      'degraded' => degraded,
      'partial' => partial,
      'down' => down,
      _ => const Color(0xFF9AA0A6),
    };
  }

  /// Fondo tintado para banner / chips.
  static Color container(String status, {required Brightness brightness}) {
    final base = foreground(status);
    final surface =
        brightness == Brightness.dark ? const Color(0xFF1C1C1C) : const Color(0xFFF7F7F7);
    return Color.alphaBlend(base.withValues(alpha: 0.28), surface);
  }

  static Color onContainer(String status, {required Brightness brightness}) {
    final base = foreground(status);
    if (brightness == Brightness.dark) {
      return Color.lerp(base, Colors.white, 0.35)!;
    }
    return Color.lerp(base, Colors.black, 0.45)!;
  }
}
