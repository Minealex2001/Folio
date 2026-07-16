import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../models/folio_canvas_data.dart';
import 'canvas_contrast.dart';
import 'canvas_edge_painter.dart';

/// Límites del contenido (nodos y trazos) en coordenadas del lienzo.
Rect canvasContentBounds(FolioCanvasData data, {double minSize = 320, double padding = 48}) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;

  void acc(double x, double y) {
    minX = minX < x ? minX : x;
    minY = minY < y ? minY : y;
    maxX = maxX > x ? maxX : x;
    maxY = maxY > y ? maxY : y;
  }

  for (final n in data.nodes) {
    if (!n.visible) continue;
    acc(n.x, n.y);
    acc(n.x + n.width, n.y + n.height);
  }
  for (final s in data.strokes) {
    for (final p in s.points) {
      acc(p.x, p.y);
    }
  }

  if (minX.isInfinite) {
    return Rect.fromLTWH(0, 0, minSize + padding * 2, minSize + padding * 2);
  }

  var rect = Rect.fromLTRB(minX, minY, maxX, maxY);
  rect = rect.inflate(padding);
  if (rect.width < minSize) {
    final d = (minSize - rect.width) / 2;
    rect = Rect.fromLTRB(rect.left - d, rect.top, rect.right + d, rect.bottom);
  }
  if (rect.height < minSize) {
    final d = (minSize - rect.height) / 2;
    rect = Rect.fromLTRB(rect.left, rect.top - d, rect.right, rect.bottom + d);
  }
  return rect;
}

/// Rasteriza el lienzo a PNG (fondo blanco).
Future<Uint8List?> canvasToPngBytes(
  FolioCanvasData data, {
  double pixelRatio = 2,
}) async {
  final bounds = canvasContentBounds(data);
  final logicalW = math.max(1, bounds.width.ceil());
  final logicalH = math.max(1, bounds.height.ceil());

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, logicalW.toDouble(), logicalH.toDouble()));

  canvas.drawRect(
    Rect.fromLTWH(0, 0, logicalW.toDouble(), logicalH.toDouble()),
    Paint()..color = Colors.white,
  );

  canvas.save();
  canvas.translate(-bounds.left, -bounds.top);

  const layerSize = Size(10000, 10000);
  CanvasEdgePainter(
    edges: data.edges,
    nodes: data.nodes,
    labelTextStyle: const TextStyle(
      fontSize: 12,
      color: Colors.black87,
      backgroundColor: Color(0xE6FFFFFF),
    ),
  ).paint(canvas, layerSize);

  _paintStrokes(canvas, data.strokes);
  _paintNodes(canvas, data.nodes);

  canvas.restore();

  final picture = recorder.endRecording();
  final img = await picture.toImage(
    (logicalW * pixelRatio).round(),
    (logicalH * pixelRatio).round(),
  );
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd?.buffer.asUint8List();
}

void _paintStrokes(Canvas canvas, List<FolioCanvasStroke> strokes) {
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;
    final hex = stroke.color.replaceAll('#', '');
    final v = int.tryParse(hex, radix: 16);
    var color = v != null
        ? Color(hex.length == 6 ? (0xFF000000 | v) : v)
        : Colors.black;
    if (stroke.kind == FolioCanvasStrokeKind.highlighter) {
      color = color.withValues(alpha: 0.35);
    }
    var w = stroke.strokeWidth;
    if (stroke.pressures != null && stroke.pressures!.isNotEmpty) {
      w = w * (0.5 + stroke.pressures!.reduce((a, b) => a + b) / stroke.pressures!.length);
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final first = stroke.points.first;
    path.moveTo(first.x, first.y);
    for (final p in stroke.points.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    canvas.drawPath(path, paint);
  }
}

void _paintNodes(Canvas canvas, List<FolioCanvasNode> nodes) {
  for (final n in nodes) {
    if (!n.visible) continue;
    final rect = Rect.fromLTWH(n.x, n.y, n.width, n.height);
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(n.rotation);
    canvas.translate(-rect.center.dx, -rect.center.dy);

    switch (n.type) {
      case CanvasNodeType.text:
      case CanvasNodeType.folioBlock:
      case CanvasNodeType.frame:
        var bg = _parseHexColor(n.color) ?? const Color(0xFFFFF9C4);
        if (bg.a < 0.2) bg = const Color(0xFFFFF9C4);
        final fg = canvasTextOnBackground(bg);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(rrect, Paint()..color = bg);
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = Colors.black26
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        final text = n.type == CanvasNodeType.folioBlock
            ? (n.folioBlockText ?? '')
            : n.text;
        final tp = TextPainter(
          text: TextSpan(
            text: text.isEmpty ? ' ' : text,
            style: TextStyle(fontSize: 13, color: fg),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 6,
          ellipsis: '…',
        )..layout(maxWidth: n.width - 16);
        tp.paint(canvas, Offset(n.x + 8, n.y + 8));
      case CanvasNodeType.shape:
        final fill = _parseHexColor(n.color) ?? Colors.blue.shade100;
        _paintShape(canvas, n, fill);
      case CanvasNodeType.image:
        canvas.drawRect(rect, Paint()..color = Colors.grey.shade300);
        final tp = TextPainter(
          text: const TextSpan(text: 'Image', style: TextStyle(fontSize: 11)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.restore();
  }
}

Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  final clean = hex.replaceAll('#', '');
  final v = int.tryParse(clean, radix: 16);
  if (v == null) return null;
  return Color(clean.length == 6 ? (0xFF000000 | v) : v);
}

void _paintShape(Canvas canvas, FolioCanvasNode n, Color fill) {
  final rect = Rect.fromLTWH(n.x, n.y, n.width, n.height);
  final fillPaint = Paint()..color = fill;
  final border = Paint()
    ..color = Colors.black38
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  switch (n.shapeType) {
    case CanvasShapeType.rectangle:
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, border);
    case CanvasShapeType.ellipse:
      canvas.drawOval(rect, fillPaint);
      canvas.drawOval(rect, border);
    case CanvasShapeType.diamond:
      final path = Path()
        ..moveTo(n.x + n.width / 2, n.y)
        ..lineTo(n.x + n.width, n.y + n.height / 2)
        ..lineTo(n.x + n.width / 2, n.y + n.height)
        ..lineTo(n.x, n.y + n.height / 2)
        ..close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, border);
    case CanvasShapeType.triangle:
      final path = Path()
        ..moveTo(n.x + n.width / 2, n.y)
        ..lineTo(n.x + n.width, n.y + n.height)
        ..lineTo(n.x, n.y + n.height)
        ..close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, border);
  }
}

/// SVG simplificado (formas básicas, sin imágenes incrustadas en base64).
String canvasToSvgString(FolioCanvasData data) {
  final b = canvasContentBounds(data, padding: 0);
  final w = b.width.ceil();
  final h = b.height.ceil();
  final ox = -b.left;
  final oy = -b.top;

  final sb = StringBuffer();
  sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  sb.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="0 0 $w $h">',
  );
  sb.writeln('<rect width="100%" height="100%" fill="#ffffff"/>');

  for (final e in data.edges) {
    final from = _firstOrNull(data.nodes.where((n) => n.id == e.fromNodeId));
    final to = _firstOrNull(data.nodes.where((n) => n.id == e.toNodeId));
    if (from == null || to == null || !from.visible || !to.visible) continue;
    final x1 = from.x + from.width / 2 + ox;
    final y1 = from.y + from.height / 2 + oy;
    final x2 = to.x + to.width / 2 + ox;
    final y2 = to.y + to.height / 2 + oy;
    final stroke = e.color ?? '#607D8B';
    sb.writeln(
      '<line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="$stroke" stroke-width="2" marker-end="url(#arrowhead)"/>',
    );
  }
  sb.writeln('''
<defs>
  <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="#607D8B" />
  </marker>
</defs>''');

  for (final s in data.strokes) {
    if (s.points.length < 2) continue;
    final d = StringBuffer('M ${s.points.first.x + ox} ${s.points.first.y + oy}');
    for (final p in s.points.skip(1)) {
      d.write(' L ${p.x + ox} ${p.y + oy}');
    }
    sb.writeln(
      '<path d="$d" fill="none" stroke="${s.color}" stroke-width="${s.strokeWidth}" stroke-linecap="round"/>',
    );
  }

  for (final n in data.nodes) {
    if (!n.visible) continue;
    final x = n.x + ox;
    final y = n.y + oy;
    if (n.type == CanvasNodeType.shape) {
      final fill = n.color ?? '#BBDEFB';
      sb.writeln(
        '<rect x="$x" y="$y" width="${n.width}" height="${n.height}" rx="4" fill="$fill" stroke="#666" stroke-width="1"/>',
      );
    } else {
      final fill = n.color ?? '#FFF9C4';
      sb.writeln(
        '<rect x="$x" y="$y" width="${n.width}" height="${n.height}" rx="6" fill="$fill" stroke="#999" stroke-width="1"/>',
      );
      final label = (n.type == CanvasNodeType.folioBlock ? n.folioBlockText : n.text) ?? '';
      final esc = label
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      sb.writeln(
        '<text x="${x + 8}" y="${y + 20}" font-size="13" fill="#222">$esc</text>',
      );
    }
  }

  sb.writeln('</svg>');
  return sb.toString();
}

T? _firstOrNull<T>(Iterable<T> it) {
  final i = it.iterator;
  if (i.moveNext()) return i.current;
  return null;
}

/// Una página PDF con la imagen del lienzo escalada al tamaño de página.
Future<Uint8List> canvasToPdfBytes(FolioCanvasData data) async {
  final png = await canvasToPngBytes(data, pixelRatio: 2);
  if (png == null) {
    final doc = PdfDocument();
    doc.pages.add();
    return Uint8List.fromList(await doc.save());
  }
  final doc = PdfDocument();
  final page = doc.pages.add();
  final g = page.graphics;
  final size = page.getClientSize();
  final bmp = PdfBitmap(png);
  g.drawImage(bmp, Rect.fromLTWH(0, 0, size.width, size.height));
  return Uint8List.fromList(await doc.save());
}
