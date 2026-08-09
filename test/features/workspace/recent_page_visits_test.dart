import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/recent_page_visits.dart';

/// Fase 2 del roadmap de producto — el formato persistido pasó de
/// `pageId|visitedAtMs` a `pageId|visitedAtMs|blockId` (blockId opcional).
/// Estos tests cubren el round-trip y, sobre todo, que las entradas legadas
/// de 2 campos y las de 1 campo (formato pre-timestamp) se sigan
/// interpretando igual que antes.
void main() {
  group('RecentPageVisitsStore.decodeRawList', () {
    test('formato legado sin timestamp asigna tiempos decrecientes en orden', () {
      final decoded = RecentPageVisitsStore.decodeRawList(['a', 'b', 'c']);
      expect(decoded.map((v) => v.pageId).toList(), ['a', 'b', 'c']);
      expect(decoded[0].visitedAtMs, greaterThan(decoded[1].visitedAtMs));
      expect(decoded.every((v) => v.lastBlockId == null), isTrue);
    });

    test('formato pageId|visitedAtMs (2 campos) sin blockId', () {
      final decoded = RecentPageVisitsStore.decodeRawList(['p1|1000', 'p2|2000']);
      expect(decoded[0].pageId, 'p1');
      expect(decoded[0].visitedAtMs, 1000);
      expect(decoded[0].lastBlockId, isNull);
    });

    test('formato pageId|visitedAtMs|blockId (3 campos) round-trip', () {
      final decoded = RecentPageVisitsStore.decodeRawList(['p1|1000|b1']);
      expect(decoded.single.pageId, 'p1');
      expect(decoded.single.visitedAtMs, 1000);
      expect(decoded.single.lastBlockId, 'b1');
    });

    test('mezcla de entradas con y sin blockId no se confunde con formato legado', () {
      final decoded = RecentPageVisitsStore.decodeRawList(['p1|1000|b1', 'p2|2000']);
      expect(decoded.length, 2);
      expect(decoded.firstWhere((v) => v.pageId == 'p1').lastBlockId, 'b1');
      expect(decoded.firstWhere((v) => v.pageId == 'p2').lastBlockId, isNull);
    });
  });

  group('RecentPageVisitsStore.encodeList', () {
    test('omite el tercer campo cuando no hay lastBlockId', () {
      final encoded = RecentPageVisitsStore.encodeList([
        const RecentPageVisit(pageId: 'p1', visitedAtMs: 1000),
      ]);
      expect(encoded, ['p1|1000']);
    });

    test('incluye el blockId cuando existe, y decodeRawList lo recupera', () {
      final visits = [
        const RecentPageVisit(pageId: 'p1', visitedAtMs: 1000, lastBlockId: 'b1'),
      ];
      final encoded = RecentPageVisitsStore.encodeList(visits);
      expect(encoded, ['p1|1000|b1']);
      final decoded = RecentPageVisitsStore.decodeRawList(encoded);
      expect(decoded.single.lastBlockId, 'b1');
    });
  });

  group('RecentPageVisitsStore.withUpdatedLastBlock', () {
    test('actualiza el blockId de la página sin tocar visitedAtMs ni orden', () {
      final current = [
        const RecentPageVisit(pageId: 'p1', visitedAtMs: 2000),
        const RecentPageVisit(pageId: 'p2', visitedAtMs: 1000),
      ];
      final next = RecentPageVisitsStore.withUpdatedLastBlock(current, 'p1', 'b1');
      expect(next.map((v) => v.pageId).toList(), ['p1', 'p2']);
      expect(next[0].visitedAtMs, 2000);
      expect(next[0].lastBlockId, 'b1');
    });

    test('no-op si la página no está en la lista (misma instancia devuelta)', () {
      final current = [const RecentPageVisit(pageId: 'p1', visitedAtMs: 1000)];
      final next = RecentPageVisitsStore.withUpdatedLastBlock(current, 'p2', 'b1');
      expect(identical(next, current), isTrue);
    });

    test('no-op si el blockId ya es el mismo (misma instancia devuelta)', () {
      final current = [
        const RecentPageVisit(pageId: 'p1', visitedAtMs: 1000, lastBlockId: 'b1'),
      ];
      final next = RecentPageVisitsStore.withUpdatedLastBlock(current, 'p1', 'b1');
      expect(identical(next, current), isTrue);
    });
  });

  group('RecentPageVisitsStore.withNewVisit', () {
    test('una visita nueva no lleva lastBlockId (aún no se conoce)', () {
      final next = RecentPageVisitsStore.withNewVisit([], 'p1');
      expect(next.single.lastBlockId, isNull);
    });

    test('revisitar una página existente descarta su lastBlockId previo '
        '(es una visita nueva, no una continuación)', () {
      final current = [
        const RecentPageVisit(pageId: 'p1', visitedAtMs: 1000, lastBlockId: 'b1'),
      ];
      final next = RecentPageVisitsStore.withNewVisit(current, 'p1');
      expect(next.single.lastBlockId, isNull);
    });
  });
}
