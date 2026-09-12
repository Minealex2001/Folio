// Investigación del "hallazgo grande" de sync multi-dispositivo: mide el
// coste REAL de `VaultSyncMergeEngine.payloadFingerprint()` / `.merge()` para
// libretas de distintos tamaños, con las funciones de PRODUCCIÓN, tal como se
// ejecutan hoy en `VaultSession.applySyncSnapshotBytes()`
// ([vault_session.dart:8061]) — el pull de device sync (Cloud + P2P), que se
// dispara cada ~3 min en foreground ([folio_cloud_device_sync.dart:89]) más
// reactivamente cuando otro dispositivo cambia algo.
//
// Reproduce la secuencia REAL de llamadas de `applySyncSnapshotBytes` cuando
// los fingerprints difieren y hay fast-forward (el caso más común: solo un
// dispositivo editó desde la última sync):
//   1) payloadFingerprint(local)   — en el call site
//   2) payloadFingerprint(remote)  — en el call site
//   3) merge(local, remote, baseline) que internamente vuelve a calcular:
//      payloadFingerprint(local) OTRA VEZ, payloadFingerprint(remote) OTRA
//      VEZ, y payloadFingerprint(base) para decidir fast-forward.
// => 5 jsonEncode del payload completo (o de partes de él) para un solo ciclo
//    de "alguien más editó, adoptar su versión", TODO en el isolate llamante.
//
// NO toca red. NO cambia nada de producción — es solo medición.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/sync/vault_sync_merge.dart';

class _Stats {
  _Stats(this.ms);
  final List<double> ms;
  double get lo => ms.reduce(min);
  double get avg => ms.reduce((a, b) => a + b) / ms.length;
  double get hi => ms.reduce(max);
  @override
  String toString() =>
      'min=${lo.toStringAsFixed(1)} avg=${avg.toStringAsFixed(1)} '
      'max=${hi.toStringAsFixed(1)} ms';
}

_Stats measure(void Function() body, {int iters = 5}) {
  body(); // warm-up
  final s = <double>[];
  for (var i = 0; i < iters; i++) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    s.add(sw.elapsedMicroseconds / 1000.0);
  }
  return _Stats(s);
}

String _deltaJson(int page, int block) => jsonEncode([
      {'insert': 'Bloque $block de la página $page con una nota sobre '},
      {
        'insert': 'arquitectura',
        'attributes': {'bold': true}
      },
      {'insert': ', migración a PostgreSQL y rendimiento del roadmap.\n'},
    ]);

VaultPayload _payload({required int pages, int blocksPerPage = 30}) {
  return VaultPayload(
    pages: List.generate(pages, (pi) {
      final id = 'sync_page_$pi';
      return FolioPage(
        id: id,
        title: 'Página $pi sobre PostgreSQL y Folio',
        blocks: List.generate(blocksPerPage, (bi) {
          final todo = bi % 7 == 0;
          return FolioBlock(
            id: '${id}_b$bi',
            type: todo ? 'todo' : 'paragraph',
            text: 'Bloque $bi de la página $pi con una nota sobre '
                'arquitectura, migración a PostgreSQL y rendimiento. '
                'Pendiente revisar el roadmap del equipo de Folio.',
            richTextDeltaJson: todo ? null : _deltaJson(pi, bi),
            checked: todo ? false : null,
          );
        }),
      );
    }),
  );
}

/// Payload con una página editada respecto al baseline (simula "otro
/// dispositivo cambió algo"), para que el fast-forward no sea un no-op
/// trivial (local != remote != base).
VaultPayload _editedCopy({required int pages}) {
  final edited = _payload(pages: pages);
  edited.pages[0].blocks[0].text = '${edited.pages[0].blocks[0].text} [editado remoto]';
  return edited;
}

void main() {
  const engine = VaultSyncMergeEngine();
  final results = <String>[];

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== DEVICE SYNC MERGE — coste por ciclo de pull (H4, investigación) =====');
    for (final l in results) {
      // ignore: avoid_print
      print(l);
    }
    print('  (min/avg/max sobre 5 iter + 1 warm-up; máquina de dev)\n');
  });

  for (final pages in [50, 100, 250, 500, 1000]) {
    test('payloadFingerprint · ${pages}p (una sola llamada)', () {
      final payload = _payload(pages: pages);
      final stats = measure(() => VaultSyncMergeEngine.payloadFingerprint(payload));
      final approxKb =
          (utf8.encode(VaultSyncMergeEngine.payloadFingerprint(payload)).length / 1024)
              .toStringAsFixed(0);
      results.add('${pages}p · payloadFingerprint x1        : $stats '
          '(fingerprint ~$approxKb KB)');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  for (final pages in [50, 100, 250, 500, 1000]) {
    test('sondeo sin cambios (caso más común, cada ~3 min en foreground) · ${pages}p',
        () {
      // "Nada cambió desde la última sync": el caso que corre SIEMPRE que el
      // sync multi-dispositivo está activo, haga el usuario algo o no.
      // `applySyncSnapshotBytes` corta aquí mismo (vault_session.dart:8069)
      // sin llegar a merge() — coste = 2x payloadFingerprint, sin excepción.
      final local = _payload(pages: pages);
      final remote = _payload(pages: pages); // idéntico -> mismo fingerprint

      final stats = measure(() {
        final localFp = VaultSyncMergeEngine.payloadFingerprint(local);
        final remoteFp = VaultSyncMergeEngine.payloadFingerprint(remote);
        if (localFp != remoteFp) {
          throw StateError('deberían coincidir en este escenario');
        }
      });
      results.add('${pages}p · sondeo "nada cambió" (2x fingerprint): $stats');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  for (final pages in [50, 100, 250, 500, 1000]) {
    test('secuencia ANTES de Fase A (merge recalcula todo) · ${pages}p', () {
      final local = _payload(pages: pages);
      final remote = _editedCopy(pages: pages);
      // baseline == local (nadie tocó esto en ESTE dispositivo desde la
      // última sync — el caso más común, dispara fast-forward).
      final baseline = _payload(pages: pages);

      final stats = measure(() {
        // 1-2) lo que hacía el call site antes de decidir si hacía falta merge.
        final localFp = VaultSyncMergeEngine.payloadFingerprint(local);
        final remoteFp = VaultSyncMergeEngine.payloadFingerprint(remote);
        if (localFp == remoteFp) return;
        // 3) lo que hacía merge() puertas adentro ANTES de Fase A: recalcula
        // local/remote/base sin usar los que ya se calcularon arriba.
        engine.merge(local: local, remote: remote, baseline: baseline);
      });
      results.add('${pages}p · secuencia ANTES de Fase A (5x fingerprint): $stats');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  for (final pages in [50, 100, 250, 500, 1000]) {
    test('secuencia DESPUÉS de Fase A (fingerprints reutilizados) · ${pages}p',
        () {
      final local = _payload(pages: pages);
      final remote = _editedCopy(pages: pages);
      final baseline = _payload(pages: pages);
      // Cache que ya mantiene VaultSession (`_syncBaselineFingerprint`): se
      // calcula una vez cuando se fija el baseline, no en cada ciclo de sync.
      final baselineFp = VaultSyncMergeEngine.payloadFingerprint(baseline);

      final stats = measure(() {
        // 1-2) el call site sigue necesitando esto para decidir si hace
        // falta merge en absoluto (no se puede evitar sin cambiar el
        // contrato: hay que saber si local == remote).
        final localFp = VaultSyncMergeEngine.payloadFingerprint(local);
        final remoteFp = VaultSyncMergeEngine.payloadFingerprint(remote);
        if (localFp == remoteFp) return;
        // 3) merge() ya NO recalcula nada — reutiliza lo de arriba +
        // baselineFp cacheado.
        engine.merge(
          local: local,
          remote: remote,
          baseline: baseline,
          localFingerprint: localFp,
          remoteFingerprint: remoteFp,
          baselineFingerprint: baselineFp,
        );
      });
      results.add('${pages}p · secuencia DESPUÉS de Fase A (2x fingerprint): $stats');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  // --- Fase B (H4): bloqueo real del isolate llamante, PATH A (todo
  // síncrono, ya con Fase A) vs PATH B (compute()).
  //
  // PATH A no tiene NINGÚN punto de cesión (`await`) real dentro del cálculo,
  // así que un Timer no puede "pillarlo a medias" — el wall-clock de la
  // llamada ES el tiempo bloqueado (ya medido arriba, en "DESPUÉS de Fase
  // A"). Para PATH B medimos cuántos ticks de un `Timer.periodic` logran
  // disparar MIENTRAS se espera el `compute()`: si el isolate llamante sigue
  // libre, disparan casi todos (igual que la sonda de tick-coverage del
  // benchmark de Cloud Pack, H1); si se bloqueara, se perderían. ---
  for (final pages in [250, 500, 1000]) {
    test('bloqueo del isolate llamante — PATH B (compute()) · ${pages}p',
        () async {
      final local = _payload(pages: pages);
      final remote = _editedCopy(pages: pages);
      final baseline = _payload(pages: pages);
      final baselineFp = VaultSyncMergeEngine.payloadFingerprint(baseline);
      const period = Duration(milliseconds: 2);

      Future<void> pathBCompute() => compute(
            computeSyncMergeOutcome,
            <String, Object?>{
              'local': local,
              'remote': remote,
              'baseline': baseline,
              'baselineFingerprint': baselineFp,
              'remoteExpectedPageCount': null,
            },
          );

      await pathBCompute(); // warm-up

      var ticks = 0;
      final sw = Stopwatch()..start();
      final t = Timer.periodic(period, (_) => ticks++);
      await pathBCompute();
      sw.stop();
      t.cancel();

      final wallMs = sw.elapsedMicroseconds / 1000.0;
      final idealTicks = wallMs / period.inMilliseconds;
      final blockedMs =
          ((idealTicks - ticks) * period.inMilliseconds).clamp(0.0, wallMs);
      final coveragePct = idealTicks <= 0 ? 100.0 : (ticks / idealTicks * 100).clamp(0.0, 100.0);

      results.add(
        '${pages}p · PATH B compute() — wall=${wallMs.toStringAsFixed(0)}ms '
        'isolate llamante libre=${coveragePct.toStringAsFixed(0)}% '
        '(bloqueado≈${blockedMs.toStringAsFixed(0)}ms de $wallMs ms totales)',
      );
      // El isolate llamante debe seguir atendiendo el Timer casi todo el
      // rato: la CPU pesada corre en el worker, no aquí.
      expect(coveragePct, greaterThan(70),
          reason: 'el isolate llamante no debería quedarse bloqueado '
              'mientras compute() trabaja en el worker');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  for (final pages in [50, 100, 250, 500, 1000]) {
    test('merge() con diff real (muchos bloques cambiados) · ${pages}p', () {
      final baseline = _payload(pages: pages);
      final local = _payload(pages: pages);
      final remote = _payload(pages: pages);
      // Simula un dispositivo que editó bastante desde el baseline en ambos
      // lados (evita el atajo de fast-forward, fuerza el diff completo).
      for (var i = 0; i < local.pages.length; i += 2) {
        local.pages[i].blocks[0].text += ' [local edit $i]';
      }
      for (var i = 1; i < remote.pages.length; i += 2) {
        remote.pages[i].blocks[0].text += ' [remote edit $i]';
      }
      final stats = measure(
        () => engine.merge(local: local, remote: remote, baseline: baseline),
      );
      results.add('${pages}p · merge() diff real (mitad de páginas tocadas): $stats');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
