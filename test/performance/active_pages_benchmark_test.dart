// Mide el coste real de `VaultSession.activePages` (filtro + copia
// `List.unmodifiable` sin caché) antes de decidir si de verdad hace falta
// cachearlo. Reproduce el patrón real: `workspace_page.dart` lo llama una
// vez por build cuando hay pestañas abiertas.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';

List<FolioPage> _pages(int n, {double trashedFraction = 0.05}) {
  final r = Random(7);
  return List.generate(n, (i) {
    final trashed = r.nextDouble() < trashedFraction;
    return FolioPage(
      id: 'p$i',
      title: 'Página $i',
      trashedAt: trashed ? DateTime.now() : null,
      blocks: [FolioBlock(id: 'p${i}_b0', type: 'paragraph', text: 'texto')],
    );
  });
}

List<FolioPage> activePagesOf(List<FolioPage> pages) =>
    List.unmodifiable(pages.where((p) => !p.isTrashed));

void main() {
  for (final n in [500, 1000, 2000, 5000, 10000]) {
    test('activePages · $n páginas x100 llamadas', () {
      final pages = _pages(n);
      activePagesOf(pages); // warm-up
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        activePagesOf(pages);
      }
      sw.stop();
      final perCallUs = sw.elapsedMicroseconds / 100;
      // ignore: avoid_print
      print('$n páginas: ${perCallUs.toStringAsFixed(1)} µs/llamada '
          '(${sw.elapsedMicroseconds} µs / 100 llamadas)');
    });
  }
}
