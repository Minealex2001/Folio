import 'package:collection/collection.dart';
import '../../models/block.dart';
import '../../models/folio_kanban_data.dart';
import '../../models/folio_page.dart';
import '../../models/folio_task_data.dart';
import '../../models/youtrack_integration_state.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import 'youtrack_api_client.dart';

class YouTrackSyncResult {
  const YouTrackSyncResult({
    required this.pulled,
    required this.created,
    required this.updated,
  });
  final int pulled;
  final int created;
  final int updated;
}

class YouTrackPushResult {
  const YouTrackPushResult({required this.pushed, required this.skipped});
  final int pushed;
  final int skipped;
}

class YouTrackSyncService {
  const YouTrackSyncService();

  Future<YouTrackSyncResult> pullIssuesIntoPage({
    required VaultSession session,
    required String pageId,
    required String youtrackSourceId,
    int maxIssues = 100,
  }) async {
    final source = session.youtrackSources.firstWhereOrNull((s) => s.id == youtrackSourceId);
    if (source == null) {
      throw StateError('Fuente YouTrack no encontrada.');
    }
    final connection = session.youtrackConnections.firstWhereOrNull(
      (c) => c.id == source.connectionId,
    );
    if (connection == null) {
      throw StateError('Conexión YouTrack no encontrada.');
    }

    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    final client = YouTrackApiClient(connection: connection);

    // Resolve search query
    var query = '';
    if (source.type == YouTrackSourceType.project) {
      final projectShortName = (source.projectShortName ?? '').trim();
      if (projectShortName.isNotEmpty) {
        query = 'project: $projectShortName';
      }
    } else {
      query = (source.query ?? '').trim();
    }

    final issues = await client.searchIssues(query: query, top: maxIssues);

    final existingByIssueId = <String, ({FolioBlock block, FolioTaskData task})>{};
    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null) continue;
      if (ext.provider != 'youtrack') continue;
      final issueId = ext.issueId.trim();
      if (issueId.isEmpty) continue;
      existingByIssueId[issueId] = (block: b, task: t);
    }

    var created = 0;
    var updated = 0;
    final toAddBlocks = <FolioBlock>[];

    for (final issue in issues) {
      if (issue.id.isEmpty) continue;

      // Map priority
      final folioPriority = _mapPriorityToFolio(issue.priorityName);

      // Map status/column
      final folioStatus = _mapStatusFromYouTrack(issue.stateName, source.columnMappings);

      final nextSnapshot = FolioYouTrackIssueSnapshot(
        projectId: issue.projectId,
        projectShortName: issue.projectShortName,
        projectName: issue.projectName,
        stateName: issue.stateName,
        priorityName: issue.priorityName,
        assigneeName: issue.assigneeName,
        subsystem: issue.subsystemName,
        commentCount: issue.commentCount,
        attachmentCount: issue.attachmentCount,
        type: issue.typeName,
        fixVersions: issue.fixVersions,
        affectedVersions: issue.affectedVersions,
        fixedInBuild: issue.fixedInBuild,
        estimation: issue.estimation,
        spentTime: issue.spentTime,
      );

      final nextExternal = FolioExternalTaskLink(
        provider: 'youtrack',
        issueId: issue.id,
        issueKey: issue.idReadable,
        deployment: 'server',
        baseUrl: connection.baseUrl,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        remoteUpdatedAtMs: issue.updatedAtMs,
        syncState: 'ok',
      );

      final pulledTask = FolioTaskData(
        title: issue.summary.trim(),
        description: issue.description,
        priority: folioPriority,
        status: folioStatus,
        columnId: folioStatus,
        assignee: issue.assigneeName,
        external: nextExternal,
        youtrack: nextSnapshot,
      );

      final match = existingByIssueId[issue.id];
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
        // Create new task block
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

    return YouTrackSyncResult(
      pulled: issues.length,
      created: created,
      updated: updated,
    );
  }

  Future<YouTrackPushResult> pushLinkedTasksFromPage({
    required VaultSession session,
    required String pageId,
  }) async {
    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    var pushed = 0;
    var skipped = 0;

    // Resolve YouTrack source for column mappings
    String? pageYouTrackSourceId;
    for (final b in page.blocks) {
      if (b.type != 'kanban') continue;
      final kd = FolioKanbanData.tryParse(b.text);
      final sid = (kd?.youtrackSourceId ?? '').trim();
      if (sid.isNotEmpty) {
        pageYouTrackSourceId = sid;
        break;
      }
    }
    final source = pageYouTrackSourceId == null
        ? null
        : session.youtrackSources.firstWhereOrNull((s) => s.id == pageYouTrackSourceId);

    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null || ext.provider != 'youtrack') continue;
      final issueId = ext.issueId.trim();
      if (issueId.isEmpty) continue;

      final localNeedsPush = (ext.syncState ?? '').trim() == 'needsPush';
      if (!localNeedsPush) {
        skipped++;
        continue;
      }

      final conn = session.youtrackConnections.firstWhereOrNull((c) => c.id == ext.baseUrl || c.id == ext.cloudId || c.baseUrl == ext.baseUrl);
      // Fallback to matching connection if possible
      final connection = conn ?? session.youtrackConnections.firstWhereOrNull(
        (c) => (c.baseUrl).trim().toLowerCase() == (ext.baseUrl ?? '').trim().toLowerCase()
      );

      if (connection == null) {
        skipped++;
        continue;
      }

      final client = YouTrackApiClient(connection: connection);

      try {
        // Check for remote changes before push
        final remote = await client.getIssue(ext.issueKey ?? ext.issueId);
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

        // Map Folio priority to YouTrack priority name
        final youTrackPriority = _mapPriorityToYouTrack(t.priority);

        // Map Folio column/status to YouTrack State name
        final effectiveColumn = (t.columnId ?? '').trim().isNotEmpty
            ? t.columnId!.trim()
            : t.status.trim();
        final mapping = source?.columnMappings.firstWhereOrNull(
          (m) => m.columnId.trim() == effectiveColumn,
        );
        final desiredState = mapping?.stateName ?? _mapStatusToYouTrack(effectiveColumn);

        final snap = t.youtrack;
        final fieldValues = <String, String?>{
          if (snap != null) ...{
            'Type': snap.type,
            'Assignee': snap.assigneeName,
            'Subsystem': snap.subsystem,
            'Fix versions': snap.fixVersions,
            'Affected versions': snap.affectedVersions,
            'Fixed in build': snap.fixedInBuild,
            'Estimation': snap.estimation,
            'Spent time': snap.spentTime,
          }
        };

        // Push updates
        await client.updateIssueFields(
          issueIdOrKey: ext.issueKey ?? ext.issueId,
          summary: t.title.trim(),
          description: t.description,
          stateFieldId: remote.customFieldIds['state'],
          stateName: desiredState,
          priorityFieldId: remote.customFieldIds['priority'],
          priorityName: youTrackPriority,
          customFieldIds: remote.customFieldIds,
          customFieldValues: fieldValues,
        );

        // Refresh issue to capture next remote update timestamp
        final updatedRemote = await client.getIssue(ext.issueKey ?? ext.issueId);

        final nextSnapshot = FolioYouTrackIssueSnapshot(
          projectId: updatedRemote.projectId,
          projectShortName: updatedRemote.projectShortName,
          stateName: updatedRemote.stateName,
          priorityName: updatedRemote.priorityName,
          assigneeName: updatedRemote.assigneeName,
          subsystem: updatedRemote.subsystemName,
          commentCount: updatedRemote.commentCount,
          attachmentCount: updatedRemote.attachmentCount,
          type: updatedRemote.typeName,
          fixVersions: updatedRemote.fixVersions,
          affectedVersions: updatedRemote.affectedVersions,
          fixedInBuild: updatedRemote.fixedInBuild,
          estimation: updatedRemote.estimation,
          spentTime: updatedRemote.spentTime,
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
            youtrack: nextSnapshot,
          ).encode(),
        );

        pushed++;
      } catch (e) {
        AppLogger.warn(
          'Error pushing task to YouTrack',
          tag: 'youtrack',
          context: {'issueId': ext.issueKey ?? ext.issueId, 'error': '$e'},
        );
        skipped++;
      }
    }

    return YouTrackPushResult(pushed: pushed, skipped: skipped);
  }

  String? _mapPriorityToFolio(String? youtrackPriority) {
    return youtrackPriority;
  }

  String? _mapPriorityToYouTrack(String? folioPriority) {
    final p = (folioPriority ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    switch (p) {
      case 'high':
        return 'Major';
      case 'medium':
        return 'Normal';
      case 'low':
      case 'lowest':
        return 'Minor';
      default:
        if (p == 'showstopper') return 'Showstopper';
        if (p == 'critical') return 'Critical';
        if (p == 'major') return 'Major';
        if (p == 'normal') return 'Normal';
        if (p == 'minor') return 'Minor';
        if (p == 'minimal') return 'Minimal';
        return folioPriority;
    }
  }

  String _mapStatusFromYouTrack(String? youtrackState, List<YouTrackColumnMapping> mappings) {
    final state = (youtrackState ?? '').trim().toLowerCase();
    if (state.isEmpty) return 'todo';

    // Check custom mappings first
    final mapped = mappings.firstWhereOrNull((m) => (m.stateName ?? '').trim().toLowerCase() == state);
    if (mapped != null) {
      return mapped.columnId;
    }

    // Fallback guesses
    if (state.contains('fixed') ||
        state.contains('done') ||
        state.contains('complete') ||
        state.contains('resolved') ||
        state.contains('closed') ||
        state.contains('verificado')) {
      return 'done';
    }
    if (state.contains('progress') ||
        state.contains('curso') ||
        state.contains('desarrollo') ||
        state.contains('haciendo')) {
      return 'in_progress';
    }
    return 'todo';
  }

  String _mapStatusToYouTrack(String folioStatus) {
    switch (folioStatus) {
      case 'done':
        return 'Fixed';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'To Do';
    }
  }

  bool _shouldUpdateLocal(FolioTaskData current, FolioTaskData next) {
    if (current.title.trim() != next.title.trim()) return true;
    if (current.description.trim() != next.description.trim()) return true;
    if (current.status.trim() != next.status.trim()) return true;
    if (current.priority != next.priority) return true;
    if (current.assignee != next.assignee) return true;

    final curYt = current.youtrack;
    final nxtYt = next.youtrack;
    if (curYt?.subsystem != nxtYt?.subsystem) return true;
    if (curYt?.assigneeName != nxtYt?.assigneeName) return true;
    if (curYt?.priorityName != nxtYt?.priorityName) return true;
    if (curYt?.stateName != nxtYt?.stateName) return true;
    if (curYt?.type != nxtYt?.type) return true;
    if (curYt?.fixVersions != nxtYt?.fixVersions) return true;
    if (curYt?.affectedVersions != nxtYt?.affectedVersions) return true;
    if (curYt?.fixedInBuild != nxtYt?.fixedInBuild) return true;
    if (curYt?.estimation != nxtYt?.estimation) return true;
    if (curYt?.spentTime != nxtYt?.spentTime) return true;

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
    final prevRemote = ext.remoteUpdatedAtMs;
    if (localNeedsPush) {
      final nextExt = ext.copyWith(
        remoteUpdatedAtMs: remoteUpdatedAtMs,
        syncState: 'conflict',
      );
      return current.copyWith(
        external: nextExt,
        youtrack: pulled.youtrack ?? current.youtrack,
      );
    }

    final nextExt = ext.copyWith(
      remoteUpdatedAtMs: remoteUpdatedAtMs,
      syncState: 'ok',
      lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return pulled.copyWith(external: nextExt);
  }
}
