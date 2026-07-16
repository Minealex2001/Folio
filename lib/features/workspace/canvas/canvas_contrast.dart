import 'package:flutter/material.dart';

/// Color de primer plano legible sobre [background] (notas, formas, export).
Color canvasTextOnBackground(Color background) {
  if (background.a < 0.12) {
    return const Color(0xDE000000);
  }
  final y = background.computeLuminance();
  return y > 0.42 ? const Color(0xDE000000) : Colors.white;
}

/// Texto secundario (p. ej. placeholder) sobre el mismo fondo.
Color canvasSecondaryTextOnBackground(Color background) {
  final fg = canvasTextOnBackground(background);
  return fg == Colors.white
      ? Colors.white.withValues(alpha: 0.72)
      : Colors.black.withValues(alpha: 0.45);
}
