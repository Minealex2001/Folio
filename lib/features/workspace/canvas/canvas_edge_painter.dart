import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/folio_canvas_data.dart';

/// Pinta las flechas/conectores entre nodos del lienzo.
class CanvasEdgePainter extends CustomPainter {
  const CanvasEdgePainter({
    required this.edges,
    required this.nodes,
    this.selectedEdgeId,
    this.labelTextStyle,
  });

  final List<FolioCanvasEdge> edges;
  final List<FolioCanvasNode> nodes;
  final String? selectedEdgeId;

  /// Estilo para etiquetas de conector (tamaño/color)
  final TextStyle? labelTextStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeById = {for (final n in nodes) n.id: n};

    for (final edge in edges) {
      final from = nodeById[edge.fromNodeId];
      final to = nodeById[edge.toNodeId];
      if (from == null || to == null) continue;
      if (!from.visible || !to.visible) continue;

      final isSelected = edge.id == selectedEdgeId;
      final color = _parseColor(edge.color) ?? Colors.blueGrey;
      final strokeColor = isSelected ? color.withValues(alpha: 1) : color;
      final paint = Paint()
        ..color = strokeColor
        ..strokeWidth = isSelected ? 3.2 : 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final fromCenter = Offset(from.x + from.width / 2, from.y + from.height / 2);
      final toCenter = Offset(to.x + to.width / 2, to.y + to.height / 2);

      final fromEdge = _edgePoint(from, toCenter);
      final toEdge = _edgePoint(to, fromCenter);

      Path? path;
      Offset dirIntoTip = toEdge - fromEdge;
      if (dirIntoTip.distance < 1e-6) dirIntoTip = const Offset(1, 0);

      switch (edge.style) {
        case CanvasEdgeStyle.straight:
          canvas.drawLine(fromEdge, toEdge, paint);
          dirIntoTip = toEdge - fromEdge;
        case CanvasEdgeStyle.curve:
          final ctrl = Offset(
            (fromEdge.dx + toEdge.dx) / 2,
            (fromEdge.dy + toEdge.dy) / 2 - 60,
          );
          path = Path()
            ..moveTo(fromEdge.dx, fromEdge.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, toEdge.dx, toEdge.dy);
          canvas.drawPath(path, paint);
          dirIntoTip = toEdge - ctrl;
        case CanvasEdgeStyle.arrow:
          canvas.drawLine(fromEdge, toEdge, paint);
          dirIntoTip = toEdge - fromEdge;
        case CanvasEdgeStyle.bezier:
          final cp1 = _bezierControl1(edge, fromEdge, toEdge);
          final cp2 = _bezierControl2(edge, fromEdge, toEdge);
          path = Path()
            ..moveTo(fromEdge.dx, fromEdge.dy)
            ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, toEdge.dx, toEdge.dy);
          canvas.drawPath(path, paint);
          dirIntoTip = toEdge - cp2;
      }

      final drawArrow = edge.style != CanvasEdgeStyle.straight;
      if (drawArrow) {
        if (dirIntoTip.distance < 1e-6) dirIntoTip = const Offset(1, 0);
        final u = dirIntoTip / dirIntoTip.distance;
        _drawArrowhead(canvas, toEdge - u * 12, toEdge, strokeColor);
      }

      if (edge.label.isNotEmpty) {
        _paintLabel(canvas, edge.label, fromEdge, toEdge, path);
      }
    }
  }

  Offset _bezierControl1(FolioCanvasEdge edge, Offset from, Offset to) {
    if (edge.cp1x != null && edge.cp1y != null) {
      return Offset(edge.cp1x!, edge.cp1y!);
    }
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    return Offset(mid.dx - 80, mid.dy - 40);
  }

  Offset _bezierControl2(FolioCanvasEdge edge, Offset from, Offset to) {
    if (edge.cp2x != null && edge.cp2y != null) {
      return Offset(edge.cp2x!, edge.cp2y!);
    }
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    return Offset(mid.dx + 80, mid.dy + 40);
  }

  void _paintLabel(
    Canvas canvas,
    String label,
    Offset fromEdge,
    Offset toEdge,
    Path? path,
  ) {
    final style = labelTextStyle ??
        const TextStyle(
          fontSize: 12,
          color: Colors.black87,
          backgroundColor: Color(0xE6FFFFFF),
        );
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 280);

    late Offset mid;
    late double angle;
    if (path != null) {
      final it = path.computeMetrics().iterator;
      if (it.moveNext()) {
        final metrics = it.current;
        final half = metrics.length * 0.5;
        final tangent = metrics.getTangentForOffset(half);
        if (tangent != null) {
          mid = tangent.position;
          angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
        } else {
          mid = Offset((fromEdge.dx + toEdge.dx) / 2, (fromEdge.dy + toEdge.dy) / 2);
          angle = math.atan2(toEdge.dy - fromEdge.dy, toEdge.dx - fromEdge.dx);
        }
      } else {
        mid = Offset((fromEdge.dx + toEdge.dx) / 2, (fromEdge.dy + toEdge.dy) / 2);
        angle = math.atan2(toEdge.dy - fromEdge.dy, toEdge.dx - fromEdge.dx);
      }
    } else {
      mid = Offset((fromEdge.dx + toEdge.dx) / 2, (fromEdge.dy + toEdge.dy) / 2);
      angle = math.atan2(toEdge.dy - fromEdge.dy, toEdge.dx - fromEdge.dx);
    }

    canvas.save();
    canvas.translate(mid.dx, mid.dy);
    canvas.rotate(angle);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
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
      old.edges != edges ||
      old.nodes != nodes ||
      old.selectedEdgeId != selectedEdgeId ||
      old.labelTextStyle != labelTextStyle;
}
