import 'dart:math' as math;

import 'package:folio/features/workspace/graph/graph_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runForceLayout', () {
    test('1000 nodos produce posiciones finitas', () {
      final nodes = [
        for (var i = 0; i < 1000; i++)
          GraphLayoutNodeSeed(
            id: 'n$i',
            label: 'Page $i',
            isFolder: i % 20 == 0,
          ),
      ];
      final edges = [
        for (var i = 1; i < 1000; i++)
          GraphLayoutEdgeSeed(
            fromId: 'n${i ~/ 2}',
            toId: 'n$i',
            isHierarchy: i % 3 == 0,
          ),
      ];

      final result = runForceLayout(
        GraphLayoutInput(nodes: nodes, edges: edges),
      );

      expect(result.nodes, hasLength(1000));
      for (final n in result.nodes) {
        expect(n.x.isFinite, isTrue, reason: '${n.id} x');
        expect(n.y.isFinite, isTrue, reason: '${n.id} y');
        expect(n.x.abs(), lessThanOrEqualTo(12000));
        expect(n.y.abs(), lessThanOrEqualTo(12000));
      }
    });

    test('grafo vacío', () {
      final result = runForceLayout(
        const GraphLayoutInput(nodes: [], edges: []),
      );
      expect(result.nodes, isEmpty);
    });

    test('páginas hijas quedan cerca de su carpeta', () {
      final nodes = [
        const GraphLayoutNodeSeed(id: 'f1', label: 'F1', isFolder: true),
        const GraphLayoutNodeSeed(id: 'f2', label: 'F2', isFolder: true),
        for (var i = 0; i < 12; i++)
          GraphLayoutNodeSeed(id: 'c$i', label: 'C$i', isFolder: false),
      ];
      final edges = [
        for (var i = 0; i < 12; i++)
          GraphLayoutEdgeSeed(
            fromId: i < 6 ? 'f1' : 'f2',
            toId: 'c$i',
            isHierarchy: true,
          ),
      ];

      final result = runForceLayout(
        GraphLayoutInput(nodes: nodes, edges: edges),
      );
      final byId = {for (final n in result.nodes) n.id: n};
      final f1 = byId['f1']!;
      final f2 = byId['f2']!;

      double dist(GraphLayoutNode a, GraphLayoutNode b) {
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        return math.sqrt(dx * dx + dy * dy);
      }

      for (var i = 0; i < 6; i++) {
        final child = byId['c$i']!;
        expect(dist(child, f1), lessThan(dist(child, f2)));
      }
      for (var i = 6; i < 12; i++) {
        final child = byId['c$i']!;
        expect(dist(child, f2), lessThan(dist(child, f1)));
      }
    });
  });
}
