import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import 'dashboard_grid_controller.dart';
import 'dashboard_grid_math.dart';

/// Chrome de una instancia de widget dentro del grid del dashboard —
/// equivalente de `PanelFrame` (Fase 2) para widgets en vez de paneles:
/// arrastrable (vía `LongPressDraggable`, Flutter nativo — decisión de la
/// Fase 5 del plan para ergonomía táctil, a diferencia del drag a mano de
/// paneles/canvas), resize desde la esquina inferior derecha, y botones de
/// duplicar/eliminar.
class WidgetInstanceFrame extends StatefulWidget {
  const WidgetInstanceFrame({
    super.key,
    required this.instance,
    required this.controller,
    required this.child,
    this.resizable = true,
    this.rowUnit = 32,
  });

  final WidgetInstanceConfig instance;
  final DashboardGridController controller;
  final Widget child;
  final bool resizable;

  /// Unidad de fila para el snap de alto/ancho al soltar el resize.
  final double rowUnit;

  @override
  State<WidgetInstanceFrame> createState() => _WidgetInstanceFrameState();
}

class _WidgetInstanceFrameState extends State<WidgetInstanceFrame> {
  Offset _resizeAccumulator = Offset.zero;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (_hovering)
              Positioned(
                top: 4,
                right: 4,
                child: _InstanceActionsRow(
                  instance: widget.instance,
                  controller: widget.controller,
                ),
              ),
            if (widget.resizable && _hovering)
              Positioned(
                right: 0,
                bottom: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _resizeAccumulator = Offset.zero,
                    onPanUpdate: (details) {
                      _resizeAccumulator += details.delta;
                    },
                    onPanEnd: (_) => _commitResize(),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: Icon(Icons.south_east_rounded, size: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return LongPressDraggable<String>(
      data: widget.instance.instanceId,
      feedback: Material(
        elevation: 6,
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: widget.instance.width ?? 240,
            height: widget.instance.height ?? 160,
            child: widget.child,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );
  }

  void _commitResize() {
    final baseWidth = widget.instance.width ?? 240;
    final baseHeight = widget.instance.height ?? 160;
    final nextWidth = DashboardGridMath.snapToRowUnit(
      (baseWidth + _resizeAccumulator.dx).clamp(80, double.infinity),
      widget.rowUnit,
    );
    final nextHeight = DashboardGridMath.snapToRowUnit(
      (baseHeight + _resizeAccumulator.dy).clamp(80, double.infinity),
      widget.rowUnit,
    );
    widget.controller.resizeInstance(
      widget.instance.instanceId,
      width: nextWidth,
      height: nextHeight,
    );
    _resizeAccumulator = Offset.zero;
  }
}

class _InstanceActionsRow extends StatelessWidget {
  const _InstanceActionsRow({required this.instance, required this.controller});

  final WidgetInstanceConfig instance;
  final DashboardGridController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      shape: const StadiumBorder(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => controller.duplicateInstance(instance.instanceId),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => controller.removeInstance(instance.instanceId),
          ),
        ],
      ),
    );
  }
}
