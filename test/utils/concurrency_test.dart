import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:folio/utils/concurrency.dart';

void main() {
  test('mapConcurrent preserves input order regardless of completion order',
      () async {
    final completionOrder = <int>[];
    final delaysMs = [30, 5, 20, 1, 15];

    final results = await mapConcurrent(delaysMs, (delay) async {
      await Future<void>.delayed(Duration(milliseconds: delay));
      completionOrder.add(delay);
      return delay * 2;
    }, concurrency: 4);

    expect(results, delaysMs.map((d) => d * 2).toList());
    // Con concurrencia > 1 y delays distintos, al menos algún item debería
    // completar fuera de su orden posicional (si no, el test de "orden
    // preservado" sería trivial). No lo exigimos estrictamente para evitar
    // flakiness, pero sí que el resultado nunca dependa de ese orden.
    expect(completionOrder.length, delaysMs.length);
  });

  test('mapConcurrent never runs more than `concurrency` tasks at once', () async {
    var active = 0;
    var maxActive = 0;
    final items = List.generate(10, (i) => i);

    await mapConcurrent(items, (i) async {
      active++;
      maxActive = active > maxActive ? active : maxActive;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      active--;
    }, concurrency: 3);

    expect(maxActive, lessThanOrEqualTo(3));
  });

  test('mapConcurrent propagates an error from a failing task', () async {
    Object? caught;
    try {
      await mapConcurrent([1, 2, 3], (i) async {
        if (i == 2) throw StateError('boom');
        return i;
      }, concurrency: 2);
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<StateError>());
  });

  test('mapConcurrent returns empty list for empty input', () async {
    final results = await mapConcurrent<int, int>([], (i) async => i);
    expect(results, isEmpty);
  });
}
