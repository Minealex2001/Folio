import 'package:collection/collection.dart';
import '../../models/block.dart';
import '../../models/folio_kanban_data.dart';
import '../../models/folio_task_data.dart';
import '../../models/gitlab_integration_state.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import 'gitlab_api_client.dart';

class GitLabSyncResult {
  const GitLabSyncResult({
    required this.pulled,
    required this.created,
    required this.updated,
  });
  final int pulled;
  final int created;
  final int updated;
}

class GitLabPushResult {
  const GitLabPushResult({required this.pushed, required this.skipped});
  final int pushed;
  final int skipped;
}

class GitLabSyncService {
  const GitLabSyncService();

  Future<GitLabSyncResult> pullIssuesIntoPage({
    required VaultSession session,
    required String pageId,
    required String gitlabSourceId,
    int maxItems = 200,
  }) async {
    final source = session.gitlabSources.firstWhereOrNull((s) => s.id == gitlabSourceId);
    if (source == null) {
      throw StateError('Fuente GitLab no encontrada.');
    }
    final connection = session.gitlabConnections.firstWhereOrNull(
      (c) => c.id == source.connectionId,
    );
    if (connection == null) {
      throw StateError('Conexión GitLab no encontrada.');
    }

    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    final client = GitLabApiClient(connection: connection);
    final issues = await client.getIssues(source.projectPath);
    final items = source.includeMergeRequests
        ? [...issues, ...await client.getMergeRequests(source.projectPath)]
        : issues;
    final limited = items.length > maxItems ? items.sublist(0, maxItems) : items;

    final existingByItemId = <String, ({FolioBlock block, FolioTaskData task})>{};
    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null) continue;
      if (ext.provider != 'gitlab') continue;
      final itemId = ext.issueId.trim();
      if (itemId.isEmpty) continue;
      existingByItemId[itemId] = (block: b, task: t);
    }

    var created = 0;
    var updated = 0;
    final toAddBlocks = <FolioBlock>[];

    for (final item in limited) {
      if (item.id == 0) continue;
      final itemIdStr = '${item.id}';

      final folioPriority = _mapPriorityFromGitLab(item.labels, source.priorityLabelMappings);
      final folioStatus = _mapColumnFromGitLab(item, source.columnMappings);
      final tags = _tagsFromGitLabLabels(item.labels);
      final existing = existingByItemId[itemIdStr];

      final nextSnapshot = FolioGitLabIssueSnapshot(
        projectPath: source.projectPath,
        iid: item.iid,
        isMergeRequest: item.isMergeRequest,
        state: item.state,
        labels: item.labels.isEmpty ? null : item.labels.map((l) => l.name).join(', '),
        assigneeUsername: item.assigneeUsername,
        webUrl: item.webUrl,
      );

      final nextExternal = FolioExternalTaskLink(
        provider: 'gitlab',
        issueId: itemIdStr,
        issueKey: '${source.projectPath}#${item.iid}',
        // Reutilizamos cloudId (libre para proveedores no-Jira) para guardar el
        // connectionId de GitLab y así resolver la conexión correcta al hacer push.
        cloudId: connection.id,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        remoteUpdatedAtMs: item.updatedAtMs,
        syncState: 'ok',
      );

      final pulledTask = FolioTaskData(
        title: item.title.trim(),
        description: item.description,
        priority: folioPriority,
        status: folioStatus,
        columnId: folioStatus,
        assignee: item.assigneeUsername,
        tags: tags,
        subtasks: existing?.task.subtasks ?? const [],
        external: nextExternal,
        gitlab: nextSnapshot,
      );

      final match = existing;
      if (match != null) {
        final merged = _mergePull(
          current: match.task,
          pulled: pulledTask,
          remoteUpdatedAtMs: item.updatedAtMs,
        );
        if (_shouldUpdateLocal(match.task, merged)) {
          session.updateBlockText(pageId, match.block.id, merged.encode());
          updated++;
        }
      } else {
        final blockId = 'task_${DateTime.now().microsecondsSinceEpoch}_$created';
        final newBlock = FolioBlock(
          id: blockId,
          type: 'task',
          text: pulledTask.encode(),
        );
        toAddBlocks.add(newBlock);
        created++;
      }
    }

    if (toAddBlocks.isNotEmpty) {
      final afterBlockId = page.blocks.isNotEmpty ? page.blocks.last.id : '';
      if (afterBlockId.isNotEmpty) {
        session.insertBlocksAfterMany(
          pageId: pageId,
          afterBlockId: afterBlockId,
          blocks: toAddBlocks,
        );
      }
    }

    return GitLabSyncResult(
      pulled: limited.length,
      created: created,
      updated: updated,
    );
  }

  /// Empuja título, estado (abierto/cerrado) y labels de vuelta a GitLab.
  Future<GitLabPushResult> pushLinkedTasksFromPage({
    required VaultSession session,
    required String pageId,
  }) async {
    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    var pushed = 0;
    var skipped = 0;

    String? pageGitLabSourceId;
    for (final b in page.blocks) {
      if (b.type != 'kanban') continue;
      final kd = FolioKanbanData.tryParse(b.text);
      final sid = (kd?.gitlabSourceId ?? '').trim();
      if (sid.isNotEmpty) {
        pageGitLabSourceId = sid;
        break;
      }
    }
    final source = pageGitLabSourceId == null
        ? null
        : session.gitlabSources.firstWhereOrNull((s) => s.id == pageGitLabSourceId);

    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null || ext.provider != 'gitlab') continue;
      final itemIdStr = ext.issueId.trim();
      if (itemIdStr.isEmpty) continue;
      final gl = t.gitlab;
      final projectPath = (source?.projectPath ?? gl?.projectPath ?? '').trim();
      final iid = gl?.iid;
      final isMr = gl?.isMergeRequest ?? false;
      if (projectPath.isEmpty || iid == null) {
        skipped++;
        continue;
      }

      final localNeedsPush = (ext.syncState ?? '').trim() == 'needsPush';
      if (!localNeedsPush) {
        skipped++;
        continue;
      }

      final connectionId = (ext.cloudId ?? '').trim().isNotEmpty
          ? ext.cloudId!.trim()
          : (source?.connectionId ?? '').trim();
      final connection = connectionId.isEmpty
          ? null
          : session.gitlabConnections.firstWhereOrNull((c) => c.id == connectionId);
      if (connection == null) {
        AppLogger.warn(
          'GitLab push skipped: connection not found',
          tag: 'gitlab',
          context: {
            'itemId': itemIdStr,
            'cloudId': ext.cloudId,
            'sourceConnectionId': source?.connectionId,
          },
        );
        skipped++;
        continue;
      }

      final client = GitLabApiClient(connection: connection);

      try {
        GitLabIssueOrMr? remote;
        try {
          remote = isMr
              ? await client.getMergeRequest(projectPath, iid)
              : await client.getIssue(projectPath, iid);
        } on GitLabApiException {
          remote = null;
        }
        if (remote == null) {
          skipped++;
          continue;
        }
        final remoteUpdatedAtMs = remote.updatedAtMs;
        final previousRemoteUpdatedAtMs = ext.remoteUpdatedAtMs;
        final hadRemoteChange = previousRemoteUpdatedAtMs != null &&
            remoteUpdatedAtMs > previousRemoteUpdatedAtMs;

        if (hadRemoteChange) {
          final nextExternal = ext.copyWith(
            remoteUpdatedAtMs: remoteUpdatedAtMs,
            syncState: 'conflict',
          );
          session.updateBlockText(
            pageId,
            b.id,
            t.copyWith(external: nextExternal).encode(),
          );
          skipped++;
          continue;
        }

        final effectiveColumn = (t.columnId ?? '').trim().isNotEmpty
            ? t.columnId!.trim()
            : t.status.trim();
        final mapping = source?.columnMappings.firstWhereOrNull(
          (m) => m.columnId.trim() == effectiveColumn,
        );
        final desiredState = mapping?.stateValue;
        final stateEvent = _mapDesiredStateToStateEvent(desiredState, remote.state);

        final columnLabelNames = source?.columnMappings
                .map((m) => (m.labelName ?? '').trim())
                .where((n) => n.isNotEmpty)
                .toSet() ??
            const <String>{};
        final priorityLabelNames = source?.priorityLabelMappings
                .map((m) => m.labelName.trim())
                .toSet() ??
            const <String>{};
        final desiredColumnLabel = (mapping?.labelName ?? '').trim();
        final desiredPriorityLabel = source == null
            ? null
            : _mapPriorityToGitLab(t.priority, source.priorityLabelMappings);

        final nextLabels = remote.labels
            .map((l) => l.name)
            .where((n) => !columnLabelNames.contains(n) && !priorityLabelNames.contains(n))
            .toSet();
        if (desiredColumnLabel.isNotEmpty) nextLabels.add(desiredColumnLabel);
        if (desiredPriorityLabel != null) nextLabels.add(desiredPriorityLabel);

        await client.updateIssueOrMr(
          projectPath,
          iid,
          isMergeRequest: isMr,
          title: t.title.trim(),
          stateEvent: stateEvent,
          labels: nextLabels.toList(),
        );

        GitLabIssueOrMr updatedRemote;
        try {
          updatedRemote = isMr
              ? await client.getMergeRequest(projectPath, iid)
              : await client.getIssue(projectPath, iid);
        } on GitLabApiException {
          updatedRemote = remote;
        }

        final nextSnapshot = FolioGitLabIssueSnapshot(
          projectPath: projectPath,
          iid: updatedRemote.iid,
          isMergeRequest: updatedRemote.isMergeRequest,
          state: updatedRemote.state,
          labels: updatedRemote.labels.isEmpty
              ? null
              : updatedRemote.labels.map((l) => l.name).join(', '),
          assigneeUsername: updatedRemote.assigneeUsername,
          webUrl: updatedRemote.webUrl,
        );

        final nextExternal = ext.copyWith(
          lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
          remoteUpdatedAtMs: updatedRemote.updatedAtMs,
          syncState: 'ok',
        );

        session.updateBlockText(
          pageId,
          b.id,
          t.copyWith(
            external: nextExternal,
            gitlab: nextSnapshot,
          ).encode(),
        );

        pushed++;
      } catch (e) {
        AppLogger.warn(
          'Error pushing task to GitLab',
          tag: 'gitlab',
          context: {'itemId': itemIdStr, 'error': '$e'},
        );
        skipped++;
      }
    }

    return GitLabPushResult(pushed: pushed, skipped: skipped);
  }

  String? _mapPriorityFromGitLab(
    List<GitLabLabel> labels,
    List<GitLabPriorityLabelMapping> mappings,
  ) {
    if (labels.isEmpty || mappings.isEmpty) return null;
    for (final label in labels) {
      final mapping = mappings.firstWhereOrNull((m) => m.labelName == label.name);
      if (mapping != null) return mapping.priority;
    }
    return null;
  }

  String? _mapPriorityToGitLab(
    String? folioPriority,
    List<GitLabPriorityLabelMapping> mappings,
  ) {
    final p = (folioPriority ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    return mappings.firstWhereOrNull((m) => m.priority.toLowerCase() == p)?.labelName;
  }

  /// Prioriza el mapeo por label (más específico); si no hay match, cae al
  /// estado abierto/cerrado (vocabulario GitLab: `opened`/`closed`).
  String _mapColumnFromGitLab(GitLabIssueOrMr item, List<GitLabColumnMapping> mappings) {
    final labelNames = item.labels.map((l) => l.name).toSet();
    final byLabel = mappings.firstWhereOrNull(
      (m) => (m.labelName ?? '').isNotEmpty && labelNames.contains(m.labelName),
    );
    if (byLabel != null) return byLabel.columnId;
    final byState = mappings.firstWhereOrNull((m) => m.stateValue == item.state);
    if (byState != null) return byState.columnId;
    return 'todo';
  }

  /// Traduce el estado deseado (columna destino) al campo de escritura
  /// `state_event` (`close`/`reopen`), comparando contra el estado actual.
  /// Devuelve `null` si no aplica ningún cambio.
  String? _mapDesiredStateToStateEvent(String? desiredState, String currentState) {
    final desired = (desiredState ?? '').trim();
    if (desired.isEmpty) return null;
    if (desired == 'closed' && currentState != 'closed') return 'close';
    if (desired == 'opened' && currentState == 'closed') return 'reopen';
    return null;
  }

  List<String> _tagsFromGitLabLabels(List<GitLabLabel> labels) {
    final tags = <String>[];
    final seen = <String>{};
    for (final label in labels) {
      final name = label.name.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      tags.add(name);
    }
    return tags;
  }

  bool _tagsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _shouldUpdateLocal(FolioTaskData current, FolioTaskData next) {
    if (current.title.trim() != next.title.trim()) return true;
    if (current.description.trim() != next.description.trim()) return true;
    if (current.status.trim() != next.status.trim()) return true;
    if (current.priority != next.priority) return true;
    if (current.assignee != next.assignee) return true;
    if (!_tagsEqual(current.tags, next.tags)) return true;

    final curGl = current.gitlab;
    final nxtGl = next.gitlab;
    if (curGl?.state != nxtGl?.state) return true;
    if (curGl?.labels != nxtGl?.labels) return true;
    if (curGl?.assigneeUsername != nxtGl?.assigneeUsername) return true;

    return false;
  }

  FolioTaskData _mergePull({
    required FolioTaskData current,
    required FolioTaskData pulled,
    required int remoteUpdatedAtMs,
  }) {
    final ext = current.external;
    final pulledExt = pulled.external;
    if (ext == null || pulledExt == null) return pulled;

    final localNeedsPush = (ext.syncState ?? '').trim() == 'needsPush';
    if (localNeedsPush) {
      final prevRemote = ext.remoteUpdatedAtMs;
      final remoteChanged =
          prevRemote != null && remoteUpdatedAtMs > prevRemote;
      if (remoteChanged) {
        // Conflicto real: remoto cambió mientras Folio tenía cambios pendientes.
        final nextExt = ext.copyWith(
          remoteUpdatedAtMs: remoteUpdatedAtMs,
          syncState: 'conflict',
        );
        return current.copyWith(
          external: nextExt,
          gitlab: pulled.gitlab ?? current.gitlab,
        );
      }
      // Sin cambios remotos: conservar needsPush para que el push del mismo
      // ciclo de sync pueda aplicar los cambios locales.
      return current;
    }

    final nextExt = ext.copyWith(
      remoteUpdatedAtMs: remoteUpdatedAtMs,
      syncState: 'ok',
      lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return pulled.copyWith(external: nextExt);
  }
}
