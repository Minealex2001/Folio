import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/layout_engine/snapping/snap_engine.dart';

class _FakeTarget implements SnapTarget {
  _FakeTarget({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.visible = true,
  });

  @override
  final String id;
  @override
  double x;
  @override
  double y;
  @override
  final double width;
  @override
  final double height;
  @override
  final bool visible;
}

void main() {
  group('snapMove', () {
    test('rounds to the grid step when no siblings are nearby', () {
      final target = _FakeTarget(id: 'a', x: 100, y: 100, width: 50, height: 50);
      final result = snapMove(
        target: target,
        proposedDelta: const Offset(3, 5),
        siblings: const [],
        excludeIds: const {},
        gridStep: 8,
      );
      // x: 100 + 3 = 103 -> rounds to 104 (nearest multiple of 8) -> delta 4
      // y: 100 + 5 = 105 -> rounds to 104 -> delta 4
      expect(result.delta.dx, 4);
      expect(result.delta.dy, 4);
    });

    test('snaps to a sibling edge within snapPx', () {
      final target = _FakeTarget(id: 'a', x: 0, y: 0, width: 50, height: 50);
      final sibling = _FakeTarget(id: 'b', x: 100, y: 0, width: 50, height: 50);
      // Mover 'a' hasta que su borde derecho (x+width) quede cerca del borde
      // izquierdo de 'b' (100): proposedDelta.dx = 47 -> right edge en 97,
      // dentro de snapPx=6 de 100.
      final result = snapMove(
        target: target,
        proposedDelta: const Offset(47, 0),
        siblings: [sibling],
        excludeIds: const {},
        gridStep: 0,
        snapPx: 6,
      );
      final finalRight = target.x + result.delta.dx + target.width;
      expect(finalRight, 100);
      expect(result.guideV, 100);
    });

    test('excludes ids in excludeIds from snap targets', () {
      final target = _FakeTarget(id: 'a', x: 0, y: 0, width: 50, height: 50);
      final sibling = _FakeTarget(id: 'b', x: 97, y: 0, width: 50, height: 50);
      final result = snapMove(
        target: target,
        proposedDelta: const Offset(47, 0),
        siblings: [sibling],
        excludeIds: {'b'},
        gridStep: 0,
        snapPx: 6,
      );
      // Sin snap disponible (única sibling excluida): el delta pasa igual.
      expect(result.delta.dx, 47);
    });

    test('ignores invisible siblings', () {
      final target = _FakeTarget(id: 'a', x: 0, y: 0, width: 50, height: 50);
      final sibling = _FakeTarget(
        id: 'b',
        x: 97,
        y: 0,
        width: 50,
        height: 50,
        visible: false,
      );
      final result = snapMove(
        target: target,
        proposedDelta: const Offset(47, 0),
        siblings: [sibling],
        excludeIds: const {},
        gridStep: 0,
        snapPx: 6,
      );
      expect(result.delta.dx, 47);
    });
  });

  group('snapGroupMove', () {
    test('returns the proposed delta unchanged for an empty group', () {
      final result = snapGroupMove(
        moving: const [],
        proposedDelta: const Offset(10, 10),
        siblings: const [],
        movingIds: const {},
      );
      expect(result.delta, const Offset(10, 10));
    });

    test('snaps the group bounding box as a unit', () {
      final a = _FakeTarget(id: 'a', x: 0, y: 0, width: 20, height: 20);
      final b = _FakeTarget(id: 'b', x: 30, y: 0, width: 20, height: 20);
      final sibling = _FakeTarget(id: 'c', x: 97, y: 0, width: 20, height: 20);
      // bbox de a+b: left=0, right=50. Proponemos +44 -> right en 94, a 3px
      // (dentro de snapPx=6) del borde izquierdo de 'c' (97) -> corrige +3.
      final result = snapGroupMove(
        moving: [a, b],
        proposedDelta: const Offset(44, 0),
        siblings: [sibling],
        movingIds: {'a', 'b'},
        gridStep: 0,
        snapPx: 6,
      );
      expect(result.delta.dx, 47);
      expect(result.guideV, 97);
    });
  });
}
