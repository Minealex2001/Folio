import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cualquier elemento posicionable/redimensionable que participa en snap:
/// un [PanelConfig] (Fase 2) o, más adelante, una instancia de widget de
/// dashboard (Fase 5). Generalización de `FolioCanvasNode` — la misma
/// matemática de `canvas_snap.dart` sirve para ambos casos vía este adaptador.
abstract class SnapTarget {
  String get id;
  double get x;
  double get y;
  double get width;
  double get height;
  bool get visible;
}

/// Resultado de aplicar snapping a un desplazamiento propuesto.
class SnapResult {
  const SnapResult({required this.delta, this.guideH, this.guideV});

  final Offset delta;
  final double? guideH;
  final double? guideV;
}

/// Ajusta [proposedDelta] con grid y geometría de otros elementos.
/// Generalización de `snapNodeMove` (`canvas_snap.dart`): mismo algoritmo,
/// mismo grid-step + guías de alineación por borde/centro, pero operando
/// sobre [SnapTarget] en vez de `FolioCanvasNode` — así paneles (Fase 2) y
/// widgets de dashboard (Fase 5) comparten una sola implementación.
SnapResult snapMove({
  required SnapTarget target,
  required Offset proposedDelta,
  required List<SnapTarget> siblings,
  required Set<String> excludeIds,
  double gridStep = 8,
  double snapPx = 6,
}) {
  double nx = target.x + proposedDelta.dx;
  double ny = target.y + proposedDelta.dy;

  if (gridStep > 0) {
    nx = (nx / gridStep).roundToDouble() * gridStep;
    ny = (ny / gridStep).roundToDouble() * gridStep;
  }

  double? guideH;
  double? guideV;
  final rect = Rect.fromLTWH(nx, ny, target.width, target.height);
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  final left = rect.left;
  final right = rect.right;
  final top = rect.top;
  final bottom = rect.bottom;

  double bestDx = 0;
  double bestDy = 0;
  var bestScoreX = double.infinity;
  var bestScoreY = double.infinity;

  for (final other in siblings) {
    if (excludeIds.contains(other.id)) continue;
    if (!other.visible) continue;
    final or = Rect.fromLTWH(other.x, other.y, other.width, other.height);
    // Solo los bordes/centro del OTRO elemento son targets válidos — nunca
    // los del propio [target], que siempre están a distancia 0 de sí mismos
    // y anularían cualquier snap real encontrado (bug detectado al portar
    // esta lógica desde `canvas_snap.dart`, que sí incluye ambos; se
    // corrige aquí porque este módulo nuevo todavía no tiene consumidores,
    // sin tocar el archivo original en producción).
    final targetsX = <double>[or.left, or.center.dx, or.right];
    final targetsY = <double>[or.top, or.center.dy, or.bottom];

    for (final tx in targetsX) {
      for (final vx in [left, cx, right]) {
        final d = tx - vx;
        if (d.abs() < snapPx && d.abs() < bestScoreX) {
          bestScoreX = d.abs();
          bestDx = d;
          guideV = tx;
        }
      }
    }
    for (final ty in targetsY) {
      for (final vy in [top, cy, bottom]) {
        final d = ty - vy;
        if (d.abs() < snapPx && d.abs() < bestScoreY) {
          bestScoreY = d.abs();
          bestDy = d;
          guideH = ty;
        }
      }
    }
  }

  nx += bestDx;
  ny += bestDy;

  return SnapResult(
    delta: Offset(nx - target.x, ny - target.y),
    guideH: guideH,
    guideV: guideV,
  );
}

/// Variante para mover un conjunto de elementos como unidad (bounding box) —
/// generalización de `snapGroupMove`.
SnapResult snapGroupMove({
  required List<SnapTarget> moving,
  required Offset proposedDelta,
  required List<SnapTarget> siblings,
  required Set<String> movingIds,
  double gridStep = 8,
  double snapPx = 6,
}) {
  if (moving.isEmpty) {
    return SnapResult(delta: proposedDelta);
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
  final anchor = _BoundingBoxSnapTarget(
    x: minX,
    y: minY,
    width: maxX - minX,
    height: maxY - minY,
  );
  return snapMove(
    target: anchor,
    proposedDelta: proposedDelta,
    siblings: siblings,
    excludeIds: movingIds,
    gridStep: gridStep,
    snapPx: snapPx,
  );
}

class _BoundingBoxSnapTarget implements SnapTarget {
  _BoundingBoxSnapTarget({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  final double x;
  @override
  final double y;
  @override
  final double width;
  @override
  final double height;
  @override
  String get id => '_bbox_';
  @override
  bool get visible => true;
}
