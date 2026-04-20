import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/folio_canvas_data.dart';

/// Pinta las flechas/conectores entre nodos del lienzo.
class CanvasEdgePainter extends CustomPainter {
  const CanvasEdgePainter({
    required this.edges,
    required this.nodes,
  });

  final List<FolioCanvasEdge> edges;
  final List<FolioCanvasNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeById = {for (final n in nodes) n.id: n};

    for (final edge in edges) {
      final from = nodeById[edge.fromNodeId];
      final to = nodeById[edge.toNodeId];
      if (from == null || to == null) continue;

      final color = _parseColor(edge.color) ?? Colors.blueGrey;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final fromCenter = Offset(from.x + from.width / 2, from.y + from.height / 2);
      final toCenter = Offset(to.x + to.width / 2, to.y + to.height / 2);

      // Punto de salida en el borde del nodo origen
      final fromEdge = _edgePoint(from, toCenter);
      final toEdge = _edgePoint(to, fromCenter);

      switch (edge.style) {
        case CanvasEdgeStyle.straight:
          canvas.drawLine(fromEdge, toEdge, paint);
        case CanvasEdgeStyle.curve:
          final ctrl = Offset(
            (fromEdge.dx + toEdge.dx) / 2,
            (fromEdge.dy + toEdge.dy) / 2 - 60,
          );
          final path = Path()
            ..moveTo(fromEdge.dx, fromEdge.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, toEdge.dx, toEdge.dy);
          canvas.drawPath(path, paint);
          _drawArrowhead(canvas, ctrl, toEdge, color);
        case CanvasEdgeStyle.arrow:
          canvas.drawLine(fromEdge, toEdge, paint);
          _drawArrowhead(canvas, fromEdge, toEdge, color);
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Color color) {
    const arrowSize = 10.0;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - arrowSize * math.cos(angle - 0.4),
        to.dy - arrowSize * math.sin(angle - 0.4),
      )
      ..lineTo(
        to.dx - arrowSize * math.cos(angle + 0.4),
        to.dy - arrowSize * math.sin(angle + 0.4),
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  /// Calcula el punto en el borde del rectángulo del nodo más cercano a [target].
  Offset _edgePoint(FolioCanvasNode node, Offset target) {
    final cx = node.x + node.width / 2;
    final cy = node.y + node.height / 2;
    final dx = target.dx - cx;
    final dy = target.dy - cy;
    if (dx == 0 && dy == 0) return Offset(cx, cy);

    final hw = node.width / 2;
    final hh = node.height / 2;

    final scaleX = hw / dx.abs().clamp(1e-9, double.infinity);
    final scaleY = hh / dy.abs().clamp(1e-9, double.infinity);
    final scale = math.min(scaleX, scaleY);

    return Offset(cx + dx * scale, cy + dy * scale);
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceAll('#', '');
    final v = int.tryParse(clean, radix: 16);
    if (v == null) return null;
    return Color(clean.length == 6 ? (0xFF000000 | v) : v);
  }

  @override
  bool shouldRepaint(covariant CanvasEdgePainter old) =>
      old.edges != edges || old.nodes != nodes;
}
