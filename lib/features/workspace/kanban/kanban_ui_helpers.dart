import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_kanban_data.dart';

/// Etiqueta visible de una columna (título personalizado o texto localizado para ids estándar).
String folioKanbanColumnLabel(
  FolioKanbanColumnSpec spec,
  AppLocalizations l10n,
) {
  final t = spec.title.trim();
  if (t.isNotEmpty) return t;
  return switch (spec.id) {
    'in_progress' => l10n.taskStatusInProgress,
    'done' => l10n.taskStatusDone,
    _ => l10n.taskStatusTodo,
  };
}

/// Color de fondo de chip de estado alineado con el tablero.
Color folioKanbanColumnChipSelectedColor(
  FolioKanbanColumnSpec spec,
  ColorScheme scheme,
) {
  final argb = spec.colorArgb;
  if (argb != null) {
    return Color(argb).withValues(alpha: 0.28);
  }
  return switch (spec.id) {
    'done' => scheme.primaryContainer,
    'in_progress' => scheme.secondaryContainer,
    _ => scheme.surfaceContainerHighest,
  };
}
