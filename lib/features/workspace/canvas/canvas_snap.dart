import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/folio_canvas_data.dart';

/// Resultado de aplicar snapping a un desplazamiento propuesto.
class CanvasSnapResult {
  const CanvasSnapResult({
    required this.delta,
    this.guideH,
    this.guideV,
  });

  final Offset delta;
  final double? guideH;
  final double? guideV;
}

/// Ajusta [proposedDelta] con grid y geometría de otros nodos.
CanvasSnapResult snapNodeMove({
  required FolioCanvasNode node,
  required Offset proposedDelta,
  required List<FolioCanvasNode> allNodes,
  required Set<String> excludeIds,
  double gridStep = 8,
  double snapPx = 6,
}) {
  double nx = node.x + proposedDelta.dx;
  double ny = node.y + proposedDelta.dy;

  if (gridStep > 0) {
    nx = (nx / gridStep).roundToDouble() * gridStep;
    ny = (ny / gridStep).roundToDouble() * gridStep;
  }

  double? guideH;
  double? guideV;
  final rect = Rect.fromLTWH(nx, ny, node.width, node.height);
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  final left = rect.left;
  final right = rect.right;
  final top = rect.top;
  final bottom = rect.bottom;

  double bestDx = 0;
  double bestDy = 0;
  var bestScore = double.infinity;

  for (final o in allNodes) {
    if (excludeIds.contains(o.id)) continue;
    if (!o.visible) continue;
    final or = Rect.fromLTWH(o.x, o.y, o.width, o.height);
    final targetsX = <double>[
      or.left,
      or.center.dx,
      or.right,
      left,
      cx,
      right,
    ];
    final targetsY = <double>[
      or.top,
      or.center.dy,
      or.bottom,
      top,
      cy,
      bottom,
    ];
    for (final tx in targetsX) {
      for (final vx in [left, cx, right]) {
        final d = tx - vx;
        if (d.abs() < snapPx && d.abs() < bestScore) {
          bestScore = d.abs();
          bestDx = d;
          guideV = tx;
        }
      }
    }
    bestScore = double.infinity;
    for (final ty in targetsY) {
      for (final vy in [top, cy, bottom]) {
        final d = ty - vy;
        if (d.abs() < snapPx && d.abs() < bestScore) {
          bestScore = d.abs();
          bestDy = d;
          guideH = ty;
        }
      }
    }
  }

  nx += bestDx;
  ny += bestDy;

  final out = Offset(nx - node.x, ny - node.y);
  return CanvasSnapResult(delta: out, guideH: guideH, guideV: guideV);
}

/// Snapping para mover un conjunto de nodos como unidad (usa bounding box).
CanvasSnapResult snapGroupMove({
  required List<FolioCanvasNode> moving,
  required Offset proposedDelta,
  required List<FolioCanvasNode> allNodes,
  required Set<String> movingIds,
  double gridStep = 8,
  double snapPx = 6,
}) {
  if (moving.isEmpty) {
    return CanvasSnapResult(delta: proposedDelta);
  }
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;
  for (final n in moving) {
    minX = math.min(minX, n.x);
    minY = math.min(minY, n.y);
    maxX = math.max(maxX, n.x + n.width);
    maxY = math.max(maxY, n.y + n.height);
  }
  final anchor = FolioCanvasNode(
    id: '_bbox_',
    type: CanvasNodeType.text,
    x: minX,
    y: minY,
    width: maxX - minX,
    height: maxY - minY,
  );
  return snapNodeMove(
    node: anchor,
    proposedDelta: proposedDelta,
    allNodes: allNodes,
    excludeIds: movingIds,
    gridStep: gridStep,
    snapPx: snapPx,
  );
}
