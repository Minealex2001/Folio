import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/canvas/canvas_snap.dart';
import 'package:folio/models/folio_canvas_data.dart';

FolioCanvasNode _node({
  required String id,
  required double x,
  required double y,
  double width = 50,
  double height = 50,
  bool visible = true,
}) {
  return FolioCanvasNode(
    id: id,
    type: CanvasNodeType.shape,
    x: x,
    y: y,
    width: width,
    height: height,
    visible: visible,
  );
}

void main() {
  group('snapNodeMove', () {
    test('snaps a node moving toward a sibling edge within snapPx', () {
      final node = _node(id: 'a', x: 0, y: 0);
      final sibling = _node(id: 'b', x: 100, y: 0);

      // node.right = 0+50=50 hoy; proponemos +47 -> right propuesto en 97,
      // a 3px (dentro de snapPx=6) del borde izquierdo de 'b' (100).
      final result = snapNodeMove(
        node: node,
        proposedDelta: const Offset(47, 0),
        allNodes: [node, sibling],
        excludeIds: {'a'},
        gridStep: 0,
        snapPx: 6,
      );

      final finalRight = node.x + result.delta.dx + node.width;
      expect(finalRight, 100); // corrige a la coordenada exacta del vecino
      expect(result.guideV, 100);
    });

    test(
      'does not silently cancel a real snap with a self-comparison '
      '(regression for the bug where targetsX/Y included the moving '
      "node's own edges)",
      () {
        final node = _node(id: 'a', x: 0, y: 0);
        final sibling = _node(id: 'b', x: 100, y: 0);

        final result = snapNodeMove(
          node: node,
          proposedDelta: const Offset(46, 0),
          allNodes: [node, sibling],
          excludeIds: {'a'},
          gridStep: 0,
          snapPx: 6,
        );

        // Antes del fix, bestDx siempre terminaba en 0 (self-snap espurio,
        // ver arriba) en vez de aplicar la corrección real (+4) a la
        // coordenada exacta del vecino.
        expect(result.delta.dx, 50);
        expect(node.x + result.delta.dx + node.width, 100);
      },
    );

    test('falls back to plain grid rounding when no sibling is in range', () {
      final node = _node(id: 'a', x: 100, y: 100);
      final result = snapNodeMove(
        node: node,
        proposedDelta: const Offset(3, 5),
        allNodes: [node],
        excludeIds: {'a'},
        gridStep: 8,
      );
      expect(result.delta.dx, 4); // 103 -> redondea a 104
      expect(result.delta.dy, 4); // 105 -> redondea a 104
    });

    test('excludeIds prevents snapping to an excluded sibling', () {
      final node = _node(id: 'a', x: 0, y: 0);
      final sibling = _node(id: 'b', x: 97, y: 0);
      final result = snapNodeMove(
        node: node,
        proposedDelta: const Offset(47, 0),
        allNodes: [node, sibling],
        excludeIds: {'a', 'b'},
        gridStep: 0,
        snapPx: 6,
      );
      expect(result.delta.dx, 47); // sin corrección: única vecina excluida
    });

    test('ignores invisible siblings', () {
      final node = _node(id: 'a', x: 0, y: 0);
      final sibling = _node(id: 'b', x: 97, y: 0, visible: false);
      final result = snapNodeMove(
        node: node,
        proposedDelta: const Offset(47, 0),
        allNodes: [node, sibling],
        excludeIds: {'a'},
        gridStep: 0,
        snapPx: 6,
      );
      expect(result.delta.dx, 47);
    });
  });

  group('snapGroupMove', () {
    test('snaps the group bounding box to a sibling as a unit', () {
      final a = _node(id: 'a', x: 0, y: 0, width: 20, height: 20);
      final b = _node(id: 'b', x: 30, y: 0, width: 20, height: 20);
      final sibling = _node(id: 'c', x: 97, y: 0, width: 20, height: 20);

      final result = snapGroupMove(
        moving: [a, b],
        proposedDelta: const Offset(44, 0),
        allNodes: [a, b, sibling],
        movingIds: {'a', 'b'},
        gridStep: 0,
        snapPx: 6,
      );

      expect(result.delta.dx, 47);
      expect(result.guideV, 97);
    });

    test('returns the proposed delta unchanged for an empty group', () {
      final result = snapGroupMove(
        moving: const [],
        proposedDelta: const Offset(10, 10),
        allNodes: const [],
        movingIds: const {},
      );
      expect(result.delta, const Offset(10, 10));
    });
  });
}
