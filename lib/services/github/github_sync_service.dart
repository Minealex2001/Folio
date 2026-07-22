import 'package:collection/collection.dart';
import '../../models/block.dart';
import '../../models/folio_kanban_data.dart';
import '../../models/folio_task_data.dart';
import '../../models/github_integration_state.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import 'github_api_client.dart';

class GitHubSyncResult {
  const GitHubSyncResult({
    required this.pulled,
    required this.created,
    required this.updated,
  });
  final int pulled;
  final int created;
  final int updated;
}

class GitHubPushResult {
  const GitHubPushResult({required this.pushed, required this.skipped});
  final int pushed;
  final int skipped;
}

class GitHubSyncService {
  const GitHubSyncService();

  Future<GitHubSyncResult> pullIssuesIntoPage({
    required VaultSession session,
    required String pageId,
    required String githubSourceId,
    int maxItems = 200,
  }) async {
    final source = session.githubSources.firstWhereOrNull((s) => s.id == githubSourceId);
    if (source == null) {
      throw StateError('Fuente GitHub no encontrada.');
    }
    final connection = session.githubConnections.firstWhereOrNull(
      (c) => c.id == source.connectionId,
    );
    if (connection == null) {
      throw StateError('Conexión GitHub no encontrada.');
    }

    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    final client = GitHubApiClient(connection: connection);
    final items = await client.getIssuesAndPRs(source.owner, source.repo);
    final filtered = source.includePullRequests
        ? items
        : items.where((i) => !i.isPullRequest).toList();
    final limited = filtered.length > maxItems ? filtered.sublist(0, maxItems) : filtered;

    final existingByIssueId = <String, ({FolioBlock block, FolioTaskData task})>{};
    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null) continue;
      if (ext.provider != 'github') continue;
      final issueId = ext.issueId.trim();
      if (issueId.isEmpty) continue;
      existingByIssueId[issueId] = (block: b, task: t);
    }

    var created = 0;
    var updated = 0;
    final toAddBlocks = <FolioBlock>[];

    for (final issue in limited) {
      if (issue.id == 0) continue;
      final issueIdStr = '${issue.id}';

      final folioPriority = _mapPriorityFromGitHub(issue.labels, source.priorityLabelMappings);
      final folioStatus = _mapColumnFromGitHub(issue, source.columnMappings);
      final tags = _tagsFromGitHubLabels(issue.labels);
      final existing = existingByIssueId[issueIdStr];

      final nextSnapshot = FolioGitHubIssueSnapshot(
        owner: source.owner,
        repo: source.repo,
        number: issue.number,
        isPullRequest: issue.isPullRequest,
        state: issue.state,
        labels: issue.labels.isEmpty ? null : issue.labels.map((l) => l.name).join(', '),
        assigneeLogin: issue.assigneeLogin,
        htmlUrl: issue.htmlUrl,
      );

      final nextExternal = FolioExternalTaskLink(
        provider: 'github',
        issueId: issueIdStr,
        issueKey: '${source.owner}/${source.repo}#${issue.number}',
        // Reutilizamos cloudId (libre para proveedores no-Jira) para guardar el
        // connectionId de GitHub y así resolver la conexión correcta al hacer push.
        cloudId: connection.id,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        remoteUpdatedAtMs: issue.updatedAtMs,
        syncState: 'ok',
      );

      final pulledTask = FolioTaskData(
        title: issue.title.trim(),
        description: issue.body,
        priority: folioPriority,
        status: folioStatus,
        columnId: folioStatus,
        assignee: issue.assigneeLogin,
        tags: tags,
        subtasks: existing?.task.subtasks ?? const [],
        external: nextExternal,
        github: nextSnapshot,
      );

      final match = existing;
      if (match != null) {
        final merged = _mergePull(
          current: match.task,
          pulled: pulledTask,
          remoteUpdatedAtMs: issue.updatedAtMs,
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

    return GitHubSyncResult(
      pulled: limited.length,
      created: created,
      updated: updated,
    );
  }

  /// Empuja título, estado (abierto/cerrado) y labels de vuelta a GitHub.
  ///
  /// Sólo toca metadatos: nunca intenta "crear" una PR ni tocar su rama o
  /// diff, porque Folio no gestiona git. Eso simplemente no se expone en el
  /// mapeo de campos de más abajo.
  Future<GitHubPushResult> pushLinkedTasksFromPage({
    required VaultSession session,
    required String pageId,
  }) async {
    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    var pushed = 0;
    var skipped = 0;

    String? pageGitHubSourceId;
    for (final b in page.blocks) {
      if (b.type != 'kanban') continue;
      final kd = FolioKanbanData.tryParse(b.text);
      final sid = (kd?.githubSourceId ?? '').trim();
      if (sid.isNotEmpty) {
        pageGitHubSourceId = sid;
        break;
      }
    }
    final source = pageGitHubSourceId == null
        ? null
        : session.githubSources.firstWhereOrNull((s) => s.id == pageGitHubSourceId);

    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null || ext.provider != 'github') continue;
      final issueIdStr = ext.issueId.trim();
      if (issueIdStr.isEmpty) continue;
      final gh = t.github;
      final owner = (source?.owner ?? gh?.owner ?? '').trim();
      final repo = (source?.repo ?? gh?.repo ?? '').trim();
      final number = gh?.number;
      if (owner.isEmpty || repo.isEmpty || number == null) {
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
          : session.githubConnections.firstWhereOrNull((c) => c.id == connectionId);
      if (connection == null) {
        AppLogger.warn(
          'GitHub push skipped: connection not found',
          tag: 'github',
          context: {
            'issueId': issueIdStr,
            'cloudId': ext.cloudId,
            'sourceConnectionId': source?.connectionId,
          },
        );
        skipped++;
        continue;
      }

      final client = GitHubApiClient(connection: connection);

      try {
        GitHubIssue? remote;
        try {
          remote = await client.getIssue(owner, repo, number);
        } on GitHubApiException {
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
            : _mapPriorityToGitHub(t.priority, source.priorityLabelMappings);

        final nextLabels = remote.labels
            .map((l) => l.name)
            .where((n) => !columnLabelNames.contains(n) && !priorityLabelNames.contains(n))
            .toSet();
        if (desiredColumnLabel.isNotEmpty) nextLabels.add(desiredColumnLabel);
        if (desiredPriorityLabel != null) nextLabels.add(desiredPriorityLabel);

        await client.updateIssue(
          owner: owner,
          repo: repo,
          number: number,
          title: t.title.trim(),
          state: desiredState,
          labels: nextLabels.toList(),
        );

        GitHubIssue updatedRemote;
        try {
          updatedRemote = await client.getIssue(owner, repo, number);
        } on GitHubApiException {
          updatedRemote = remote;
        }

        final nextSnapshot = FolioGitHubIssueSnapshot(
          owner: owner,
          repo: repo,
          number: updatedRemote.number,
          isPullRequest: updatedRemote.isPullRequest,
          state: updatedRemote.state,
          labels: updatedRemote.labels.isEmpty
              ? null
              : updatedRemote.labels.map((l) => l.name).join(', '),
          assigneeLogin: updatedRemote.assigneeLogin,
          htmlUrl: updatedRemote.htmlUrl,
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
            github: nextSnapshot,
          ).encode(),
        );

        pushed++;
      } catch (e) {
        AppLogger.warn(
          'Error pushing task to GitHub',
          tag: 'github',
          context: {'issueId': issueIdStr, 'error': '$e'},
        );
        skipped++;
      }
    }

    return GitHubPushResult(pushed: pushed, skipped: skipped);
  }

  String? _mapPriorityFromGitHub(
    List<GitHubLabel> labels,
    List<GitHubPriorityLabelMapping> mappings,
  ) {
    if (labels.isEmpty || mappings.isEmpty) return null;
    for (final label in labels) {
      final mapping = mappings.firstWhereOrNull((m) => m.labelName == label.name);
      if (mapping != null) return mapping.priority;
    }
    return null;
  }

  String? _mapPriorityToGitHub(
    String? folioPriority,
    List<GitHubPriorityLabelMapping> mappings,
  ) {
    final p = (folioPriority ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    return mappings.firstWhereOrNull((m) => m.priority.toLowerCase() == p)?.labelName;
  }

  /// Prioriza el mapeo por label (más específico); si no hay match, cae al
  /// estado abierto/cerrado del issue/PR.
  String _mapColumnFromGitHub(GitHubIssue issue, List<GitHubColumnMapping> mappings) {
    final labelNames = issue.labels.map((l) => l.name).toSet();
    final byLabel = mappings.firstWhereOrNull(
      (m) => (m.labelName ?? '').isNotEmpty && labelNames.contains(m.labelName),
    );
    if (byLabel != null) return byLabel.columnId;
    final byState = mappings.firstWhereOrNull((m) => m.stateValue == issue.state);
    if (byState != null) return byState.columnId;
    return 'todo';
  }

  List<String> _tagsFromGitHubLabels(List<GitHubLabel> labels) {
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

    final curGh = current.github;
    final nxtGh = next.github;
    if (curGh?.state != nxtGh?.state) return true;
    if (curGh?.labels != nxtGh?.labels) return true;
    if (curGh?.assigneeLogin != nxtGh?.assigneeLogin) return true;

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
          github: pulled.github ?? current.github,
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
