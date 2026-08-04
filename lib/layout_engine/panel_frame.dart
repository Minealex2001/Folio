import 'package:flutter/material.dart';

import '../config/models/panel_config.dart';
import 'drag_resize/resize_handle.dart';
import 'layout_engine_controller.dart';

/// Chrome de una región de panel: `RepaintBoundary` (aísla repintados
/// durante drag/resize de esta región del resto del shell — ver Fase 9),
/// handles de resize por borde (deshabilitados si el panel está bloqueado),
/// y — para paneles flotantes — una franja de arrastre.
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.regionId,
    required this.controller,
    required this.child,
    this.resizableEdges = const {},
    this.draggable = false,
    this.dragHandleHeight = 7,
    this.effectivePanel,
  });

  final String regionId;
  final LayoutEngineController controller;
  final Widget child;
  final Set<PanelResizeEdge> resizableEdges;
  final bool draggable;
  final double dragHandleHeight;

  /// Panel ya resuelto por breakpoint (Fase 7, `ResponsiveLayoutResolver`)
  /// para decidir `locked`/chrome — si es null, se usa
  /// `controller.panelFor(regionId)` (el panel base, sin overrides).
  /// El drag/resize sigue mutando siempre el panel base vía [controller],
  /// independientemente de este valor.
  final PanelConfig? effectivePanel;

  @override
  Widget build(BuildContext context) {
    final panel = effectivePanel ?? controller.panelFor(regionId);
    final locked = panel?.locked ?? false;

    Widget content = RepaintBoundary(child: child);

    if (draggable && !locked) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              final current = controller.panelFor(regionId);
              if (current == null) return;
              final baseX = current.floatingX ?? 0;
              final baseY = current.floatingY ?? 0;
              controller.setFloatingPosition(
                regionId,
                baseX + details.delta.dx,
                baseY + details.delta.dy,
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox(
                height: dragHandleHeight,
                child: ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    if (locked || resizableEdges.isEmpty) {
      return content;
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (resizableEdges.contains(PanelResizeEdge.right))
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: PanelResizeHandle(
              edge: PanelResizeEdge.right,
              onDelta: (d) =>
                  controller.resizeByDelta(regionId, d, axis: Axis.horizontal),
            ),
          ),
        if (resizableEdges.contains(PanelResizeEdge.left))
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: PanelResizeHandle(
              edge: PanelResizeEdge.left,
              onDelta: (d) =>
                  controller.resizeByDelta(regionId, d, axis: Axis.horizontal),
            ),
          ),
        if (resizableEdges.contains(PanelResizeEdge.bottom))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PanelResizeHandle(
              edge: PanelResizeEdge.bottom,
              onDelta: (d) =>
                  controller.resizeByDelta(regionId, d, axis: Axis.vertical),
            ),
          ),
        if (resizableEdges.contains(PanelResizeEdge.top))
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: PanelResizeHandle(
              edge: PanelResizeEdge.top,
              onDelta: (d) =>
                  controller.resizeByDelta(regionId, d, axis: Axis.vertical),
            ),
          ),
      ],
    );
  }
}
