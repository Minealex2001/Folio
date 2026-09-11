import 'package:flutter_test/flutter_test.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_math.dart';

void main() {
  group('columnWidth', () {
    test('divides available width evenly minus gaps', () {
      // 3 columnas, gap=16, ancho=616 -> (616 - 32) / 3 = 194.666...
      final width = DashboardGridMath.columnWidth(
        availableWidth: 616,
        columns: 3,
        gap: 16,
      );
      expect(width, closeTo(194.67, 0.01));
    });

    test('returns full width for a single column', () {
      final width = DashboardGridMath.columnWidth(
        availableWidth: 400,
        columns: 1,
        gap: 16,
      );
      expect(width, 400);
    });

    test('never returns negative width when gaps exceed available space', () {
      final width = DashboardGridMath.columnWidth(
        availableWidth: 10,
        columns: 5,
        gap: 100,
      );
      expect(width, 0);
    });
  });

  group('columnLeft', () {
    test('computes left edge from column index, width and gap', () {
      expect(
        DashboardGridMath.columnLeft(columnIndex: 0, columnWidth: 200, gap: 16),
        0,
      );
      expect(
        DashboardGridMath.columnLeft(columnIndex: 1, columnWidth: 200, gap: 16),
        216,
      );
      expect(
        DashboardGridMath.columnLeft(columnIndex: 2, columnWidth: 200, gap: 16),
        432,
      );
    });
  });

  group('columnIndexForX', () {
    test('maps x within the first column to index 0', () {
      final index = DashboardGridMath.columnIndexForX(
        x: 50,
        columnWidth: 200,
        gap: 16,
        columns: 3,
      );
      expect(index, 0);
    });

    test('maps x within the second column to index 1', () {
      final index = DashboardGridMath.columnIndexForX(
        x: 250,
        columnWidth: 200,
        gap: 16,
        columns: 3,
      );
      expect(index, 1);
    });

    test('clamps x beyond the last column to the last index', () {
      final index = DashboardGridMath.columnIndexForX(
        x: 10000,
        columnWidth: 200,
        gap: 16,
        columns: 3,
      );
      expect(index, 2);
    });

    test('clamps negative x to index 0', () {
      final index = DashboardGridMath.columnIndexForX(
        x: -50,
        columnWidth: 200,
        gap: 16,
        columns: 3,
      );
      expect(index, 0);
    });
  });

  group('snapToRowUnit', () {
    test('rounds to the nearest multiple of the row unit', () {
      expect(DashboardGridMath.snapToRowUnit(100, 32), 96);
      expect(DashboardGridMath.snapToRowUnit(110, 32), 96);
      expect(DashboardGridMath.snapToRowUnit(115, 32), 128);
    });

    test('returns the value unchanged when rowUnit is 0', () {
      expect(DashboardGridMath.snapToRowUnit(123.4, 0), 123.4);
    });
  });

  group('isNearColumnBoundary', () {
    test('true near the left edge', () {
      expect(
        DashboardGridMath.isNearColumnBoundary(
          xWithinColumn: 5,
          columnWidth: 200,
        ),
        isTrue,
      );
    });

    test('true near the right edge', () {
      expect(
        DashboardGridMath.isNearColumnBoundary(
          xWithinColumn: 195,
          columnWidth: 200,
        ),
        isTrue,
      );
    });

    test('false in the middle', () {
      expect(
        DashboardGridMath.isNearColumnBoundary(
          xWithinColumn: 100,
          columnWidth: 200,
        ),
        isFalse,
      );
    });
  });
}
