// Fase 0 del roadmap de producto — baseline de performance (P0), track
// continuo obligatorio. No es un test de corrección (ya cubierto en otros
// sitios): mide dos números concretos del roadmap (indexado de un vault
// grande, latencia de búsqueda) para poder comparar antes/después en cada
// fase futura, en vez de depender de "sensaciones" de lentitud.
//
// Deliberadamente acotado a lo medible sin un runner de app completa:
// `VaultSearchIndex` es Dart puro (sin widgets), así que este benchmark no
// necesita `integration_test` ni un dispositivo real — cold start y memoria
// idle se miden aparte (ver `docs/performance_baseline.md`), y "abrir
// página"/"editor con muchos bloques" (render de UI) quedan fuera de este
// archivo: instrumentarlos requeriría un harness de integration_test sobre
// una app corriendo, que es su propio proyecto — no se simula aquí con
// widget tests parciales que darían números poco representativos.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/application/vault_search_index.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';

List<FolioPage> _buildLargeVaultFixture({
  required int pageCount,
  required int blocksPerPage,
}) {
  return List.generate(pageCount, (pageIndex) {
    final pageId = 'perf_page_$pageIndex';
    return FolioPage(
      id: pageId,
      title: 'Página de rendimiento $pageIndex sobre PostgreSQL y Folio',
      blocks: List.generate(blocksPerPage, (blockIndex) {
        return FolioBlock(
          id: '${pageId}_b$blockIndex',
          type: blockIndex % 7 == 0 ? 'todo' : 'paragraph',
          text:
              'Bloque $blockIndex de la página $pageIndex. Contiene notas '
              'sobre arquitectura, migración a PostgreSQL, la reunión de '
              'equipo y una tarea pendiente de Folio para el roadmap.',
        );
      }),
    );
  });
}

void main() {
  // 500 páginas x 40 bloques = 20k bloques indexados — por encima del
  // umbral de 500 páginas que `DriftCacheEvaluation` ya señala como el
  // punto a partir del cual reconsiderar un índice FTS en disco.
  const pageCount = 500;
  const blocksPerPage = 40;

  test(
    'baseline: indexar un vault grande (${pageCount}p x ${blocksPerPage}b)',
    () {
      final pages = _buildLargeVaultFixture(
        pageCount: pageCount,
        blocksPerPage: blocksPerPage,
      );
      final index = VaultSearchIndex();

      final sw = Stopwatch()..start();
      index.rebuildFromPages(pages);
      sw.stop();

      // No hay un umbral estricto (ver Fase de performance del roadmap):
      // el valor de esto es el número impreso, comparable entre corridas.
      // ignore: avoid_print
      print(
        'BASELINE rebuildFromPages: ${sw.elapsedMilliseconds}ms '
        '(${pageCount}p x ${blocksPerPage}b = ${pageCount * blocksPerPage} bloques)',
      );
      expect(index.version, 1);
    },
  );

  test('baseline: latencia de búsqueda sobre vault grande ya indexado', () {
    final pages = _buildLargeVaultFixture(
      pageCount: pageCount,
      blocksPerPage: blocksPerPage,
    );
    final index = VaultSearchIndex();
    index.rebuildFromPages(pages);

    const queries = ['postgresql', 'reunión', 'tarea pendiente', 'folio'];
    final timingsMs = <String, int>{};
    for (final q in queries) {
      final sw = Stopwatch()..start();
      final results = index.search(q);
      sw.stop();
      timingsMs[q] = sw.elapsedMicroseconds;
      expect(results, isNotEmpty, reason: 'query "$q" debería tener matches');
    }

    // ignore: avoid_print
    print(
      'BASELINE search latency (µs) sobre $pageCount páginas: $timingsMs',
    );
  });
}
