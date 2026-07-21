import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/widgets/folio_icon_token_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';
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

class _GraphViewScreenState extends State<GraphViewScreen>
    with TickerProviderStateMixin {
  static const double _nodeRadius = 20.0;
  static const double _folderNodeWidth = 44.0;
  static const double _folderNodeHeight = 36.0;
  static const double _fontSize = 11.0;
  static const int _simulationIterations = 200;
  static const double _repulsion = 5000;
  static const double _springLink = 0.04;
  static const double _springHierarchy = 0.08;
  static const double _damping = 0.85;
  static const double _centerGravity = 0.015;

  List<_GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  bool _includeOrphans = true;
  String? _hoveredNodeId;

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

  void _buildGraph() {
    final graphData = buildVaultGraph(
      pages: widget.session.pages,
      backlinkPagesFor: widget.session.backlinkPagesFor,
      includeOrphans: _includeOrphans,
    );

    final rng = math.Random(42);
    final center = const Offset(400, 300);
    final nodes = graphData.nodes.map((data) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final radius = 80 + rng.nextDouble() * 200;
      final pos =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      return _GraphNode(
        id: data.id,
        label: data.label,
        isFolder: data.isFolder,
        emoji: data.emoji,
        pos: pos,
      );
    }).toList();

    // Run force-directed simulation
    final nodeMap = {for (final n in nodes) n.id: n};
    for (var iter = 0; iter < _simulationIterations; iter++) {
      final forces = {for (final n in nodes) n.id: Offset.zero};

      // Repulsion between all pairs
      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          final a = nodes[i];
          final b = nodes[j];
          final delta = a.pos - b.pos;
          final dist = delta.distance.clamp(1.0, double.infinity);
          final force = delta / dist * (_repulsion / (dist * dist));
          forces[a.id] = forces[a.id]! + force;
          forces[b.id] = forces[b.id]! - force;
        }
      }

      // Spring attraction for linked pairs
      for (final edge in graphData.edges) {
        final a = nodeMap[edge.fromId];
        final b = nodeMap[edge.toId];
        if (a == null || b == null) continue;
        final delta = b.pos - a.pos;
        final dist = delta.distance.clamp(1.0, double.infinity);
        final spring = edge.kind == GraphEdgeKind.hierarchy
            ? _springHierarchy
            : _springLink;
        final force = delta * spring * math.log(dist / 100 + 1);
        forces[a.id] = forces[a.id]! + force;
        forces[b.id] = forces[b.id]! - force;
      }

      // Center gravity
      for (final n in nodes) {
        final delta = center - n.pos;
        forces[n.id] = forces[n.id]! + delta * _centerGravity;
      }

      // Apply forces with damping
      for (final n in nodes) {
        n.vel = (n.vel + forces[n.id]!) * _damping;
        n.pos = n.pos + n.vel;
      }
    }

    setState(() {
      _nodes = nodes;
      _edges = graphData.edges;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Compute bounding box for initial view
    Offset minPos = const Offset(double.infinity, double.infinity);
    Offset maxPos = const Offset(
      double.negativeInfinity,
      double.negativeInfinity,
    );
    for (final n in _nodes) {
      final halfW = n.isFolder ? _folderNodeWidth / 2 : _nodeRadius;
      final halfH = n.isFolder ? _folderNodeHeight / 2 : _nodeRadius;
      minPos = Offset(
        math.min(minPos.dx, n.pos.dx - halfW),
        math.min(minPos.dy, n.pos.dy - halfH),
      );
      maxPos = Offset(
        math.max(maxPos.dx, n.pos.dx + halfW),
        math.max(maxPos.dy, n.pos.dy + halfH),
      );
    }

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
                  color: scheme.outlineVariant,
                ),
                const SizedBox(width: 12),
                _LegendItem(
                  lineStyle: _LegendLineStyle.dashed,
                  label: l10n.graphViewLegendHierarchy,
                  color: scheme.outline.withValues(alpha: 0.55),
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
                onChanged: (v) {
                  setState(() => _includeOrphans = v);
                  _buildGraph();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: _nodes.isEmpty
          ? Center(
              child: Text(
                l10n.graphViewEmpty,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : LayoutBuilder(
              builder: (context, viewportConstraints) {
                final graphW = maxPos.dx - minPos.dx + 200;
                final graphH = maxPos.dy - minPos.dy + 200;
                // Canvas is at least the viewport size so nodes are centered
                // rather than stuck in the top-left corner.
                final canvasW = math.max(graphW, viewportConstraints.maxWidth);
                final canvasH = math.max(graphH, viewportConstraints.maxHeight);
                // Offset that maps simulation coords to canvas coords,
                // centering the bounding box within the canvas.
                final dx = (canvasW - graphW) / 2 - minPos.dx + 100;
                final dy = (canvasH - graphH) / 2 - minPos.dy + 100;
                final nodeOffset = Offset(dx, dy);

                return InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.1,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(500),
                  child: SizedBox(
                    width: canvasW,
                    height: canvasH,
                    child: Stack(
                      children: [
                        // Edges layer
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EdgePainter(
                              nodes: _nodes,
                              edges: _edges,
                              linkColor: scheme.outlineVariant,
                              hierarchyColor: scheme.outline.withValues(
                                alpha: 0.55,
                              ),
                              offset: nodeOffset,
                            ),
                          ),
                        ),
                        // Nodes layer
                        ..._nodes.map((node) {
                          final drawPos = node.pos + nodeOffset;
                          final isHovered = _hoveredNodeId == node.id;
                          final nodeHalfW = node.isFolder
                              ? _folderNodeWidth / 2
                              : _nodeRadius;
                          final nodeHalfH = node.isFolder
                              ? _folderNodeHeight / 2
                              : _nodeRadius;
                          return Positioned(
                            left: drawPos.dx - nodeHalfW - 40,
                            top: drawPos.dy - nodeHalfH - 8,
                            width: 80 + nodeHalfW * 2,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onOpenPage(node.id);
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setState(() => _hoveredNodeId = node.id),
                                onExit: (_) =>
                                    setState(() => _hoveredNodeId = null),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (node.isFolder)
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        width: isHovered
                                            ? _folderNodeWidth * 1.15
                                            : _folderNodeWidth,
                                        height: isHovered
                                            ? _folderNodeHeight * 1.15
                                            : _folderNodeHeight,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: isHovered
                                              ? scheme.tertiary
                                              : scheme.tertiaryContainer,
                                          border: Border.all(
                                            color: scheme.tertiary,
                                            width: 1.5,
                                          ),
                                          boxShadow: isHovered
                                              ? [
                                                  BoxShadow(
                                                    color: scheme.tertiary
                                                        .withAlpha(80),
                                                    blurRadius: 8,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: FolioIconTokenView(
                                            appSettings: widget.appSettings,
                                            token: node.emoji,
                                            fallbackText: '📁',
                                            size: 18,
                                          ),
                                        ),
                                      )
                                    else
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        width: isHovered
                                            ? _nodeRadius * 2.4
                                            : _nodeRadius * 2,
                                        height: isHovered
                                            ? _nodeRadius * 2.4
                                            : _nodeRadius * 2,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isHovered
                                              ? scheme.primary
                                              : scheme.primaryContainer,
                                          border: Border.all(
                                            color: scheme.primary,
                                            width: 1.5,
                                          ),
                                          boxShadow: isHovered
                                              ? [
                                                  BoxShadow(
                                                    color: scheme.primary
                                                        .withAlpha(80),
                                                    blurRadius: 8,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      node.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: _fontSize,
                                        fontWeight: isHovered
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isHovered
                                            ? (node.isFolder
                                                  ? scheme.tertiary
                                                  : scheme.primary)
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

enum _LegendLineStyle { solid, dashed }

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.lineStyle,
    required this.label,
    required this.color,
  });

  final _LegendLineStyle lineStyle;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 2),
          painter: _LegendLinePainter(lineStyle: lineStyle, color: color),
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
  const _LegendLinePainter({required this.lineStyle, required this.color});

  final _LegendLineStyle lineStyle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
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
      oldDelegate.lineStyle != lineStyle || oldDelegate.color != color;
}

class _GraphNode {
  _GraphNode({
    required this.id,
    required this.label,
    required this.isFolder,
    required this.pos,
    this.emoji,
  }) : vel = Offset.zero;

  final String id;
  final String label;
  final bool isFolder;
  final String? emoji;
  Offset pos;
  Offset vel;
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.nodes,
    required this.edges,
    required this.linkColor,
    required this.hierarchyColor,
    required this.offset,
  });

  final List<_GraphNode> nodes;
  final List<GraphEdge> edges;
  final Color linkColor;
  final Color hierarchyColor;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};
    for (final edge in edges) {
      final a = nodeMap[edge.fromId];
      final b = nodeMap[edge.toId];
      if (a == null || b == null) continue;
      final from = a.pos + offset;
      final to = b.pos + offset;
      final paint = Paint()
        ..color = edge.kind == GraphEdgeKind.hierarchy
            ? hierarchyColor
            : linkColor
        ..strokeWidth = edge.kind == GraphEdgeKind.hierarchy ? 1.0 : 1.2
        ..style = PaintingStyle.stroke;
      if (edge.kind == GraphEdgeKind.hierarchy) {
        _drawDashedLine(canvas, paint, from, to, dashLength: 6, gapLength: 4);
      } else {
        canvas.drawLine(from, to, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.edges != edges;
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
  if (length <= 0) return;
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
