import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';
import 'graph_layout.dart';
import 'graph_model.dart';

/// Pantalla de vista de grafo: muestra las páginas como nodos y sus
/// enlaces internos y jerarquía de carpetas como aristas.
class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({
    super.key,
    required this.session,
    required this.appSettings,
    required this.onOpenPage,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final void Function(String pageId) onOpenPage;

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> {
  static const double _fontSize = 10.0;
  static const double _maxCanvasSide = 14000.0;
  static const double _minCanvasSide = 400.0;
  static const double _minScale = 0.015;
  static const double _tapSlop = 6.0;

  List<_GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  final Map<String, int> _nodeIndex = {};
  bool _includeOrphans = true;
  bool _building = true;
  String? _hoveredNodeId;
  String? _draggingNodeId;
  int _buildGeneration = 0;
  /// Bumps on drag so [CustomPaint] repaints despite in-place position mutation.
  int _paintEpoch = 0;

  /// Frozen after layout so dragging does not re-center the canvas.
  Offset _nodeOffset = Offset.zero;
  double _canvasW = _minCanvasSide;
  double _canvasH = _minCanvasSide;

  late final TransformationController _tc = TransformationController();

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _buildGraph() async {
    final generation = ++_buildGeneration;
    setState(() => _building = true);

    final graphData = buildVaultGraph(
      pages: widget.session.pages,
      backlinkPagesFor: widget.session.backlinkPagesFor,
      includeOrphans: _includeOrphans,
    );

    final layout = await computeGraphLayout(
      GraphLayoutInput(
        nodes: [
          for (final n in graphData.nodes)
            GraphLayoutNodeSeed(
              id: n.id,
              label: n.label,
              isFolder: n.isFolder,
              emoji: n.emoji,
            ),
        ],
        edges: [
          for (final e in graphData.edges)
            GraphLayoutEdgeSeed(
              fromId: e.fromId,
              toId: e.toId,
              isHierarchy: e.kind == GraphEdgeKind.hierarchy,
            ),
        ],
      ),
    );
    if (!mounted || generation != _buildGeneration) return;

    final colorGroupById = {
      for (final n in graphData.nodes) n.id: n.colorGroupId,
    };
    final fallback = Theme.of(context).colorScheme.primaryContainer;
    final nodes = [
      for (final n in layout.nodes)
        _GraphNode(
          id: n.id,
          label: n.label,
          isFolder: n.isFolder,
          emoji: n.emoji,
          pos: Offset(n.x, n.y),
          color: _colorForGroup(colorGroupById[n.id], fallback: fallback),
          degree: n.degree,
          radius: _radiusFor(isFolder: n.isFolder, degree: n.degree),
        ),
    ];

    final size = MediaQuery.sizeOf(context);
    final viewportW = size.width;
    final viewportH = math.max(size.height - 120, _minCanvasSide);
    final metrics = _computeCanvasMetrics(
      nodes,
      viewportW: viewportW,
      viewportH: viewportH,
    );

    setState(() {
      _nodes = nodes;
      _nodeIndex
        ..clear()
        ..addEntries([
          for (var i = 0; i < nodes.length; i++) MapEntry(nodes[i].id, i),
        ]);
      _edges = graphData.edges;
      _nodeOffset = metrics.offset;
      _canvasW = metrics.width;
      _canvasH = metrics.height;
      _building = false;
      _hoveredNodeId = null;
      _draggingNodeId = null;
      _tc.value = _fitTransform(
        canvasW: metrics.width,
        canvasH: metrics.height,
        viewportW: viewportW,
        viewportH: viewportH,
      );
    });
  }

  /// Zoom out enough to fit the canvas in the viewport (with a bit of margin).
  Matrix4 _fitTransform({
    required double canvasW,
    required double canvasH,
    required double viewportW,
    required double viewportH,
  }) {
    if (canvasW <= 0 || canvasH <= 0 || viewportW <= 0 || viewportH <= 0) {
      return Matrix4.identity();
    }
    final scale = (math.min(viewportW / canvasW, viewportH / canvasH) * 0.92)
        .clamp(_minScale, 1.0);
    final dx = (viewportW - canvasW * scale) / 2;
    final dy = (viewportH - canvasH * scale) / 2;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  ({double width, double height, Offset offset}) _computeCanvasMetrics(
    List<_GraphNode> nodes, {
    required double viewportW,
    required double viewportH,
  }) {
    final bounds = _safeBounds(nodes);
    final contentW = bounds.max.dx - bounds.min.dx + 240;
    final contentH = bounds.max.dy - bounds.min.dy + 240;
    final graphW = contentW.clamp(_minCanvasSide, _maxCanvasSide).toDouble();
    final graphH = contentH.clamp(_minCanvasSide, _maxCanvasSide).toDouble();
    final canvasW = math
        .max(graphW, viewportW)
        .clamp(_minCanvasSide, _maxCanvasSide)
        .toDouble();
    final canvasH = math
        .max(graphH, viewportH)
        .clamp(_minCanvasSide, _maxCanvasSide)
        .toDouble();
    final dx = (canvasW - contentW) / 2 - bounds.min.dx + 120;
    final dy = (canvasH - contentH) / 2 - bounds.min.dy + 120;
    return (
      width: canvasW,
      height: canvasH,
      offset: Offset(dx.isFinite ? dx : 0, dy.isFinite ? dy : 0),
    );
  }

  String? _hitTestNode(Offset local) {
    for (var i = _nodes.length - 1; i >= 0; i--) {
      final node = _nodes[i];
      final center = node.pos + _nodeOffset;
      final hitR = node.radius + (node.isFolder ? 6.0 : 4.0);
      final dx = local.dx - center.dx;
      final dy = local.dy - center.dy;
      if (dx * dx + dy * dy <= hitR * hitR) return node.id;
    }
    return null;
  }

  void _moveNodeTo(String id, Offset localCanvasPos) {
    final idx = _nodeIndex[id];
    if (idx == null) return;
    final next = localCanvasPos - _nodeOffset;
    if (!next.dx.isFinite || !next.dy.isFinite) return;
    _nodes[idx].pos = next;
  }

  void _openNode(String id) {
    Navigator.of(context).pop();
    widget.onOpenPage(id);
  }

  /// Color estable pseudoaleatorio por carpeta (hash del id).
  static Color _colorForGroup(String? groupId, {required Color fallback}) {
    if (groupId == null || groupId.isEmpty) return fallback;
    final hash = groupId.hashCode;
    final hue = (hash & 0x7fffffff) % 360;
    final sat = 0.48 + ((hash >> 9) & 0xff) / 255.0 * 0.28;
    final light = 0.40 + ((hash >> 17) & 0xff) / 255.0 * 0.22;
    return HSLColor.fromAHSL(1, hue.toDouble(), sat, light).toColor();
  }

  static double _radiusFor({required bool isFolder, required int degree}) {
    if (isFolder) {
      return (16.0 + 6.0 * math.log(1 + degree)).clamp(16.0, 42.0);
    }
    return (4.5 + 2.2 * math.log(1 + degree)).clamp(4.5, 12.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dragging = _draggingNodeId != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.graphViewTitle),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendItem(
                  lineStyle: _LegendLineStyle.solid,
                  label: l10n.graphViewLegendLink,
                  color: scheme.outline.withValues(alpha: 0.45),
                  strokeWidth: 1.0,
                ),
                const SizedBox(width: 12),
                _LegendItem(
                  lineStyle: _LegendLineStyle.solid,
                  label: l10n.graphViewLegendHierarchy,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  strokeWidth: 2.0,
                ),
              ],
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.graphViewIncludeOrphans,
                style: const TextStyle(fontSize: 13),
              ),
              Switch(
                value: _includeOrphans,
                onChanged: _building
                    ? null
                    : (v) {
                        setState(() => _includeOrphans = v);
                        _buildGraph();
                      },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: _building
          ? const Center(child: CircularProgressIndicator())
          : _nodes.isEmpty
          ? Center(
              child: Text(
                l10n.graphViewEmpty,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : InteractiveViewer(
              transformationController: _tc,
              constrained: false,
              // Disable pan/zoom while dragging a node so gestures don't fight.
              panEnabled: !dragging,
              scaleEnabled: !dragging,
              minScale: _minScale,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(800),
              child: SizedBox(
                width: _canvasW,
                height: _canvasH,
                child: MouseRegion(
                  cursor: dragging
                      ? SystemMouseCursors.grabbing
                      : (_hoveredNodeId != null
                            ? SystemMouseCursors.grab
                            : SystemMouseCursors.basic),
                  onHover: dragging
                      ? null
                      : (event) {
                          final id = _hitTestNode(event.localPosition);
                          if (id != _hoveredNodeId) {
                            setState(() => _hoveredNodeId = id);
                          }
                        },
                  onExit: (_) {
                    if (_hoveredNodeId != null && !dragging) {
                      setState(() => _hoveredNodeId = null);
                    }
                  },
                  child: RawGestureDetector(
                    gestures: <Type, GestureRecognizerFactory>{
                      _NodeDragGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _NodeDragGestureRecognizer
                          >(
                            () => _NodeDragGestureRecognizer(
                              hitTest: _hitTestNode,
                              tapSlop: _tapSlop,
                            ),
                            (instance) {
                              instance
                                ..hitTest = _hitTestNode
                                ..tapSlop = _tapSlop
                                ..onDragStart = (id, local) {
                                  setState(() {
                                    _draggingNodeId = id;
                                    _hoveredNodeId = id;
                                  });
                                }
                                ..onDragUpdate = (id, local) {
                                  setState(() {
                                    _moveNodeTo(id, local);
                                    _paintEpoch++;
                                  });
                                }
                                ..onDragEnd = (id, {required wasTap}) {
                                  setState(() => _draggingNodeId = null);
                                  if (wasTap) _openNode(id);
                                };
                            },
                          ),
                    },
                    child: CustomPaint(
                      isComplex: true,
                      willChange: dragging,
                      size: Size(_canvasW, _canvasH),
                      painter: _GraphPainter(
                        paintEpoch: _paintEpoch,
                        nodes: _nodes,
                        edges: _edges,
                        offset: _nodeOffset,
                        hoveredNodeId: _hoveredNodeId ?? _draggingNodeId,
                        linkColor: scheme.outline.withValues(alpha: 0.22),
                        hierarchyColor: scheme.onSurface.withValues(alpha: 0.45),
                        labelColor: scheme.onSurface,
                        fontSize: _fontSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Wins the gesture arena immediately when the pointer lands on a node,
/// so [InteractiveViewer] does not pan/zoom during node drag.
class _NodeDragGestureRecognizer extends OneSequenceGestureRecognizer {
  _NodeDragGestureRecognizer({
    required this.hitTest,
    required this.tapSlop,
  });

  String? Function(Offset local) hitTest;
  double tapSlop;
  void Function(String id, Offset local)? onDragStart;
  void Function(String id, Offset local)? onDragUpdate;
  void Function(String id, {required bool wasTap})? onDragEnd;

  String? _id;
  Offset? _start;
  bool _moved = false;

  @override
  void addPointer(PointerDownEvent event) {
    final id = hitTest(event.localPosition);
    if (id == null) return;
    _id = id;
    _start = event.localPosition;
    _moved = false;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onDragStart?.call(id, event.localPosition);
  }

  @override
  void handleEvent(PointerEvent event) {
    final id = _id;
    if (id == null) return;
    if (event is PointerMoveEvent) {
      final start = _start;
      if (start != null && (event.localPosition - start).distance > tapSlop) {
        _moved = true;
      }
      onDragUpdate?.call(id, event.localPosition);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      final wasTap = !_moved && event is PointerUpEvent;
      stopTrackingPointer(event.pointer);
      onDragEnd?.call(id, wasTap: wasTap);
      _reset();
    }
  }

  void _reset() {
    _id = null;
    _start = null;
    _moved = false;
  }

  @override
  String get debugDescription => 'graph node drag';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    final id = _id;
    if (id != null) {
      onDragEnd?.call(id, wasTap: false);
    }
    _reset();
  }
}

({Offset min, Offset max}) _safeBounds(List<_GraphNode> nodes) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  var any = false;
  for (final n in nodes) {
    if (!n.pos.dx.isFinite || !n.pos.dy.isFinite) continue;
    any = true;
    minX = math.min(minX, n.pos.dx);
    minY = math.min(minY, n.pos.dy);
    maxX = math.max(maxX, n.pos.dx);
    maxY = math.max(maxY, n.pos.dy);
  }
  if (!any) {
    return (min: Offset.zero, max: const Offset(400, 300));
  }
  return (min: Offset(minX, minY), max: Offset(maxX, maxY));
}

enum _LegendLineStyle { solid, dashed }

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.lineStyle,
    required this.label,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final _LegendLineStyle lineStyle;
  final String label;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 2),
          painter: _LegendLinePainter(
            lineStyle: lineStyle,
            color: color,
            strokeWidth: strokeWidth,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({
    required this.lineStyle,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final _LegendLineStyle lineStyle;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    if (lineStyle == _LegendLineStyle.dashed) {
      _drawDashedLine(
        canvas,
        paint,
        Offset.zero,
        Offset(size.width, 0),
        dashLength: 4,
        gapLength: 3,
      );
    } else {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter oldDelegate) =>
      oldDelegate.lineStyle != lineStyle ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _GraphNode {
  _GraphNode({
    required this.id,
    required this.label,
    required this.isFolder,
    required this.pos,
    required this.color,
    required this.degree,
    required this.radius,
    this.emoji,
  });

  final String id;
  final String label;
  final bool isFolder;
  final String? emoji;
  final Color color;
  final int degree;
  final double radius;
  Offset pos;
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.paintEpoch,
    required this.nodes,
    required this.edges,
    required this.offset,
    required this.hoveredNodeId,
    required this.linkColor,
    required this.hierarchyColor,
    required this.labelColor,
    required this.fontSize,
  });

  final int paintEpoch;
  final List<_GraphNode> nodes;
  final List<GraphEdge> edges;
  final Offset offset;
  final String? hoveredNodeId;
  final Color linkColor;
  final Color hierarchyColor;
  final Color labelColor;
  final double fontSize;

  Color _fill(Color base, {required bool hovered}) {
    if (!hovered) {
      return Color.lerp(base, Colors.white, 0.18) ?? base;
    }
    return base;
  }

  Color _border(Color base, {required bool hovered}) {
    final hsl = HSLColor.fromColor(base);
    final darker = hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.05, 0.8))
        .toColor();
    return hovered ? darker : Color.lerp(Colors.black, darker, 0.65) ?? darker;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final edge in edges) {
      if (edge.kind == GraphEdgeKind.hierarchy) continue;
      final a = nodeMap[edge.fromId];
      final b = nodeMap[edge.toId];
      if (a == null || b == null) continue;
      final from = a.pos + offset;
      final to = b.pos + offset;
      if (!from.dx.isFinite ||
          !from.dy.isFinite ||
          !to.dx.isFinite ||
          !to.dy.isFinite) {
        continue;
      }
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = linkColor
          ..strokeWidth = 0.7
          ..style = PaintingStyle.stroke,
      );
    }

    for (final edge in edges) {
      if (edge.kind != GraphEdgeKind.hierarchy) continue;
      final a = nodeMap[edge.fromId];
      final b = nodeMap[edge.toId];
      if (a == null || b == null) continue;
      final from = a.pos + offset;
      final to = b.pos + offset;
      if (!from.dx.isFinite ||
          !from.dy.isFinite ||
          !to.dx.isFinite ||
          !to.dy.isFinite) {
        continue;
      }
      final tint = Color.lerp(a.color, hierarchyColor, 0.45) ?? hierarchyColor;
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = tint.withValues(alpha: 0.55)
          ..strokeWidth = 1.35
          ..style = PaintingStyle.stroke,
      );
    }

    final drawOrder = List<_GraphNode>.from(nodes)
      ..sort((a, b) => a.radius.compareTo(b.radius));
    final showLabels = nodes.length <= 250;
    for (final node in drawOrder) {
      final center = node.pos + offset;
      if (!center.dx.isFinite || !center.dy.isFinite) continue;
      final hovered = hoveredNodeId == node.id;
      final r = hovered ? node.radius * 1.15 : node.radius;
      final fill = _fill(node.color, hovered: hovered);
      final border = _border(node.color, hovered: hovered);
      canvas.drawCircle(center, r, Paint()..color = fill);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = border.withValues(alpha: node.isFolder ? 0.85 : 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = node.isFolder ? 1.4 : 0.8,
      );

      if (node.isFolder && (hovered || nodes.length <= 120)) {
        final emoji = (node.emoji == null || node.emoji!.trim().isEmpty)
            ? '📁'
            : node.emoji!.trim();
        _paintCenteredText(
          canvas,
          emoji,
          center,
          fontSize: math.min(14, r * 0.9),
          color: labelColor,
        );
      }

      if (showLabels || hovered) {
        _paintCenteredText(
          canvas,
          node.label,
          center.translate(0, r + 8),
          fontSize: fontSize,
          color: hovered ? border : labelColor.withValues(alpha: 0.85),
          maxWidth: 72,
          fontWeight: hovered ? FontWeight.w600 : FontWeight.w400,
        );
      }
    }
  }

  void _paintCenteredText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    double? maxWidth,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              maxLines: 2,
              ellipsis: '…',
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize))
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth ?? 40));
    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - paragraph.width / 2, center.dy - paragraph.height / 2),
    );
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      oldDelegate.paintEpoch != paintEpoch ||
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.offset != offset ||
      oldDelegate.hoveredNodeId != hoveredNodeId ||
      oldDelegate.linkColor != linkColor ||
      oldDelegate.hierarchyColor != hierarchyColor;
}

void _drawDashedLine(
  Canvas canvas,
  Paint paint,
  Offset from,
  Offset to, {
  required double dashLength,
  required double gapLength,
}) {
  final delta = to - from;
  final length = delta.distance;
  if (!length.isFinite || length <= 0) return;
  final direction = delta / length;
  var traveled = 0.0;
  while (traveled < length) {
    final start = from + direction * traveled;
    final endDist = math.min(traveled + dashLength, length);
    final end = from + direction * endDist;
    canvas.drawLine(start, end, paint);
    traveled += dashLength + gapLength;
  }
}
