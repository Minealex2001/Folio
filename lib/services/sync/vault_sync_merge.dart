import 'dart:convert';

import '../../data/vault_payload.dart';
import '../../data/vault_paths.dart';
import '../../models/block.dart';
import '../../models/folio_page.dart';
import '../../models/folio_page_revision.dart';
import '../../models/jira_integration_state.dart';
import '../../models/youtrack_integration_state.dart';
import '../../models/trello_integration_state.dart';
import '../../models/github_integration_state.dart';
import '../../models/gitlab_integration_state.dart';
import '../../models/slack_integration_state.dart';
import '../../models/teams_integration_state.dart';
import '../../models/spotify_integration_state.dart';
import '../../models/ytmusic_integration_state.dart';
import '../../models/discord_integration_state.dart';
import '../../models/system_media_integration_state.dart';

/// Conflicto de un bloque concreto tras un merge a 3 vías.
class VaultSyncBlockConflict {
  const VaultSyncBlockConflict({
    required this.pageId,
    required this.blockId,
    required this.localBlock,
    required this.remoteBlock,
    this.baseBlock,
  });

  final String pageId;
  final String blockId;
  final FolioBlock localBlock;
  final FolioBlock remoteBlock;

  /// Versión del bloque en el ancestro común (`baseline`), si existía. Nulo
  /// si el bloque se creó después del último baseline conocido por ambos
  /// lados — permite un diff de 3 vías (local/base/remoto) en vez de solo 2.
  final FolioBlock? baseBlock;
}

/// Resultado del merge semántico local · remoto · baseline.
class VaultSyncMergeResult {
  const VaultSyncMergeResult({
    required this.payload,
    required this.blockConflicts,
    required this.attachmentPaths,
    required this.changed,
  });

  final VaultPayload payload;
  final List<VaultSyncBlockConflict> blockConflicts;
  final List<String> attachmentPaths;
  final bool changed;
}

/// Motor compartido Cloud + P2P: merge por página/bloque sin CRDT de caracteres.
class VaultSyncMergeEngine {
  const VaultSyncMergeEngine();

  /// Huella estable de una página (contenido syncable).
  static String pageFingerprint(FolioPage page) => jsonEncode(page.toJson());

  /// Huella estable de un bloque.
  static String blockFingerprint(FolioBlock block) =>
      jsonEncode(block.toJson());

  /// Huella del payload completo (orden canónico de páginas por id).
  static String payloadFingerprint(VaultPayload payload) {
    final pages = List<FolioPage>.from(payload.pages)
      ..sort((a, b) => a.id.compareTo(b.id));
    final tombs = Map<String, int>.from(payload.pageTombstones);
    final tombKeys = tombs.keys.toList()..sort();
    return jsonEncode({
      'pages': pages.map((p) => p.toJson()).toList(),
      'displayName': payload.displayName.trim(),
      'pageOrderByParent': payload.pageOrderByParent,
      'pageTombstones': {for (final k in tombKeys) k: tombs[k]},
      'comments': payload.comments.map((c) => c.toJson()).toList(),
      'pageTemplates': payload.pageTemplates.map((t) => t.toJson()).toList(),
      'jira': payload.jira.toJson(),
      'youtrack': payload.youtrack.toJson(),
      'trello': payload.trello.toJson(),
      'github': payload.github.toJson(),
      'gitlab': payload.gitlab.toJson(),
      'slack': payload.slack.toJson(),
      'teams': payload.teams.toJson(),
      'spotify': payload.spotify.toJson(),
      'ytMusic': payload.ytMusic.toJson(),
      'discord': payload.discord.toJson(),
      'systemMedia': payload.systemMedia.toJson(),
    });
  }

  /// Huella corta (FNV-1a) apta para metadatos en la nube.
  static String payloadFingerprintShort(VaultPayload payload) {
    final data = utf8.encode(payloadFingerprint(payload));
    var hash = 0x811c9dc5;
    const prime = 0x01000193;
    const mask = 0xffffffff;
    for (final b in data) {
      hash ^= b;
      hash = (hash * prime) & mask;
    }
    // Segundo pase para más bits útiles.
    var hash2 = 0x811c9dc5;
    for (var i = data.length - 1; i >= 0; i--) {
      hash2 ^= data[i];
      hash2 = (hash2 * prime) & mask;
    }
    return '${hash.toRadixString(16).padLeft(8, '0')}'
        '${hash2.toRadixString(16).padLeft(8, '0')}';
  }

  /// Rutas de adjuntos referenciadas por bloques (`attachments/...`).
  static List<String> collectAttachmentPaths(VaultPayload payload) {
    final out = <String>{};
    for (final page in payload.pages) {
      for (final block in page.blocks) {
        final url = block.url?.trim() ?? '';
        if (_isManagedAttachmentPath(url)) {
          out.add(url.replaceAll(r'\', '/'));
        }
      }
    }
    final list = out.toList()..sort();
    return list;
  }

  static bool _isManagedAttachmentPath(String? path) {
    final t = path?.trim() ?? '';
    if (t.isEmpty) return false;
    final n = t.replaceAll(r'\', '/');
    return n.startsWith('${VaultPaths.attachmentsDirName}/');
  }

  FolioPage clonePage(FolioPage page) =>
      FolioPage.fromJson(Map<String, dynamic>.from(page.toJson()));

  FolioBlock cloneBlock(FolioBlock block) =>
      FolioBlock.fromJson(Map<String, dynamic>.from(block.toJson()));

  /// Umbral bajo el cual un `remote.pages.length` respecto a `base.pages.length`
  /// se considera "sospechosamente parcial" en vez de un borrado real: por
  /// debajo del 40% del baseline. Solo aplica con al menos 4 páginas en el
  /// baseline, para no disparar falsos positivos en libretas pequeñas donde
  /// un borrado legítimo de una o dos páginas ya cruza ese porcentaje.
  static const double _partialRemoteThreshold = 0.4;
  static const int _partialRemoteMinBasePages = 4;

  /// Expuesto (no privado) porque los guards de más arriba en la pila
  /// (`vault_session.dart`, `headless_device_sync_vault.dart`) necesitan el
  /// mismo criterio para decidir si negarse a aplicar un remoto ANTES de
  /// invocar `merge()` — por ejemplo cuando el baseline en memoria aún no se
  /// sembró y `merge()` vería `basePageCount == 0` (no dispararía el guard
  /// interno de fast-forward/tombstones por sí solo).
  ///
  /// OJO: el bug real que motivó esto es que el DISPOSITIVO QUE HACE PUSH
  /// tenía en memoria un payload ya truncado (p. ej. libreta a medio cargar)
  /// — el manifiesto que ese dispositivo escribe declara fielmente ese mismo
  /// recuento truncado, así que `remoteExpectedPageCount` (lo declarado por
  /// el propio manifiesto) coincide trivialmente con `remotePageCount` (lo
  /// descargado) en el caso que nos importa. Por eso la comparación contra
  /// `basePageCount` es la señal PRINCIPAL y se evalúa siempre, coincida o
  /// no el recuento declarado — `remoteExpectedPageCount` solo añade una
  /// señal INDEPENDIENTE y más fuerte para el caso de truncado en tránsito
  /// (manifiesto declara N, se descargan menos de N páginas), nunca sirve
  /// para descartar la sospecha cuando sí coincide.
  static bool looksSuspiciouslyPartial({
    required int basePageCount,
    required int remotePageCount,
    int? remoteExpectedPageCount,
  }) {
    final manifestMismatch = remoteExpectedPageCount != null &&
        remoteExpectedPageCount != remotePageCount;
    if (manifestMismatch) return true;

    if (basePageCount < _partialRemoteMinBasePages) return false;
    if (remotePageCount == 0) return false; // ya cubierto por el guard de remoto vacío
    return remotePageCount <= (basePageCount * _partialRemoteThreshold).ceil();
  }

  /// Merge a 3 vías. Si [baseline] es null, se trata como snapshot vacío.
  ///
  /// Si `remote.pages` cae muy por debajo de `baseline.pages` (ver
  /// [looksSuspiciouslyPartial]), no se adopta como fuente de verdad — ni por
  /// fast-forward ni marcando tombstones por las páginas ausentes — hasta que
  /// una capa superior confirme que es un borrado real (no un manifiesto
  /// parcial). [remoteExpectedPageCount] (recuento declarado por el propio
  /// manifiesto remoto, si se conoce) añade una señal adicional: si no
  /// coincide con `remote.pages.length`, es indicio de truncado en tránsito y
  /// se marca como sospechoso incluso si la caída no cruzase el umbral.
  VaultSyncMergeResult merge({
    required VaultPayload local,
    required VaultPayload remote,
    VaultPayload? baseline,
    int? remoteExpectedPageCount,
  }) {
    final base =
        baseline ?? VaultPayload(pages: const [], pageTombstones: const {});

    final remoteLooksPartial = looksSuspiciouslyPartial(
      basePageCount: base.pages.length,
      remotePageCount: remote.pages.length,
      remoteExpectedPageCount: remoteExpectedPageCount,
    );

    final localFp = payloadFingerprint(local);
    final remoteFp = payloadFingerprint(remote);
    if (localFp == remoteFp) {
      return VaultSyncMergeResult(
        payload: _copyPayload(local),
        blockConflicts: const [],
        attachmentPaths: collectAttachmentPaths(local),
        changed: false,
      );
    }

    // Fast-forward: si lo local no cambió desde el ancestro común, no hace
    // falta recorrer página por página — se adopta el remoto completo tal
    // cual, igual que un `git merge --ff-only`. Evita el diffing completo en
    // el caso más habitual (nadie tocó esta libreta en este dispositivo
    // desde la última sync).
    //
    // Salvo que el remoto parezca un manifiesto parcial: adoptarlo tal cual
    // colapsaría la libreta local a esas pocas páginas sin pasar por ningún
    // diff. En ese caso se cae al camino de abajo, que sí sabe no tombstonear
    // páginas ausentes solo por culpa de un remoto incompleto.
    if (localFp == payloadFingerprint(base) && !remoteLooksPartial) {
      return VaultSyncMergeResult(
        payload: _copyPayload(remote),
        blockConflicts: const [],
        attachmentPaths: collectAttachmentPaths(remote),
        changed: true,
      );
    }

    final basePages = {for (final p in base.pages) p.id: p};
    final localPages = {for (final p in local.pages) p.id: p};
    final remotePages = {for (final p in remote.pages) p.id: p};

    final tombstones = <String, int>{};
    void absorbTombs(Map<String, int> src) {
      for (final e in src.entries) {
        final prev = tombstones[e.key];
        if (prev == null || e.value > prev) {
          tombstones[e.key] = e.value;
        }
      }
    }

    absorbTombs(base.pageTombstones);
    absorbTombs(local.pageTombstones);
    absorbTombs(remote.pageTombstones);

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final id in basePages.keys) {
      final missingLocal = !localPages.containsKey(id);
      final missingRemote = !remotePages.containsKey(id);
      if (!missingLocal && missingRemote && remoteLooksPartial) {
        // El remoto parece un manifiesto parcial: una página presente en
        // local pero ausente del remoto es más probable un artefacto de
        // subida incompleta que un borrado real. No tombstonear — se
        // conserva la página local; el próximo push completo repara el
        // remoto en vez de que este pull la borre en silencio.
        continue;
      }
      if (missingLocal || missingRemote) {
        tombstones.putIfAbsent(id, () => nowMs);
      }
    }

    final allIds = <String>{...localPages.keys, ...remotePages.keys}
      ..removeWhere(tombstones.containsKey);

    final conflicts = <VaultSyncBlockConflict>[];
    final mergedPages = <FolioPage>[];
    final extraRevisions = <String, List<FolioPageRevision>>{};

    for (final id in allIds) {
      final l = localPages[id];
      final r = remotePages[id];
      final b = basePages[id];

      if (l != null && r == null) {
        mergedPages.add(clonePage(l));
        continue;
      }
      if (r != null && l == null) {
        mergedPages.add(clonePage(r));
        continue;
      }
      if (l == null || r == null) continue;

      final lFp = pageFingerprint(l);
      final rFp = pageFingerprint(r);
      if (lFp == rFp) {
        mergedPages.add(clonePage(l));
        continue;
      }

      final bFp = b == null ? '' : pageFingerprint(b);
      if (bFp.isNotEmpty && lFp == bFp) {
        mergedPages.add(clonePage(r));
        continue;
      }
      if (bFp.isNotEmpty && rFp == bFp) {
        mergedPages.add(clonePage(l));
        continue;
      }

      final pageMerge = _mergePage(local: l, remote: r, baseline: b);
      mergedPages.add(pageMerge.page);
      conflicts.addAll(pageMerge.conflicts);
      if (pageMerge.remoteRevision != null) {
        (extraRevisions[id] ??= []).add(pageMerge.remoteRevision!);
      }
    }

    final pageOrder = _mergePageOrder(
      local: local.pageOrderByParent,
      remote: remote.pageOrderByParent,
      baseline: base.pageOrderByParent,
      keptPageIds: mergedPages.map((p) => p.id).toSet(),
    );

    final pageRevisions = _mergeRevisions(
      local: local.pageRevisions,
      remote: remote.pageRevisions,
      extra: extraRevisions,
    );

    final comments = _mergeById(
      local: local.comments,
      remote: remote.comments,
      idOf: (c) => c.id,
    );

    final templates = _mergeById(
      local: local.pageTemplates,
      remote: remote.pageTemplates,
      idOf: (t) => t.id,
    );

    final profiles = _mergeById(
      local: local.localProfiles,
      remote: remote.localProfiles,
      idOf: (p) => p.id,
    );

    final aiThreads = _mergeById(
      local: local.aiChatThreads,
      remote: remote.aiChatThreads,
      idOf: (t) => t.id,
    );

    final acl = <String, Map<String, String>>{
      ...base.pageAcl,
      ...remote.pageAcl,
      ...local.pageAcl,
    };
    acl.removeWhere((k, _) => tombstones.containsKey(k));

    var syncClock = local.syncClock;
    if (remote.syncClock > syncClock) syncClock = remote.syncClock;
    if (base.syncClock > syncClock) syncClock = base.syncClock;
    syncClock += 1;

    final mcpReadable = <String>{
      ...base.mcpReadablePageIds,
      ...remote.mcpReadablePageIds,
      ...local.mcpReadablePageIds,
    };
    mcpReadable.removeWhere(tombstones.containsKey);

    final merged = VaultPayload(
      version: kVaultPayloadVersion,
      pages: mergedPages,
      displayName: _mergeDisplayName(
        local: local.displayName,
        remote: remote.displayName,
        baseline: base.displayName,
      ),
      pageOrderByParent: pageOrder,
      pageRevisions: pageRevisions,
      pageAcl: acl,
      localProfiles: profiles,
      comments: comments,
      aiChatThreads: aiThreads,
      aiActiveChatIndex: local.aiActiveChatIndex,
      pageTemplates: templates,
      jira: _pickJira(local.jira, remote.jira, base.jira),
      youtrack: _pickYoutrack(local.youtrack, remote.youtrack, base.youtrack),
      trello: TrelloIntegrationState(
        connections: _mergeById(
          local: local.trello.connections,
          remote: remote.trello.connections,
          idOf: (c) => c.id,
        ),
        sources: _mergeById(
          local: local.trello.sources,
          remote: remote.trello.sources,
          idOf: (s) => s.id,
        ),
      ),
      github: GitHubIntegrationState(
        connections: _mergeById(
          local: local.github.connections,
          remote: remote.github.connections,
          idOf: (c) => c.id,
        ),
        sources: _mergeById(
          local: local.github.sources,
          remote: remote.github.sources,
          idOf: (s) => s.id,
        ),
      ),
      gitlab: GitLabIntegrationState(
        connections: _mergeById(
          local: local.gitlab.connections,
          remote: remote.gitlab.connections,
          idOf: (c) => c.id,
        ),
        sources: _mergeById(
          local: local.gitlab.sources,
          remote: remote.gitlab.sources,
          idOf: (s) => s.id,
        ),
      ),
      slack: SlackIntegrationState(
        connections: _mergeById(
          local: local.slack.connections,
          remote: remote.slack.connections,
          idOf: (c) => c.id,
        ),
      ),
      teams: TeamsIntegrationState(
        connections: _mergeById(
          local: local.teams.connections,
          remote: remote.teams.connections,
          idOf: (c) => c.id,
        ),
      ),
      spotify: SpotifyIntegrationState(
        connections: _mergeById(
          local: local.spotify.connections,
          remote: remote.spotify.connections,
          idOf: (c) => c.id,
        ),
      ),
      ytMusic: YtMusicIntegrationState(
        connections: _mergeById(
          local: local.ytMusic.connections,
          remote: remote.ytMusic.connections,
          idOf: (c) => c.id,
        ),
      ),
      discord: DiscordIntegrationState(
        connections: _mergeById(
          local: local.discord.connections,
          remote: remote.discord.connections,
          idOf: (c) => c.id,
        ),
      ),
      systemMedia: _mergeSystemMedia(
        local: local.systemMedia,
        remote: remote.systemMedia,
      ),
      pageTombstones: tombstones,
      syncClock: syncClock,
      mcpReadablePageIds: mcpReadable,
    );

    final changed = payloadFingerprint(merged) != localFp;
    return VaultSyncMergeResult(
      payload: merged,
      blockConflicts: conflicts,
      attachmentPaths: collectAttachmentPaths(merged),
      changed: changed || conflicts.isNotEmpty,
    );
  }

  VaultPayload _copyPayload(VaultPayload src) {
    return VaultPayload.decodeUtf8(src.encodeUtf8());
  }

  /// Merge 3 vías del nombre visible de la libreta.
  static String _mergeDisplayName({
    required String local,
    required String remote,
    required String baseline,
  }) {
    final l = local.trim();
    final r = remote.trim();
    final b = baseline.trim();
    if (l == r) return l;
    if (b.isNotEmpty && l == b) return r;
    if (b.isNotEmpty && r == b) return l;
    if (l.isEmpty) return r;
    if (r.isEmpty) return l;
    // Ambos cambiaron respecto al baseline: preferir remoto (llegó por sync).
    return r;
  }

  ({
    FolioPage page,
    List<VaultSyncBlockConflict> conflicts,
    FolioPageRevision? remoteRevision,
  })
  _mergePage({
    required FolioPage local,
    required FolioPage remote,
    FolioPage? baseline,
  }) {
    final conflicts = <VaultSyncBlockConflict>[];
    final baseBlocks = {
      for (final b in baseline?.blocks ?? const <FolioBlock>[]) b.id: b,
    };
    final localBlocks = {for (final b in local.blocks) b.id: b};
    final remoteBlocks = {for (final b in remote.blocks) b.id: b};

    final allBlockIds = <String>{...localBlocks.keys, ...remoteBlocks.keys};
    final mergedById = <String, FolioBlock>{};
    var hadBlockConflict = false;

    for (final id in allBlockIds) {
      final l = localBlocks[id];
      final r = remoteBlocks[id];
      final b = baseBlocks[id];

      if (l != null && r == null) {
        mergedById[id] = cloneBlock(l);
        continue;
      }
      if (r != null && l == null) {
        mergedById[id] = cloneBlock(r);
        continue;
      }
      if (l == null || r == null) continue;

      final lFp = blockFingerprint(l);
      final rFp = blockFingerprint(r);
      if (lFp == rFp) {
        mergedById[id] = cloneBlock(l);
        continue;
      }
      final bFp = b == null ? '' : blockFingerprint(b);
      if (bFp.isNotEmpty && lFp == bFp) {
        mergedById[id] = cloneBlock(r);
        continue;
      }
      if (bFp.isNotEmpty && rFp == bFp) {
        mergedById[id] = cloneBlock(l);
        continue;
      }

      mergedById[id] = cloneBlock(l);
      conflicts.add(
        VaultSyncBlockConflict(
          pageId: local.id,
          blockId: id,
          localBlock: cloneBlock(l),
          remoteBlock: cloneBlock(r),
          baseBlock: b != null ? cloneBlock(b) : null,
        ),
      );
      hadBlockConflict = true;
    }

    final order = _mergeIdOrder(
      localOrder: local.blocks.map((b) => b.id).toList(),
      remoteOrder: remote.blocks.map((b) => b.id).toList(),
      baselineOrder: baseline?.blocks.map((b) => b.id).toList() ?? const [],
      kept: mergedById.keys.toSet(),
    );

    final title = _pickScalar(
      local: local.title,
      remote: remote.title,
      baseline: baseline?.title,
    );
    final emoji = _pickScalar(
      local: local.emoji,
      remote: remote.emoji,
      baseline: baseline?.emoji,
    );
    final parentId = _pickScalar(
      local: local.parentId,
      remote: remote.parentId,
      baseline: baseline?.parentId,
    );
    final isFolder = _pickBool(
      local: local.isFolder,
      remote: remote.isFolder,
      baseline: baseline?.isFolder,
    );
    final trashedAt = _pickTrashedAt(
      local: local.trashedAt,
      remote: remote.trashedAt,
      baseline: baseline?.trashedAt,
    );

    final page = FolioPage(
      id: local.id,
      title: title ?? local.title,
      emoji: emoji,
      parentId: parentId,
      isFolder: isFolder ?? local.isFolder,
      lastImportInfo: local.lastImportInfo ?? remote.lastImportInfo,
      collabRoomId: local.collabRoomId ?? remote.collabRoomId,
      collabJoinCode: local.collabJoinCode ?? remote.collabJoinCode,
      trashedAt: trashedAt,
      blocks: [for (final id in order) mergedById[id]!],
      properties: local.properties.isNotEmpty
          ? List.from(local.properties)
          : List.from(remote.properties),
      tags: {...local.tags, ...remote.tags}.toList(),
    );

    FolioPageRevision? remoteRevision;
    if (hadBlockConflict) {
      remoteRevision = FolioPageRevision(
        revisionId: 'sync_remote_${DateTime.now().microsecondsSinceEpoch}',
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
        title: remote.title,
        blocksJson: remote.blocks.map((b) => b.toJson()).toList(),
      );
    }

    return (page: page, conflicts: conflicts, remoteRevision: remoteRevision);
  }

  Map<String, List<String>> _mergePageOrder({
    required Map<String, List<String>> local,
    required Map<String, List<String>> remote,
    required Map<String, List<String>> baseline,
    required Set<String> keptPageIds,
  }) {
    final keys = <String>{...local.keys, ...remote.keys, ...baseline.keys};
    final out = <String, List<String>>{};
    for (final key in keys) {
      final merged = _mergeIdOrder(
        localOrder: local[key] ?? const [],
        remoteOrder: remote[key] ?? const [],
        baselineOrder: baseline[key] ?? const [],
        kept: keptPageIds,
      );
      if (merged.isNotEmpty) {
        out[key] = merged;
      }
    }
    return out;
  }

  List<String> _mergeIdOrder({
    required List<String> localOrder,
    required List<String> remoteOrder,
    required List<String> baselineOrder,
    required Set<String> kept,
  }) {
    final result = <String>[
      for (final id in localOrder)
        if (kept.contains(id)) id,
    ];
    final present = result.toSet();

    for (var i = 0; i < remoteOrder.length; i++) {
      final id = remoteOrder[i];
      if (!kept.contains(id) || present.contains(id)) continue;
      var insertAt = result.length;
      for (var j = i - 1; j >= 0; j--) {
        final pred = remoteOrder[j];
        final predIdx = result.indexOf(pred);
        if (predIdx != -1) {
          insertAt = predIdx + 1;
          break;
        }
      }
      result.insert(insertAt, id);
      present.add(id);
    }

    for (final id in kept) {
      if (!present.contains(id)) {
        result.add(id);
        present.add(id);
      }
    }
    return result;
  }

  Map<String, List<FolioPageRevision>> _mergeRevisions({
    required Map<String, List<FolioPageRevision>> local,
    required Map<String, List<FolioPageRevision>> remote,
    required Map<String, List<FolioPageRevision>> extra,
  }) {
    final keys = <String>{...local.keys, ...remote.keys, ...extra.keys};
    final out = <String, List<FolioPageRevision>>{};
    for (final key in keys) {
      final byId = <String, FolioPageRevision>{};
      for (final r in [
        ...?local[key],
        ...?remote[key],
        ...?extra[key],
      ]) {
        if (r.revisionId.isEmpty) continue;
        byId.putIfAbsent(r.revisionId, () => r);
      }
      if (byId.isEmpty) continue;
      final list = byId.values.toList()
        ..sort((a, b) => a.savedAtMs.compareTo(b.savedAtMs));
      out[key] = list;
    }
    return out;
  }

  List<T> _mergeById<T>({
    required List<T> local,
    required List<T> remote,
    required String Function(T) idOf,
  }) {
    final map = <String, T>{};
    for (final item in remote) {
      final id = idOf(item);
      if (id.isEmpty) continue;
      map[id] = item;
    }
    for (final item in local) {
      final id = idOf(item);
      if (id.isEmpty) continue;
      map[id] = item;
    }
    return map.values.toList();
  }

  T? _pickScalar<T>({
    required T? local,
    required T? remote,
    required T? baseline,
  }) {
    if (local == remote) return local;
    if (baseline != null && local == baseline) return remote;
    if (baseline != null && remote == baseline) return local;
    return local;
  }

  bool? _pickBool({
    required bool local,
    required bool remote,
    required bool? baseline,
  }) {
    if (local == remote) return local;
    if (baseline != null && local == baseline) return remote;
    if (baseline != null && remote == baseline) return local;
    return local;
  }

  DateTime? _pickTrashedAt({
    required DateTime? local,
    required DateTime? remote,
    required DateTime? baseline,
  }) {
    if (local != null && remote != null) {
      return local.isAfter(remote) ? local : remote;
    }
    if (local != null && remote == null) {
      if (baseline != null && baseline == local) return null;
      return local;
    }
    if (remote != null && local == null) {
      if (baseline != null && baseline == remote) return null;
      return remote;
    }
    return null;
  }

  JiraIntegrationState _pickJira(
    JiraIntegrationState local,
    JiraIntegrationState remote,
    JiraIntegrationState baseline,
  ) {
    final l = jsonEncode(local.toJson());
    final r = jsonEncode(remote.toJson());
    final b = jsonEncode(baseline.toJson());
    if (l == r) return local;
    if (l == b) return remote;
    if (r == b) return local;
    return local;
  }

  YouTrackIntegrationState _pickYoutrack(
    YouTrackIntegrationState local,
    YouTrackIntegrationState remote,
    YouTrackIntegrationState baseline,
  ) {
    final l = jsonEncode(local.toJson());
    final r = jsonEncode(remote.toJson());
    final b = jsonEncode(baseline.toJson());
    if (l == r) return local;
    if (l == b) return remote;
    if (r == b) return local;
    return local;
  }

  SystemMediaIntegrationState _mergeSystemMedia({
    required SystemMediaIntegrationState local,
    required SystemMediaIntegrationState remote,
  }) {
    // Preferir remoto si habilitó; si no, conservar local.
    if (local.enabled == remote.enabled &&
        local.zenPauseOnExit == remote.zenPauseOnExit) {
      return local;
    }
    if (remote.enabled != local.enabled) {
      return remote;
    }
    return SystemMediaIntegrationState(
      enabled: local.enabled || remote.enabled,
      zenPauseOnExit: remote.zenPauseOnExit,
    );
  }
}
