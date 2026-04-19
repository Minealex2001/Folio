import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';

/// Pantalla de vista de grafo: muestra las páginas como nodos y sus
/// enlaces internos como aristas en un layout de fuerza dirigida.
class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({
    super.key,
    required this.session,
    required this.onOpenPage,
  });

  final VaultSession session;
  final void Function(String pageId) onOpenPage;

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen>
    with TickerProviderStateMixin {
  static const double _nodeRadius = 20.0;
  static const double _fontSize = 11.0;
  static const int _simulationIterations = 200;
  static const double _repulsion = 5000;
  static const double _spring = 0.04;
  static const double _damping = 0.85;
  static const double _centerGravity = 0.015;

  List<_GraphNode> _nodes = [];
  List<_GraphEdge> _edges = [];
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
    final pages = widget.session.pages;
    final edgeSet = <String>{};
    final edges = <_GraphEdge>[];
    final linkedPageIds = <String>{};

    // Build edges from backlinks
    for (final page in pages) {
      final backlinks = widget.session.backlinkPagesFor(page.id);
      for (final src in backlinks) {
        final key = src.id.compareTo(page.id) < 0
            ? '${src.id}→${page.id}'
            : '${page.id}→${src.id}';
        if (!edgeSet.contains(key)) {
          edgeSet.add(key);
          edges.add(_GraphEdge(fromId: src.id, toId: page.id));
          linkedPageIds.add(src.id);
          linkedPageIds.add(page.id);
        }
      }
    }

    // Filter pages
    final visiblePages = _includeOrphans
        ? pages
        : pages.where((p) => linkedPageIds.contains(p.id)).toList();

    final rng = math.Random(42);
    final center = const Offset(400, 300);
    final nodes = visiblePages.map((p) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final radius = 80 + rng.nextDouble() * 200;
      final pos =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      return _GraphNode(
        id: p.id,
        label: p.title.trim().isEmpty ? '…' : p.title.trim(),
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
      for (final edge in edges) {
        final a = nodeMap[edge.fromId];
        final b = nodeMap[edge.toId];
        if (a == null || b == null) continue;
        final delta = b.pos - a.pos;
        final dist = delta.distance.clamp(1.0, double.infinity);
        final force = delta * _spring * math.log(dist / 100 + 1);
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
      _edges = edges;
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
      minPos = Offset(
        math.min(minPos.dx, n.pos.dx),
        math.min(minPos.dy, n.pos.dy),
      );
      maxPos = Offset(
        math.max(maxPos.dx, n.pos.dx),
        math.max(maxPos.dy, n.pos.dy),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.graphViewTitle),
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
          : InteractiveViewer(
              transformationController: _tc,
              constrained: false,
              minScale: 0.1,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(500),
              child: SizedBox(
                width: maxPos.dx - minPos.dx + 200,
                height: maxPos.dy - minPos.dy + 200,
                child: Stack(
                  children: [
                    // Edges layer
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EdgePainter(
                          nodes: _nodes,
                          edges: _edges,
                          edgeColor: scheme.outlineVariant,
                          offset: -minPos + const Offset(100, 100),
                        ),
                      ),
                    ),
                    // Nodes layer
                    ..._nodes.map((node) {
                      final drawPos =
                          node.pos - minPos + const Offset(100, 100);
                      final isHovered = _hoveredNodeId == node.id;
                      return Positioned(
                        left: drawPos.dx - _nodeRadius - 40,
                        top: drawPos.dy - _nodeRadius - 8,
                        width: 80 + _nodeRadius * 2,
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
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
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
                                              color: scheme.primary.withAlpha(
                                                80,
                                              ),
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
                                        ? scheme.primary
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
            ),
    );
  }
}

class _GraphNode {
  _GraphNode({required this.id, required this.label, required Offset pos})
    : pos = pos,
      vel = Offset.zero;

  final String id;
  final String label;
  Offset pos;
  Offset vel;
}

class _GraphEdge {
  const _GraphEdge({required this.fromId, required this.toId});
  final String fromId;
  final String toId;
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.nodes,
    required this.edges,
    required this.edgeColor,
    required this.offset,
  });

  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final Color edgeColor;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final nodeMap = {for (final n in nodes) n.id: n};
    for (final edge in edges) {
      final a = nodeMap[edge.fromId];
      final b = nodeMap[edge.toId];
      if (a == null || b == null) continue;
      final from = a.pos + offset;
      final to = b.pos + offset;
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.edges != edges;
}
