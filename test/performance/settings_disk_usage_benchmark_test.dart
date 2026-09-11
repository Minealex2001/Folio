// Fase 4 — investigación Settings/Cloud. Mide `VaultPaths.directoryTotalFileBytes`,
// que la pantalla de Ajustes (sección Vault/Backup) invoca DENTRO de `build()`
// como `future:` de un `FutureBuilder` → se re-ejecuta en cada rebuild de esa
// sección mientras está visible.
//
// El coste crece con TODO el árbol de la libreta: `repo/` (todas las páginas) +
// `versions/` (todos los snapshots de historial, .json + .zip) + `.bak`. Este
// benchmark aísla cuánto pesa el historial (`versions/`) frente a las páginas.
//
// Ejecutar:  flutter test test/performance/settings_disk_usage_benchmark_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_paths.dart';

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

Future<_Stats> _measure(Future<void> Function() body, {int iterations = 5}) async {
  await body(); // warm-up descartado
  final s = <double>[];
  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    await body();
    sw.stop();
    s.add(sw.elapsedMicroseconds / 1000.0);
  }
  return _Stats(s);
}

void _buildFakeVault(
  Directory vaultDir, {
  required int pages,
  required int snapshots,
}) {
  final repo = Directory('${vaultDir.path}/repo/pages')..createSync(recursive: true);
  for (var i = 0; i < pages; i++) {
    final id = 'page${i.toString().padLeft(6, '0')}';
    final d = Directory('${repo.path}/${id.substring(0, 2)}/$id')
      ..createSync(recursive: true);
    File('${d.path}/meta.json').writeAsStringSync('{"id":"$id","title":"P$i"}');
    File('${d.path}/blocks.jsonl').writeAsStringSync(
      List.generate(30, (b) => '{"id":"${id}_b$b","type":"paragraph","text":"x"}')
          .join('\n'),
    );
  }
  final versions = Directory('${vaultDir.path}/versions')..createSync(recursive: true);
  // Cada snapshot = un .json de metadatos + un .zip del árbol comprimido.
  final zipBlob = List.filled(24 * 1024, 0x50); // ~24 KB placeholder
  for (var i = 0; i < snapshots; i++) {
    final sid = 'snap${i.toString().padLeft(6, '0')}';
    File('${versions.path}/$sid.json').writeAsStringSync('{"id":"$sid","ts":$i}');
    File('${versions.path}/$sid.zip').writeAsBytesSync(zipBlob);
  }
}

void main() {
  final results = <String>[];

  tearDownAll(() {
    // ignore: avoid_print
    print('\n======= FASE 4 · directoryTotalFileBytes (Settings) =======');
    for (final l in results) {
      // ignore: avoid_print
      print(l);
    }
    // ignore: avoid_print
    print('  Nota: se re-ejecuta en CADA rebuild de la sección Vault/Backup');
    // ignore: avoid_print
    print('  mientras está visible (future: creado dentro de build()).');
    // ignore: avoid_print
    print('==========================================================\n');
  });

  for (final cfg in const [
    (pages: 50, snapshots: 0),
    (pages: 50, snapshots: 100),
    (pages: 250, snapshots: 0),
    (pages: 250, snapshots: 500),
    (pages: 250, snapshots: 2000),
  ]) {
    test('vault ${cfg.pages}p + ${cfg.snapshots} snapshots', () async {
      final vaultDir = Directory.systemTemp.createTempSync('folio_du_bench_');
      try {
        _buildFakeVault(vaultDir, pages: cfg.pages, snapshots: cfg.snapshots);
        final totalFiles = cfg.pages * 2 + cfg.snapshots * 2;
        final stats = await _measure(
          () => VaultPaths.directoryTotalFileBytes(vaultDir),
        );
        results.add(
          '  ${cfg.pages}p + ${cfg.snapshots} snap  (~$totalFiles ficheros) : $stats',
        );
        expect(stats.avg, greaterThan(0));
      } finally {
        try {
          vaultDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
