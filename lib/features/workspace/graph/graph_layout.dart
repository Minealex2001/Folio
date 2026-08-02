import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Input for isolate-safe force-directed layout.
class GraphLayoutNodeSeed {
  const GraphLayoutNodeSeed({
    required this.id,
    required this.label,
    required this.isFolder,
    this.emoji,
  });

  final String id;
  final String label;
  final bool isFolder;
  final String? emoji;
}

class GraphLayoutEdgeSeed {
  const GraphLayoutEdgeSeed({
    required this.fromId,
    required this.toId,
    required this.isHierarchy,
  });

  final String fromId;
  final String toId;
  final bool isHierarchy;
}

class GraphLayoutInput {
  const GraphLayoutInput({required this.nodes, required this.edges});

  final List<GraphLayoutNodeSeed> nodes;
  final List<GraphLayoutEdgeSeed> edges;
}

class GraphLayoutNode {
  const GraphLayoutNode({
    required this.id,
    required this.label,
    required this.isFolder,
    required this.x,
    required this.y,
    required this.degree,
    this.emoji,
  });

  final String id;
  final String label;
  final bool isFolder;
  final String? emoji;
  final double x;
  final double y;
  final int degree;
}

class GraphLayoutResult {
  const GraphLayoutResult({required this.nodes});

  final List<GraphLayoutNode> nodes;
}

/// Runs force-directed layout off the UI isolate when possible.
Future<GraphLayoutResult> computeGraphLayout(GraphLayoutInput input) {
  return compute(runForceLayout, input);
}

int _pairKey(int a, int b) {
  final lo = a < b ? a : b;
  final hi = a < b ? b : a;
  return lo * 1000003 + hi;
}

/// Cluster-aware force layout: folders as hubs, pages orbit nearby.
GraphLayoutResult runForceLayout(GraphLayoutInput input) {
  final n = input.nodes.length;
  if (n == 0) return const GraphLayoutResult(nodes: []);

  final rng = math.Random(42);
  final xs = List<double>.filled(n, 0);
  final ys = List<double>.filled(n, 0);
  final vxs = List<double>.filled(n, 0);
  final vys = List<double>.filled(n, 0);
  final idToIndex = <String, int>{
    for (var i = 0; i < n; i++) input.nodes[i].id: i,
  };

  final children = <int, List<int>>{};
  final parentOf = <int, int>{};
  final hierPairKeys = <int>{};
  final degrees = List<int>.filled(n, 0);

  for (final edge in input.edges) {
    final ai = idToIndex[edge.fromId];
    final bi = idToIndex[edge.toId];
    if (ai == null || bi == null) continue;
    degrees[ai]++;
    degrees[bi]++;
    if (!edge.isHierarchy) continue;
    children.putIfAbsent(ai, () => []).add(bi);
    parentOf[bi] = ai;
    hierPairKeys.add(_pairKey(ai, bi));
  }

  final folderIndices = <int>[
    for (var i = 0; i < n; i++)
      if (input.nodes[i].isFolder) i,
  ];
  final placed = List<bool>.filled(n, false);

  // 1) Folders on a wide ring (satellite clusters).
  final folderSpread = 220.0 + math.sqrt(math.max(folderIndices.length, 1)) * 140.0;
  if (folderIndices.isEmpty) {
    final spread = 180.0 + math.sqrt(n) * 40.0;
    for (var i = 0; i < n; i++) {
      final angle = (2 * math.pi * i) / n;
      final radius = spread * (0.5 + rng.nextDouble() * 0.5);
      xs[i] = math.cos(angle) * radius;
      ys[i] = math.sin(angle) * radius;
      placed[i] = true;
    }
  } else {
    for (var f = 0; f < folderIndices.length; f++) {
      final i = folderIndices[f];
      final angle =
          (2 * math.pi * f) / folderIndices.length + rng.nextDouble() * 0.2;
      final radius = folderSpread * (0.65 + rng.nextDouble() * 0.35);
      xs[i] = math.cos(angle) * radius;
      ys[i] = math.sin(angle) * radius;
      placed[i] = true;
    }

    // 2) Children in a tight orbit around their folder parent.
    for (final fi in folderIndices) {
      final kids = children[fi] ?? const <int>[];
      if (kids.isEmpty) continue;
      final orbit = 28.0 + 7.0 * math.sqrt(kids.length);
      for (var k = 0; k < kids.length; k++) {
        final ci = kids[k];
        if (placed[ci]) continue;
        final angle =
            (2 * math.pi * k) / kids.length + rng.nextDouble() * 0.15;
        final r = orbit * (0.85 + rng.nextDouble() * 0.3);
        xs[ci] = xs[fi] + math.cos(angle) * r;
        ys[ci] = ys[fi] + math.sin(angle) * r;
        placed[ci] = true;
      }
    }

    // Nested pages whose parent is not a folder: near their parent if placed.
    for (var i = 0; i < n; i++) {
      if (placed[i]) continue;
      final p = parentOf[i];
      if (p != null && placed[p]) {
        final angle = rng.nextDouble() * 2 * math.pi;
        final r = 24 + rng.nextDouble() * 20;
        xs[i] = xs[p] + math.cos(angle) * r;
        ys[i] = ys[p] + math.sin(angle) * r;
        placed[i] = true;
      }
    }

    // Remaining orphans: outer cloud.
    final orphanSpread = folderSpread * 1.35;
    var orphanIdx = 0;
    final orphanCount = placed.where((p) => !p).length;
    for (var i = 0; i < n; i++) {
      if (placed[i]) continue;
      final angle = orphanCount == 0
          ? 0.0
          : (2 * math.pi * orphanIdx) / orphanCount;
      orphanIdx++;
      final r = orphanSpread * (0.9 + rng.nextDouble() * 0.25);
      xs[i] = math.cos(angle) * r;
      ys[i] = math.sin(angle) * r;
      placed[i] = true;
    }
  }

  final mass = List<double>.generate(n, (i) {
    final kids = children[i]?.length ?? 0;
    if (input.nodes[i].isFolder) return 2.5 + math.sqrt(kids);
    return 1.0;
  });

  final iterations = n > 800
      ? 80
      : n > 400
      ? 110
      : n > 150
      ? 150
      : 220;
  final repulsion = 9000.0 / math.max(1.0, math.sqrt(n / 40.0));
  const springLink = 0.008;
  const springHierarchy = 0.11;
  const damping = 0.84;
  final centerGravity = n > 400 ? 0.002 : 0.0035;
  final idealLink = 90.0 + 700.0 / math.sqrt(n);
  final maxForce = 50.0 + 2500.0 / math.max(n, 1);
  final maxVel = 32.0;
  const maxCoord = 12000.0;

  (double, double) clampVec(double x, double y, double max) {
    final d = math.sqrt(x * x + y * y);
    if (!d.isFinite || d == 0) return (0.0, 0.0);
    if (d > max) {
      final s = max / d;
      return (x * s, y * s);
    }
    return (x, y);
  }

  final fxs = List<double>.filled(n, 0);
  final fys = List<double>.filled(n, 0);

  for (var iter = 0; iter < iterations; iter++) {
    for (var i = 0; i < n; i++) {
      fxs[i] = 0;
      fys[i] = 0;
    }

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final dx = xs[i] - xs[j];
        final dy = ys[i] - ys[j];
        var distSq = dx * dx + dy * dy;
        if (!distSq.isFinite || distSq < 1.0) distSq = 1.0;
        final dist = math.sqrt(distSq);
        // Soften repulsion for parent↔child so pages stay near folders.
        final pairMul = hierPairKeys.contains(_pairKey(i, j)) ? 0.12 : 1.0;
        final strength = repulsion * pairMul / distSq;
        final fx = dx / dist * strength;
        final fy = dy / dist * strength;
        if (!fx.isFinite || !fy.isFinite) continue;
        fxs[i] += fx;
        fys[i] += fy;
        fxs[j] -= fx;
        fys[j] -= fy;
      }
    }

    for (final edge in input.edges) {
      final ai = idToIndex[edge.fromId];
      final bi = idToIndex[edge.toId];
      if (ai == null || bi == null) continue;
      final dx = xs[bi] - xs[ai];
      final dy = ys[bi] - ys[ai];
      var dist = math.sqrt(dx * dx + dy * dy);
      if (!dist.isFinite || dist < 1.0) dist = 1.0;

      late final double spring;
      late final double ideal;
      if (edge.isHierarchy) {
        final kidCount = math.max(
          children[ai]?.length ?? 1,
          children[bi]?.length ?? 1,
        );
        spring = springHierarchy;
        ideal = 22.0 + math.min(55.0, 6.5 * math.sqrt(kidCount.toDouble()));
      } else {
        spring = springLink;
        ideal = idealLink;
      }

      final scale = spring * (dist - ideal);
      final fx = dx / dist * scale;
      final fy = dy / dist * scale;
      if (!fx.isFinite || !fy.isFinite) continue;
      fxs[ai] += fx;
      fys[ai] += fy;
      fxs[bi] -= fx;
      fys[bi] -= fy;
    }

    for (var i = 0; i < n; i++) {
      fxs[i] += -xs[i] * centerGravity;
      fys[i] += -ys[i] * centerGravity;
      final clampedF = clampVec(fxs[i], fys[i], maxForce);
      final invMass = 1.0 / mass[i];
      final nvx = (vxs[i] + clampedF.$1 * invMass) * damping;
      final nvy = (vys[i] + clampedF.$2 * invMass) * damping;
      final clampedV = clampVec(nvx, nvy, maxVel);
      vxs[i] = clampedV.$1;
      vys[i] = clampedV.$2;

      var nx = xs[i] + vxs[i];
      var ny = ys[i] + vys[i];
      if (!nx.isFinite || !ny.isFinite) {
        vxs[i] = 0;
        vys[i] = 0;
        continue;
      }
      xs[i] = nx.clamp(-maxCoord, maxCoord);
      ys[i] = ny.clamp(-maxCoord, maxCoord);
    }
  }

  // Mild global inflate — keep relative cluster structure.
  var minX = xs[0];
  var maxX = xs[0];
  var minY = ys[0];
  var maxY = ys[0];
  var cx = 0.0;
  var cy = 0.0;
  for (var i = 0; i < n; i++) {
    minX = math.min(minX, xs[i]);
    maxX = math.max(maxX, xs[i]);
    minY = math.min(minY, ys[i]);
    maxY = math.max(maxY, ys[i]);
    cx += xs[i];
    cy += ys[i];
  }
  cx /= n;
  cy /= n;
  final area = math.max((maxX - minX) * (maxY - minY), 1.0);
  final targetArea = n * 70.0 * 70.0;
  final inflate = math.sqrt(targetArea / area).clamp(1.0, 3.5);
  if (inflate > 1.02) {
    for (var i = 0; i < n; i++) {
      xs[i] = (cx + (xs[i] - cx) * inflate).clamp(-maxCoord, maxCoord);
      ys[i] = (cy + (ys[i] - cy) * inflate).clamp(-maxCoord, maxCoord);
    }
  }

  return GraphLayoutResult(
    nodes: [
      for (var i = 0; i < n; i++)
        GraphLayoutNode(
          id: input.nodes[i].id,
          label: input.nodes[i].label,
          isFolder: input.nodes[i].isFolder,
          emoji: input.nodes[i].emoji,
          x: xs[i],
          y: ys[i],
          degree: degrees[i],
        ),
    ],
  );
}
