import 'package:flutter_test/flutter_test.dart';

import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/sync/vault_sync_merge.dart';

void main() {
  const engine = VaultSyncMergeEngine();

  FolioPage page({
    required String id,
    String title = 'Page',
    List<FolioBlock>? blocks,
    DateTime? trashedAt,
  }) {
    return FolioPage(
      id: id,
      title: title,
      trashedAt: trashedAt,
      blocks: blocks ??
          [
            FolioBlock(id: '${id}_b0', type: 'paragraph', text: 'hello'),
          ],
    );
  }

  VaultPayload payload(List<FolioPage> pages, {Map<String, int>? tombs}) {
    return VaultPayload(
      pages: pages,
      pageTombstones: tombs ?? const {},
    );
  }

  test('páginas distintas se unen', () {
    final local = payload([page(id: 'a', title: 'A')]);
    final remote = payload([page(id: 'b', title: 'B')]);
    final baseline = payload(const []);

    final result = engine.merge(
      local: local,
      remote: remote,
      baseline: baseline,
    );

    expect(result.payload.pages.map((p) => p.id).toSet(), {'a', 'b'});
    expect(result.blockConflicts, isEmpty);
  });

  test('cambio unilateral remoto se aplica', () {
    final basePage = page(id: 'a', title: 'Base');
    final baseline = payload([basePage]);
    final local = payload([page(id: 'a', title: 'Base')]);
    final remote = payload([page(id: 'a', title: 'Remote')]);

    final result = engine.merge(
      local: local,
      remote: remote,
      baseline: baseline,
    );

    expect(result.payload.pages.single.title, 'Remote');
    expect(result.blockConflicts, isEmpty);
  });

  test('bloques concurrentes: conserva local y registra conflicto', () {
    final base = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'base')],
    );
    final local = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'local')],
    );
    final remote = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'remote')],
    );

    final result = engine.merge(
      local: payload([local]),
      remote: payload([remote]),
      baseline: payload([base]),
    );

    expect(result.payload.pages.single.blocks.single.text, 'local');
    expect(result.blockConflicts, hasLength(1));
    expect(result.blockConflicts.single.remoteBlock.text, 'remote');
    expect(result.payload.pageRevisions['a'], isNotEmpty);
  });

  test('bloque solo en remoto se añade', () {
    final base = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'one')],
    );
    final local = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'one')],
    );
    final remote = page(
      id: 'a',
      blocks: [
        FolioBlock(id: 'b1', type: 'paragraph', text: 'one'),
        FolioBlock(id: 'b2', type: 'paragraph', text: 'two'),
      ],
    );

    final result = engine.merge(
      local: payload([local]),
      remote: payload([remote]),
      baseline: payload([base]),
    );

    expect(result.payload.pages.single.blocks.map((b) => b.id), ['b1', 'b2']);
    expect(result.blockConflicts, isEmpty);
  });

  test('tombstone evita resucitar página borrada', () {
    final base = page(id: 'a');
    final local = payload(const [], tombs: {'a': 100});
    final remote = payload([page(id: 'a', title: 'Still here')]);

    final result = engine.merge(
      local: local,
      remote: remote,
      baseline: payload([base]),
    );

    expect(result.payload.pages, isEmpty);
    expect(result.payload.pageTombstones.containsKey('a'), isTrue);
  });

  test('trashedAt gana sobre activo concurrente', () {
    final trashed = DateTime.utc(2026, 1, 2);
    final base = page(id: 'a');
    final local = page(id: 'a', trashedAt: trashed);
    final remote = page(id: 'a', title: 'Edited');

    final result = engine.merge(
      local: payload([local]),
      remote: payload([remote]),
      baseline: payload([base]),
    );

    expect(result.payload.pages.single.trashedAt, trashed);
  });
}
