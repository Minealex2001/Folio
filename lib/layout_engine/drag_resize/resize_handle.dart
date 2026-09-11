import 'package:flutter/material.dart';

/// Borde de una región por el que se puede redimensionar.
enum PanelResizeEdge { left, right, top, bottom }

/// Handle de resize por borde — generalización del `MouseRegion` +
/// `GestureDetector` de 6-7px hardcodeado hoy en `workspace_shell.dart`
/// (sidebar/AI/collab), ahora parametrizado por [edge] y reutilizable desde
/// cualquier [PanelFrame]. `onDelta` recibe el delta ya orientado (positivo
/// = crecer el panel), independientemente del borde.
class PanelResizeHandle extends StatelessWidget {
  const PanelResizeHandle({
    super.key,
    required this.edge,
    required this.onDelta,
    this.onDragStart,
    this.onDragEnd,
    this.thickness = 6,
    this.color,
    this.semanticLabel,
    this.semanticHint,
  });

  final PanelResizeEdge edge;
  final ValueChanged<double> onDelta;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double thickness;
  final Color? color;
  final String? semanticLabel;
  final String? semanticHint;

  bool get _horizontal =>
      edge == PanelResizeEdge.left || edge == PanelResizeEdge.right;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final handle = MouseRegion(
      cursor: _horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _horizontal ? (_) => onDragStart?.call() : null,
        onHorizontalDragEnd: _horizontal ? (_) => onDragEnd?.call() : null,
        onHorizontalDragUpdate: _horizontal
            ? (details) => onDelta(
                edge == PanelResizeEdge.right
                    ? details.delta.dx
                    : -details.delta.dx,
              )
            : null,
        onVerticalDragStart: !_horizontal ? (_) => onDragStart?.call() : null,
        onVerticalDragEnd: !_horizontal ? (_) => onDragEnd?.call() : null,
        onVerticalDragUpdate: !_horizontal
            ? (details) => onDelta(
                edge == PanelResizeEdge.bottom
                    ? details.delta.dy
                    : -details.delta.dy,
              )
            : null,
        child: Container(
          width: _horizontal ? thickness : null,
          height: _horizontal ? null : thickness,
          color: color ?? scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
    );
    if (semanticLabel == null) return handle;
    return Semantics(label: semanticLabel, hint: semanticHint, child: handle);
  }
}
