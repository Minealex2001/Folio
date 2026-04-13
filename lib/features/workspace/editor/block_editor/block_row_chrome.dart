import 'package:flutter/material.dart';

/// Fila estándar del editor: menú ⋮, asa de arrastre, marcador (viñeta/check) y cuerpo.
class BlockRowChrome extends StatelessWidget {
  const BlockRowChrome({
    super.key,
    required this.depth,
    required this.menuSlot,
    required this.dragHandle,
    required this.marker,
    required this.child,
    this.paddingStart = 28.0,
    this.verticalPadding = 2,
    this.horizontalEnd = 4,
    this.compactReadOnlyMobile = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final int depth;
  final double paddingStart;
  final double verticalPadding;
  final double horizontalEnd;
  final bool compactReadOnlyMobile;
  final CrossAxisAlignment crossAxisAlignment;
  final Widget menuSlot;
  final Widget dragHandle;
  final Widget marker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = depth * (compactReadOnlyMobile ? 16.0 : paddingStart);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        start,
        verticalPadding,
        compactReadOnlyMobile ? 0 : horizontalEnd,
        verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          menuSlot,
          dragHandle,
          marker,
          Expanded(child: child),
        ],
      ),
    );
  }
}
