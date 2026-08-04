/// Matemática pura de colocación en el grid de columnas del dashboard —
/// sin dependencia de `package:flutter`, testeable directo. Ancho de
/// columna, mapeo punto→columna (para saber en qué columna soltar un
/// widget arrastrado) y snap de altura a la unidad de fila (al soltar, no
/// en cada frame de drag — mismo principio que `snap_engine.dart`).
abstract final class DashboardGridMath {
  /// Ancho de una columna dado el ancho disponible total, número de
  /// columnas y separación entre ellas ([DashboardConfig.gap]).
  static double columnWidth({
    required double availableWidth,
    required int columns,
    required double gap,
  }) {
    if (columns <= 0) return availableWidth;
    final totalGap = gap * (columns - 1);
    final width = (availableWidth - totalGap) / columns;
    return width < 0 ? 0 : width;
  }

  /// Coordenada x del borde izquierdo de la columna [columnIndex].
  static double columnLeft({
    required int columnIndex,
    required double columnWidth,
    required double gap,
  }) => columnIndex * (columnWidth + gap);

  /// Mapea una coordenada x a un índice de columna, clamp a
  /// `[0, columns - 1]` — usado al soltar un widget arrastrado para saber
  /// en qué columna cae.
  static int columnIndexForX({
    required double x,
    required double columnWidth,
    required double gap,
    required int columns,
  }) {
    if (columns <= 0) return 0;
    final step = columnWidth + gap;
    if (step <= 0) return 0;
    final index = (x / step).floor();
    if (index < 0) return 0;
    if (index > columns - 1) return columns - 1;
    return index;
  }

  /// Redondea [value] al múltiplo de [rowUnit] más cercano — auto-snap de
  /// alto/ancho al soltar un resize.
  static double snapToRowUnit(double value, double rowUnit) {
    if (rowUnit <= 0) return value;
    return (value / rowUnit).roundToDouble() * rowUnit;
  }

  /// Umbral (en fracción del ancho de columna) dentro del cual un drop cerca
  /// del borde entre dos columnas propone crear una columna nueva ahí, en
  /// vez de reordenar dentro de la columna existente. v1: split de un solo
  /// nivel — no hay sub-grids anidados (ver notas de la Fase 5 del plan).
  static const double newColumnSplitThresholdFraction = 0.12;

  /// True si [xWithinColumn] (posición x relativa al borde izquierdo de la
  /// columna, en `[0, columnWidth]`) cae dentro del umbral de "split" cerca
  /// de alguno de sus dos bordes.
  static bool isNearColumnBoundary({
    required double xWithinColumn,
    required double columnWidth,
  }) {
    if (columnWidth <= 0) return false;
    final threshold = columnWidth * newColumnSplitThresholdFraction;
    return xWithinColumn <= threshold ||
        xWithinColumn >= columnWidth - threshold;
  }
}
