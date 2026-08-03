import 'package:flutter_test/flutter_test.dart';

import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/slack_integration_state.dart';
import 'package:folio/models/teams_integration_state.dart';
import 'package:folio/models/spotify_integration_state.dart';
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

  test('slack y teams: si ambos lados tienen conexiones, gana remoto', () {
    const localSlack = SlackIntegrationState(
      connections: [
        SlackConnection(
          id: 'local',
          label: 'Local',
          webhookUrl: 'https://hooks.slack.com/local',
        ),
      ],
    );
    const remoteSlack = SlackIntegrationState(
      connections: [
        SlackConnection(
          id: 'remote',
          label: 'Remote',
          webhookUrl: 'https://hooks.slack.com/remote',
        ),
      ],
    );
    const localTeams = TeamsIntegrationState(
      connections: [
        TeamsConnection(
          id: 'local',
          label: 'Local',
          webhookUrl: 'https://teams.local/webhook',
        ),
      ],
    );
    const remoteTeams = TeamsIntegrationState(
      connections: [
        TeamsConnection(
          id: 'remote',
          label: 'Remote',
          webhookUrl: 'https://teams.remote/webhook',
        ),
      ],
    );

    final local = VaultPayload(
      pages: const [],
      slack: localSlack,
      teams: localTeams,
    );
    final remote = VaultPayload(
      pages: const [],
      slack: remoteSlack,
      teams: remoteTeams,
    );

    final result = engine.merge(
      local: local,
      remote: remote,
      baseline: VaultPayload(pages: const []),
    );

    // Distintas conexiones (ids distintos) en cada lado deben fusionarse por
    // id, no descartar una wholesale — cada dispositivo añadió la suya.
    expect(
      result.payload.slack.connections.map((c) => c.id).toSet(),
      {'local', 'remote'},
    );
    expect(
      result.payload.teams.connections.map((c) => c.id).toSet(),
      {'local', 'remote'},
    );
  });

  test('slack: misma conexión (mismo id) editada en ambos lados, gana local', () {
    const localSlack = SlackIntegrationState(
      connections: [
        SlackConnection(
          id: 'shared',
          label: 'Local label',
          webhookUrl: 'https://hooks.slack.com/local',
        ),
      ],
    );
    const remoteSlack = SlackIntegrationState(
      connections: [
        SlackConnection(
          id: 'shared',
          label: 'Remote label',
          webhookUrl: 'https://hooks.slack.com/remote',
        ),
      ],
    );

    final result = engine.merge(
      local: VaultPayload(pages: const [], slack: localSlack),
      remote: VaultPayload(pages: const [], slack: remoteSlack),
      baseline: VaultPayload(pages: const []),
    );

    expect(result.payload.slack.connections.single.label, 'Local label');
  });

  test('slack y teams: solo remoto con conexiones se conserva', () {
    const remoteSlack = SlackIntegrationState(
      connections: [
        SlackConnection(
          id: 'remote',
          label: 'Remote',
          webhookUrl: 'https://hooks.slack.com/remote',
        ),
      ],
    );

    final local = VaultPayload(pages: const []);
    final remote = VaultPayload(pages: const [], slack: remoteSlack);

    final result = engine.merge(
      local: local,
      remote: remote,
      baseline: VaultPayload(pages: const []),
    );

    expect(result.payload.slack.connections.single.id, 'remote');
  });

  test('fast-forward: local sin cambios desde baseline adopta remoto entero', () {
    final baseline = payload([
      page(id: 'a', title: 'A'),
      page(id: 'b', title: 'B'),
    ]);
    // Local idéntico al baseline: no ha cambiado nada en este dispositivo.
    final local = payload([
      page(id: 'a', title: 'A'),
      page(id: 'b', title: 'B'),
    ]);
    // Remoto avanzó en varias páginas a la vez.
    final remote = payload([
      page(id: 'a', title: 'A edited remotely'),
      page(id: 'b', title: 'B edited remotely'),
      page(id: 'c', title: 'New remote page'),
    ]);

    final result = engine.merge(
      local: local,
      remote: remote,
      baseline: baseline,
    );

    expect(
      result.payload.pages.map((p) => p.title).toSet(),
      {'A edited remotely', 'B edited remotely', 'New remote page'},
    );
    expect(result.blockConflicts, isEmpty);
    expect(result.changed, isTrue);
  });

  test('conflicto real captura el bloque base (diff de 3 vías)', () {
    final base = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'base text')],
    );
    final local = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'local text')],
    );
    final remote = page(
      id: 'a',
      blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'remote text')],
    );

    final result = engine.merge(
      local: payload([local]),
      remote: payload([remote]),
      baseline: payload([base]),
    );

    expect(result.blockConflicts, hasLength(1));
    expect(result.blockConflicts.single.baseBlock?.text, 'base text');
    expect(result.blockConflicts.single.localBlock.text, 'local text');
    expect(result.blockConflicts.single.remoteBlock.text, 'remote text');
  });

  test('spotify: conexiones distintas en cada lado se fusionan por id', () {
    final localSpotify = SpotifyIntegrationState(
      connections: [
        SpotifyConnection(
          id: 'local',
          label: 'Local',
          accessToken: 'a1',
          refreshToken: 'r1',
          expiresAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    final remoteSpotify = SpotifyIntegrationState(
      connections: [
        SpotifyConnection(
          id: 'remote',
          label: 'Remote',
          accessToken: 'a2',
          refreshToken: 'r2',
          expiresAt: DateTime.utc(2026, 2, 1),
        ),
      ],
    );
    final result = engine.merge(
      local: VaultPayload(pages: const [], spotify: localSpotify),
      remote: VaultPayload(pages: const [], spotify: remoteSpotify),
      baseline: VaultPayload(pages: const []),
    );
    // Bug corregido: antes se descartaba wholesale la lista local si ambos
    // lados tenían conexiones no vacías. Ahora se fusionan por id, así que
    // una conexión añadida en cada dispositivo sobrevive en ambos.
    expect(
      result.payload.spotify.connections.map((c) => c.id).toSet(),
      {'local', 'remote'},
    );
  });

  group('remoto parcial (bug de colapso por sync)', () {
    List<FolioPage> manyPages(int n) =>
        List.generate(n, (i) => page(id: 'p$i', title: 'Page $i'));

    test(
        'fast-forward NO adopta un remoto que colapsó frente al baseline',
        () {
      final baseline = payload(manyPages(6));
      // Local sin cambios desde el baseline: dispararía el atajo fast-forward
      // de no ser por la protección de remoto parcial.
      final local = payload(manyPages(6));
      // Remoto parcial: manifiesto autoconsistente (declara 1, trae 1) pero
      // muy por debajo del baseline — exactamente el bug reportado (push con
      // el vault a medio cargar en memoria).
      final remote = payload([page(id: 'p0', title: 'Page 0')]);

      final result = engine.merge(
        local: local,
        remote: remote,
        baseline: baseline,
        remoteExpectedPageCount: 1,
      );

      // No debe colapsar a solo la página del remoto parcial.
      expect(result.payload.pages.length, 6);
      expect(
        result.payload.pages.map((p) => p.id).toSet(),
        {'p0', 'p1', 'p2', 'p3', 'p4', 'p5'},
      );
    });

    test(
        'diff normal NO tombstona páginas ausentes solo por un remoto parcial',
        () {
      final baseline = payload(manyPages(6));
      // Local con un cambio real (evita el atajo fast-forward) para forzar
      // el camino de diff/tombstones.
      final local = payload([
        page(id: 'p0', title: 'Edited locally'),
        ...manyPages(6).skip(1),
      ]);
      final remote = payload([page(id: 'p0', title: 'Page 0')]);

      final result = engine.merge(
        local: local,
        remote: remote,
        baseline: baseline,
        remoteExpectedPageCount: 1,
      );

      // Las 5 páginas ausentes del remoto parcial se conservan, no se borran.
      expect(result.payload.pages.length, 6);
      expect(
        result.payload.pageTombstones.keys
            .where((id) => id != 'p0')
            .toList(),
        isEmpty,
      );
    });

    test(
        'looksSuspiciouslyPartial: desajuste manifiesto/descarga marca '
        'sospechoso aunque el tamaño no cruce el umbral por sí solo', () {
      // Baseline pequeño (1 página): la comparación de tamaño por sí sola no
      // dispararía (está por debajo de _partialRemoteMinBasePages). Pero si
      // el manifiesto declaraba 5 páginas y solo se resolvieron 3, eso es
      // indicio de truncado en tránsito — señal independiente del tamaño.
      expect(
        VaultSyncMergeEngine.looksSuspiciouslyPartial(
          basePageCount: 1,
          remotePageCount: 3,
          remoteExpectedPageCount: 5,
        ),
        isTrue,
      );
      // Mismo recuento declarado que el descargado: autoconsistente, se
      // evalúa solo por tamaño frente al baseline (aquí pequeño => no
      // sospechoso).
      expect(
        VaultSyncMergeEngine.looksSuspiciouslyPartial(
          basePageCount: 1,
          remotePageCount: 3,
          remoteExpectedPageCount: 3,
        ),
        isFalse,
      );
      // Sin metadata de manifiesto (P2P legacy, o v2 sin el campo nuevo): se
      // evalúa solo por tamaño, comportamiento sin cambios.
      expect(
        VaultSyncMergeEngine.looksSuspiciouslyPartial(
          basePageCount: 59,
          remotePageCount: 1,
        ),
        isTrue,
      );
    });

    test(
        'borrado genuino de 3 vías sigue funcionando sin remoteExpectedPageCount',
        () {
      // Mismo test que 'tombstone evita resucitar página borrada' de más
      // arriba, para confirmar que el nuevo parámetro opcional no cambia el
      // comportamiento cuando no se conoce (compatibilidad con P2P sync).
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
  });
}
