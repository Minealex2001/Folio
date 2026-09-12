// Fase B (H4): `computeSyncMergeOutcome` corre en un isolate aparte vía
// `compute()`. Estos tests verifican, con el mecanismo REAL de Flutter (no
// solo llamando la función directamente):
//
//  1. Los `VaultPayload`/`FolioPage`/`FolioBlock` cruzan el límite de
//     isolate tal cual (sin JSON intermedio) y el resultado es correcto.
//  2. El resultado vía `compute()` es IDÉNTICO al de llamar la función
//     directamente, para cada rama de decisión (unchanged / merged /
//     guards).
//  3. Una excepción dentro del worker se propaga por `compute()` sin
//     quedarse colgado.
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/sync/vault_sync_merge.dart';

FolioPage _page(String id, String title, {String? blockText}) => FolioPage(
      id: id,
      title: title,
      blocks: [
        FolioBlock(
          id: '${id}_b0',
          type: 'paragraph',
          text: blockText ?? 'contenido de $id',
        ),
      ],
    );

VaultPayload _payload(List<FolioPage> pages) => VaultPayload(pages: pages);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compute() real: local == remote -> unchanged', () async {
    final local = _payload([_page('a', 'A')]);
    final remote = _payload([_page('a', 'A')]);

    final outcome = await compute(computeSyncMergeOutcome, <String, Object?>{
      'local': local,
      'remote': remote,
      'baseline': null,
      'baselineFingerprint': null,
      'remoteExpectedPageCount': null,
    });

    expect(outcome.kind, SyncMergeOutcomeKind.unchanged);
    expect(outcome.localFingerprint, outcome.remoteFingerprint);
    expect(outcome.result, isNull);
  });

  test('compute() real: fast-forward -> merged con el payload remoto',
      () async {
    final baseline = _payload([_page('a', 'v1')]);
    final local = _payload([_page('a', 'v1')]); // == baseline
    final remote = _payload([_page('a', 'v2')]); // cambió

    final outcome = await compute(computeSyncMergeOutcome, <String, Object?>{
      'local': local,
      'remote': remote,
      'baseline': baseline,
      'baselineFingerprint': VaultSyncMergeEngine.payloadFingerprint(baseline),
      'remoteExpectedPageCount': null,
    });

    expect(outcome.kind, SyncMergeOutcomeKind.merged);
    expect(outcome.result!.payload.pages.single.title, 'v2');
    expect(outcome.result!.changed, isTrue);
    expect(outcome.resultFingerprint, isNotNull);
  });

  test('compute() real: remoto vacío sobre local con páginas -> emptyRemoteGuard',
      () async {
    final local = _payload([_page('a', 'A'), _page('b', 'B')]);
    final remote = _payload(const []);

    final outcome = await compute(computeSyncMergeOutcome, <String, Object?>{
      'local': local,
      'remote': remote,
      'baseline': null,
      'baselineFingerprint': null,
      'remoteExpectedPageCount': null,
    });

    expect(outcome.kind, SyncMergeOutcomeKind.emptyRemoteGuard);
    expect(outcome.localPageCount, 2);
    expect(outcome.result, isNull);
  });

  test('compute() real: manifiesto remoto parcial -> partialGuard', () async {
    final local = _payload(
      List.generate(10, (i) => _page('p$i', 'Página $i')),
    );
    final remote = _payload([_page('p0', 'Página 0')]); // colapsó de 10 a 1

    final outcome = await compute(computeSyncMergeOutcome, <String, Object?>{
      'local': local,
      'remote': remote,
      'baseline': null,
      'baselineFingerprint': null,
      'remoteExpectedPageCount': 10,
    });

    expect(outcome.kind, SyncMergeOutcomeKind.partialGuard);
    expect(outcome.localPageCount, 10);
    expect(outcome.remotePageCount, 1);
  });

  test('identidad: compute() vs llamada directa dan el mismo resultado '
      '(fast-forward)', () async {
    final baseline = _payload([_page('a', 'base')]);
    final local = _payload([_page('a', 'base')]);
    final remote = _payload([_page('a', 'editado remoto')]);
    final args = <String, Object?>{
      'local': local,
      'remote': remote,
      'baseline': baseline,
      'baselineFingerprint': VaultSyncMergeEngine.payloadFingerprint(baseline),
      'remoteExpectedPageCount': null,
    };

    final direct = computeSyncMergeOutcome(args);
    final viaCompute = await compute(computeSyncMergeOutcome, args);

    expect(viaCompute.kind, direct.kind);
    expect(viaCompute.localFingerprint, direct.localFingerprint);
    expect(viaCompute.remoteFingerprint, direct.remoteFingerprint);
    expect(viaCompute.result!.changed, direct.result!.changed);
    expect(
      viaCompute.result!.payload.pages.map((p) => p.id).toList(),
      direct.result!.payload.pages.map((p) => p.id).toList(),
    );
    expect(
      viaCompute.result!.payload.pages.first.blocks.first.text,
      direct.result!.payload.pages.first.blocks.first.text,
    );
  });

  test('identidad: compute() vs llamada directa dan el mismo resultado '
      '(diff de 3 vías con conflicto)', () async {
    final baseline = _payload([_page('a', 'base', blockText: 'base')]);
    final local = _payload([_page('a', 'base', blockText: 'local edit')]);
    final remote = _payload([_page('a', 'base', blockText: 'remote edit')]);
    final args = <String, Object?>{
      'local': local,
      'remote': remote,
      'baseline': baseline,
      'baselineFingerprint': VaultSyncMergeEngine.payloadFingerprint(baseline),
      'remoteExpectedPageCount': null,
    };

    final direct = computeSyncMergeOutcome(args);
    final viaCompute = await compute(computeSyncMergeOutcome, args);

    expect(viaCompute.kind, direct.kind);
    expect(viaCompute.result!.blockConflicts.length,
        direct.result!.blockConflicts.length);
    expect(viaCompute.result!.blockConflicts.length, greaterThan(0),
        reason: 'sanity: este escenario debe generar un conflicto real');
    expect(
      viaCompute.result!.payload.pages.first.blocks.first.text,
      direct.result!.payload.pages.first.blocks.first.text,
    );
  });

  test('excepción dentro del worker se propaga por compute()', () async {
    // Falta 'local' -> el cast `as VaultPayload` revienta dentro del worker.
    final badArgs = <String, Object?>{
      'remote': _payload([_page('a', 'A')]),
      'baseline': null,
      'baselineFingerprint': null,
      'remoteExpectedPageCount': null,
    };

    await expectLater(
      compute(computeSyncMergeOutcome, badArgs),
      throwsA(anything),
    );
  });
}
