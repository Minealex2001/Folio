// Fase 2 del plan de performance — baseline de PERSISTENCIA (medir antes de
// tocar nada). Complementa `search_index_benchmark_test.dart`.
//
// Mide, para libretas de 25 / 50 / 100 / 250 / 500 páginas x ~30 bloques:
//
//   1. `VaultLocalStorage.decomposeAndStoreAt` — el guardado v1 COMPLETO
//      (serializar toda la libreta + escribir el árbol repo/ + swap).
//      Es lo que dispara el debounce de 450 ms del editor en cada pausa de
//      escritura, en el UI isolate.
//   2. Serialización pura — solo `canonicalJson(block.toJson())` de todos los
//      bloques, para separar el coste de CPU (jsonEncode + ordenación de
//      claves) del coste de I/O.
//   3. `VaultSearchIndex.rebuildFromPages` — la reconstrucción íntegra del
//      índice de búsqueda que `persistNow()` hace tras CADA guardado.
//
// No es un test de corrección. El valor es el número impreso, comparable
// entre corridas y entre fases. No hay asserts de umbral (los umbrales de
// referencia van en el informe de la fase): 16 ms = 1 frame perdido a 60 fps,
// >100 ms = jank visible, >500 ms = congelación perceptible.
//
// Ejecutar:
//   flutter test test/performance/persistence_benchmark_test.dart
//
// Dart puro + dart:io (sin widgets, sin dispositivo). `decomposeAndStoreAt`
// escribe en un directorio temporal real, así que el número de I/O depende
// del disco de la máquina — es justo lo que queremos medir.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/application/vault_search_index.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';

const List<int> _pageCounts = [25, 50, 100, 250, 500];
const int _blocksPerPage = 30;

/// Nº de repeticiones cronometradas por escenario (además de 1 de calentamiento
/// que se descarta).
const int _iterations = 5;

String _fakeDeltaJson(int pageIndex, int blockIndex) {
  // Delta plausible de un párrafo WYSIWYG real: texto + un par de tramos con
  // atributos inline. `richTextDeltaJson` se guarda tal cual en cada bloque,
  // así que su tamaño pesa en la serialización.
  final ops = [
    {
      'insert': 'Bloque $blockIndex de la página $pageIndex con una nota sobre ',
    },
    {
      'insert': 'arquitectura',
      'attributes': {'bold': true},
    },
    {'insert': ', migración a PostgreSQL y '},
    {
      'insert': 'rendimiento',
      'attributes': {'italic': true},
    },
    {'insert': '. Pendiente revisar el roadmap del equipo de Folio.\n'},
  ];
  return jsonEncode(ops);
}

List<FolioPage> _buildVault({
  required int pageCount,
  required int blocksPerPage,
}) {
  return List.generate(pageCount, (pageIndex) {
    final pageId = 'perf_page_$pageIndex';
    return FolioPage(
      id: pageId,
      title: 'Página de rendimiento $pageIndex sobre PostgreSQL y Folio',
      blocks: List.generate(blocksPerPage, (blockIndex) {
        final isTodo = blockIndex % 7 == 0;
        return FolioBlock(
          id: '${pageId}_b$blockIndex',
          type: isTodo ? 'todo' : 'paragraph',
          text:
              'Bloque $blockIndex de la página $pageIndex con una nota sobre '
              'arquitectura, migración a PostgreSQL y rendimiento. Pendiente '
              'revisar el roadmap del equipo de Folio.',
          richTextDeltaJson: isTodo ? null : _fakeDeltaJson(pageIndex, blockIndex),
          checked: isTodo ? false : null,
        );
      }),
    );
  });
}

class _Stats {
  _Stats(this.samplesMs);
  final List<double> samplesMs;
  double get min => samplesMs.reduce((a, b) => a < b ? a : b);
  double get max => samplesMs.reduce((a, b) => a > b ? a : b);
  double get avg => samplesMs.reduce((a, b) => a + b) / samplesMs.length;
  @override
  String toString() =>
      'min=${min.toStringAsFixed(1)}ms avg=${avg.toStringAsFixed(1)}ms '
      'max=${max.toStringAsFixed(1)}ms';
}

_Stats _measure(void Function() body, {int iterations = _iterations}) {
  body(); // calentamiento, descartado
  final samples = <double>[];
  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }
  return _Stats(samples);
}

Future<_Stats> _measureAsync(
  Future<void> Function() body, {
  int iterations = _iterations,
}) async {
  await body(); // calentamiento, descartado
  final samples = <double>[];
  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    await body();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }
  return _Stats(samples);
}

/// Serialización pura: replica exactamente lo que `VaultPayloadToTree` hace
/// por bloque (`canonicalJson(block.toJson())`), sin tocar disco.
int _serializeAllBlocks(List<FolioPage> pages) {
  var chars = 0;
  for (final page in pages) {
    for (final block in page.blocks) {
      chars += canonicalJson(block.toJson()).length;
    }
  }
  return chars;
}

void main() {
  final results = <String>[];

  tearDownAll(() {
    // ignore: avoid_print
    print('\n================ FASE 2 · BASELINE PERSISTENCIA ================');
    for (final line in results) {
      // ignore: avoid_print
      print(line);
    }
    // ignore: avoid_print
    print('===============================================================\n');
  });

  for (final pageCount in _pageCounts) {
    final label = '${pageCount}p x ${_blocksPerPage}b '
        '(${pageCount * _blocksPerPage} bloques)';

    test('baseline persistencia · $label', () async {
      final pages = _buildVault(
        pageCount: pageCount,
        blocksPerPage: _blocksPerPage,
      );
      final payload = VaultPayload(pages: pages);

      // --- 1. Serialización pura (CPU) ---
      var serializedChars = 0;
      final serStats = _measure(() {
        serializedChars = _serializeAllBlocks(pages);
      });

      // --- 2. decomposeAndStoreAt: guardado v1 COMPLETO (CPU + I/O + swap) ---
      final tmpDir = Directory.systemTemp.createTempSync('folio_perf_persist_');
      _Stats storeStats;
      _Stats inc1Stats;
      _Stats inc5Stats;
      _Stats incAllStats;
      try {
        storeStats = await _measureAsync(() async {
          await VaultLocalStorage.decomposeAndStoreAt(tmpDir, payload);
        });

        // El árbol ya existe → así es como persiste ahora una edición de
        // contenido: `storePageAt` por cada página realmente modificada.
        await VaultLocalStorage.decomposeAndStoreAt(tmpDir, payload);

        // DESPUÉS · 1 página modificada
        inc1Stats = await _measureAsync(() async {
          await VaultLocalStorage.storePageAt(tmpDir, pages[pageCount ~/ 2], const []);
        });

        // DESPUÉS · 5 páginas modificadas (o todas si la vault es menor)
        final five = pages.take(5).toList();
        inc5Stats = await _measureAsync(() async {
          for (final pg in five) {
            await VaultLocalStorage.storePageAt(tmpDir, pg, const []);
          }
        });

        // DESPUÉS · "muchas": todas las páginas vía incremental (peor caso;
        // debería aproximarse al coste del guardado completo).
        incAllStats = await _measureAsync(() async {
          for (final pg in pages) {
            await VaultLocalStorage.storePageAt(tmpDir, pg, const []);
          }
        }, iterations: 3);
      } finally {
        try {
          tmpDir.deleteSync(recursive: true);
        } catch (_) {}
      }

      // --- 3. Reconstrucción del índice de búsqueda ---
      final index = VaultSearchIndex();
      final indexStats = _measure(() {
        index.rebuildFromPages(pages);
      });

      final approxKb = (serializedChars / 1024).toStringAsFixed(0);
      results.add(
        '$label\n'
        '    serialización pura        : $serStats  (~$approxKb KB JSON bloques)\n'
        '    ANTES  decomposeAndStore  : $storeStats\n'
        '    DESPUÉS storePageAt x1     : $inc1Stats\n'
        '    DESPUÉS storePageAt x5     : $inc5Stats\n'
        '    DESPUÉS storePageAt xTODAS : $incAllStats\n'
        '    rebuildSearchIndex        : $indexStats',
      );

      expect(index.version, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
