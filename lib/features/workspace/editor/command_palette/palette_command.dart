import 'package:flutter/widgets.dart';

/// Fase C1 del rediseño UX del editor — modelo del Command Palette (Ctrl+K).
/// Deliberadamente acotado, no un sistema de plugin-SDK genérico en v1: un
/// comando es un `id`/`label`/categoría/icono/acción, sin metadata extra.
enum PaletteCommandCategory {
  navigation,
  create,
  format,
  ai,
  settings,
  plugin,
}

class PaletteCommand {
  const PaletteCommand({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    this.hint = '',
    this.shortcutLabel,
    required this.execute,
    this.isAvailable,
  });

  final String id;
  final String label;
  final PaletteCommandCategory category;
  final IconData icon;
  final String hint;

  /// Texto del atajo de teclado a mostrar (ej. "Ctrl+D"), si tiene uno.
  final String? shortcutLabel;

  final VoidCallback execute;

  /// `null` = siempre disponible. Se evalúa en el momento de resolver el
  /// registro (Fase C1's `PaletteCommandRegistry.resolve`), no al registrar
  /// — permite que un comando aparezca/desaparezca según el estado actual
  /// (ej. "deshacer" solo si hay algo que deshacer).
  final bool Function()? isAvailable;

  bool get isCurrentlyAvailable => isAvailable?.call() ?? true;
}
