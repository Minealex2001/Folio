import 'package:collection/collection.dart';
import 'dart:convert';

import '../../models/block.dart';
import '../../models/folio_kanban_data.dart';
import '../../models/folio_task_data.dart';
import '../../models/jira_integration_state.dart';
import '../../session/vault_session.dart';
import 'jira_api_client.dart';

class JiraSyncService {
  const JiraSyncService();

  String? _mapFolioPriorityFromJira(String? jiraPriorityName) {
    final n = (jiraPriorityName ?? '').trim().toLowerCase();
    if (n.isEmpty) return null;
    if (n.contains('block') || n.contains('critical') || n.contains('highest')) return 'highest';
    if (n.contains('high') || n.contains('major') || n.contains('urgent')) return 'high';
    if (n.contains('medium') || n.contains('normal')) return 'medium';
    if (n.contains('lowest') || n.contains('trivial')) return 'lowest';
    if (n.contains('low') || n.contains('minor')) return 'low';
    // Default: keep unset.
    return null;
  }

  String? _mapJiraPriorityNameFromFolio(String? folioPriority) {
    final p = (folioPriority ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    return switch (p) {
      'highest' => 'Highest',
      'high' => 'High',
      'medium' => 'Medium',
      'low' => 'Low',
      'lowest' => 'Lowest',
      _ => null,
    };
  }

  Future<JiraSyncResult> pullIssuesIntoPage({
    required VaultSession session,
    required String pageId,
    required String jiraSourceId,
    int maxIssues = 100,
  }) async {
    final source = session.jiraSources.firstWhereOrNull((s) => s.id == jiraSourceId);
    if (source == null) {
      throw StateError('Fuente Jira no encontrada.');
    }
    final connection = session.jiraConnections.firstWhereOrNull(
      (c) => c.id == source.connectionId,
    );
    if (connection == null) {
      throw StateError('Conexión Jira no encontrada.');
    }

    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    final client = JiraApiClient(connection: connection);
    final issues = await _loadIssues(client: client, source: source, max: maxIssues);

    // If this source is a Jira Board, sync Folio columns to match Jira board columns.
    Map<String, String> boardStatusIdToColumnId = const {};
    Map<String, String> boardStatusNameToColumnId = const {};
    if (source.type == JiraSourceType.board) {
      final boardId = (source.boardId ?? '').trim();
      if (boardId.isNotEmpty) {
        try {
          final cfg = await client.getBoardConfiguration(boardId);
          final kanbanBlock = page.blocks.firstWhereOrNull((b) => b.type == 'kanban');
          if (kanbanBlock != null) {
            final kd = FolioKanbanData.tryParse(kanbanBlock.text) ?? FolioKanbanData.defaults();
            final sync = _syncColumnsFromJiraBoard(
              existing: kd.columns,
              config: cfg,
            );
            boardStatusIdToColumnId = sync.statusIdToColumnId;
            boardStatusNameToColumnId = sync.statusNameToColumnId;
            final nextKd = kd.copyWith(columns: sync.columns);
            session.updateBlockText(pageId, kanbanBlock.id, nextKd.encode());
          } else {
            final sync = _syncColumnsFromJiraBoard(
              existing: const [],
              config: cfg,
            );
            boardStatusIdToColumnId = sync.statusIdToColumnId;
            boardStatusNameToColumnId = sync.statusNameToColumnId;
          }
        } catch (_) {
          // If board config is unavailable (permissions / Jira Software), just skip column sync.
        }
      }
    }

    final existingByIssueId = <String, ({FolioBlock block, FolioTaskData task})>{};
    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null) continue;
      if (ext.provider != 'jira') continue;
      final issueId = ext.issueId.trim();
      if (issueId.isEmpty) continue;
      existingByIssueId[issueId] = (block: b, task: t);
    }

    // 1) Prefetch expanded issues and split subtasks.
    final expandedParents = <JiraIssueExpanded>[];
    final subtasksByParentId = <String, List<JiraIssueExpanded>>{};
    final subtasksByParentKey = <String, List<JiraIssueExpanded>>{};
    final missingParentKeysOrIds = <String>{};

    for (final issue in issues) {
      if (issue.id.isEmpty && issue.key.isEmpty) continue;
      final expanded = await client.getIssueExpanded(
        issue.key.isNotEmpty ? issue.key : issue.id,
      );
      if (expanded.isSubtask) {
        final pid = (expanded.parentId ?? '').trim();
        final pkey = (expanded.parentKey ?? '').trim();
        if (pid.isNotEmpty) {
          (subtasksByParentId[pid] ??= <JiraIssueExpanded>[]).add(expanded);
        } else if (pkey.isNotEmpty) {
          (subtasksByParentKey[pkey] ??= <JiraIssueExpanded>[]).add(expanded);
        }
        if (pid.isNotEmpty && !existingByIssueId.containsKey(pid)) {
          // note: existingByIssueId maps by issueId (not key), so we still try key below.
          missingParentKeysOrIds.add(pid);
        } else if (pkey.isNotEmpty) {
          missingParentKeysOrIds.add(pkey);
        }
        continue;
      }
      expandedParents.add(expanded);
    }

    // 2) Ensure parents referenced by subtasks exist (fetch if missing).
    final knownParentIds = <String>{for (final p in expandedParents) p.id};
    for (final ref in missingParentKeysOrIds) {
      if (ref.trim().isEmpty) continue;
      // If ref looks like an id and we already have it, skip.
      if (knownParentIds.contains(ref)) continue;
      // If any existing task already links to this ref as id, skip.
      if (existingByIssueId.containsKey(ref)) continue;
      try {
        final parentExpanded = await client.getIssueExpanded(ref);
        if (!parentExpanded.isSubtask && parentExpanded.id.isNotEmpty) {
          knownParentIds.add(parentExpanded.id);
          expandedParents.add(parentExpanded);
        }
      } catch (_) {
        // Ignore: we'll keep subtasks orphaned (no parent in page).
      }
    }

    var created = 0;
    var updated = 0;

    for (final expanded in expandedParents) {
      if (expanded.id.isEmpty) continue;
      final parentId = expanded.id.trim();
      final parentKey = expanded.key.trim();
      final parentSubtasksExpanded =
          (subtasksByParentId[parentId] ?? <JiraIssueExpanded>[]) +
              ((parentKey.isEmpty) ? const <JiraIssueExpanded>[] : (subtasksByParentKey[parentKey] ?? <JiraIssueExpanded>[]));
      final nextTask = _taskFromIssueExpanded(
        expanded,
        connection: connection,
        source: source,
        boardStatusIdToColumnId: boardStatusIdToColumnId,
        boardStatusNameToColumnId: boardStatusNameToColumnId,
      );

      final hit = existingByIssueId[parentId];
      String parentBlockId;
      if (hit == null) {
        // Append at end of page as a new task block.
        final newBlockId = '${pageId}_${DateTime.now().microsecondsSinceEpoch}_jira';
        parentBlockId = newBlockId;
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: page.blocks.isEmpty ? '' : page.blocks.last.id,
          block: FolioBlock(
            id: newBlockId,
            type: 'task',
            text: nextTask.encode(),
            depth: 0,
          ),
        );
        existingByIssueId[parentId] = (
          block: FolioBlock(id: newBlockId, type: 'task', text: nextTask.encode(), depth: 0),
          task: nextTask
        );
        created++;
      } else {
        parentBlockId = hit.block.id;
        final merged = _mergePull(
          current: hit.task,
          pulled: nextTask,
          remoteUpdatedAtMs: nextTask.external?.remoteUpdatedAtMs,
        );
        if (_shouldUpdateLocal(hit.task, merged)) {
          session.updateBlockText(pageId, hit.block.id, merged.encode());
          updated++;
        }
      }

      // Subtasks: create/update child task blocks (parentTaskId = parentBlockId).
      for (final sub in parentSubtasksExpanded) {
        if (sub.id.trim().isEmpty) continue;
        final subId = sub.id.trim();
        final subTask = _childTaskFromIssueExpanded(
          sub,
          parentTaskId: parentBlockId,
          connection: connection,
          source: source,
          boardStatusIdToColumnId: boardStatusIdToColumnId,
          boardStatusNameToColumnId: boardStatusNameToColumnId,
        );
        final existing = existingByIssueId[subId];
        if (existing == null) {
          final newBlockId = '${pageId}_${DateTime.now().microsecondsSinceEpoch}_jira_sub';
          session.insertBlockAfter(
            pageId: pageId,
            afterBlockId: parentBlockId,
            block: FolioBlock(
              id: newBlockId,
              type: 'task',
              text: subTask.encode(),
              depth: 0,
            ),
          );
          existingByIssueId[subId] = (
            block: FolioBlock(id: newBlockId, type: 'task', text: subTask.encode(), depth: 0),
            task: subTask
          );
          created++;
        } else {
          final merged = _mergePull(
            current: existing.task,
            pulled: subTask,
            remoteUpdatedAtMs: subTask.external?.remoteUpdatedAtMs,
          );
          // Ensure it's attached to the correct parent.
          final mergedWithParent = merged.copyWith(parentTaskId: parentBlockId);
          if (_shouldUpdateLocal(existing.task, mergedWithParent) ||
              existing.task.parentTaskId != parentBlockId) {
            session.updateBlockText(pageId, existing.block.id, mergedWithParent.encode());
            updated++;
          }
        }
      }
    }

    return JiraSyncResult(pulled: issues.length, created: created, updated: updated);
  }

  Future<JiraPushResult> pushLinkedTasksFromPage({
    required VaultSession session,
    required String pageId,
  }) async {
    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    var pushed = 0;
    var skipped = 0;

    // Intento de inferir sourceId desde el Kanban del page (para mapping manual).
    String? pageJiraSourceId;
    for (final b in page.blocks) {
      if (b.type != 'kanban') continue;
      final kd = FolioKanbanData.tryParse(b.text);
      final sid = (kd?.jiraSourceId ?? '').trim();
      if (sid.isNotEmpty) {
        pageJiraSourceId = sid;
        break;
      }
    }
    final source = pageJiraSourceId == null
        ? null
        : session.jiraSources.firstWhereOrNull((s) => s.id == pageJiraSourceId);

    // For Jira Board sources, infer a columnId -> Jira target statuses (ids/names)
    // from the board configuration. Used to push column moves as workflow transitions.
    final inferredColumnIdToTargetStatuses =
        <String, ({Set<String> statusIds, Set<String> statusNames})>{};
    if (source?.type == JiraSourceType.board) {
      final boardId = (source?.boardId ?? '').trim();
      if (boardId.isNotEmpty) {
        final conn = session.jiraConnections.firstWhereOrNull(
          (c) => c.id == source!.connectionId,
        );
        if (conn != null) {
          try {
            // Read current kanban columns to map internal ids -> displayed titles.
            final kanbanBlock = page.blocks.firstWhereOrNull((b) => b.type == 'kanban');
            final kd = kanbanBlock == null ? null : FolioKanbanData.tryParse(kanbanBlock.text);
            final colIdToTitle = <String, String>{};
            for (final c in (kd?.columns ?? const <FolioKanbanColumnSpec>[])) {
              final title = c.title.trim();
              colIdToTitle[c.id.trim()] = title.isEmpty ? c.id.trim() : title;
            }

            final client = JiraApiClient(connection: conn);
            final cfg = await client.getBoardConfiguration(boardId);
            for (final entry in colIdToTitle.entries) {
              final colId = entry.key.trim();
              final colTitle = entry.value.trim().toLowerCase();
              if (colId.isEmpty || colTitle.isEmpty) continue;
              final jiraCol = cfg.columns.firstWhereOrNull(
                (c) => c.name.trim().toLowerCase() == colTitle,
              );
              if (jiraCol == null) continue;
              final ids = <String>{
                for (final s in jiraCol.statusIds) if (s.trim().isNotEmpty) s.trim(),
              };
              final names = <String>{
                for (final s in jiraCol.statusNames) if (s.trim().isNotEmpty) s.trim().toLowerCase(),
              };
              if (ids.isNotEmpty || names.isNotEmpty) {
                inferredColumnIdToTargetStatuses[colId] = (statusIds: ids, statusNames: names);
              }
            }
          } catch (_) {
            // If we can't infer, we just won't transition on column moves.
          }
        }
      }
    }

    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null || ext.provider != 'jira') continue;
      final issueId = ext.issueId.trim();
      if (issueId.isEmpty) continue;

      // Incremental push: only push tasks marked as locally changed.
      final localNeedsPush = (ext.syncState ?? '').trim() == 'needsPush';
      if (!localNeedsPush) {
        skipped++;
        continue;
      }

      final conn = _resolveConnectionForExternal(session, ext);
      if (conn == null) {
        skipped++;
        continue;
      }
      final client = JiraApiClient(connection: conn);

      // Detectar conflicto remoto antes de pisar.
      final remote =
          await client.getIssueExpanded(ext.issueKey ?? ext.issueId);
      final remoteUpdatedAtMs = _parseJiraUpdatedAtMs(remote.updatedAt);
      final previousRemoteUpdatedAtMs = ext.remoteUpdatedAtMs;
      final hadRemoteChange = previousRemoteUpdatedAtMs != null &&
          remoteUpdatedAtMs != null &&
          remoteUpdatedAtMs > previousRemoteUpdatedAtMs;
      if (hadRemoteChange && localNeedsPush) {
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

      final issueIdOrKey =
          ext.issueKey?.trim().isNotEmpty == true ? ext.issueKey!.trim() : issueId;
      final desiredPriorityName = _mapJiraPriorityNameFromFolio(t.priority);
      // Update basic fields (including priority when set).
      await client.updateIssueFields(
        issueIdOrKey: issueIdOrKey,
        summary: t.title.trim(),
        description: t.description,
        dueDateIso: t.dueDate,
        priorityName: desiredPriorityName,
      );

      // Transición: primero mapping manual por columna, luego fallback por status.
      final effectiveColumn = (t.columnId ?? '').trim().isNotEmpty
          ? t.columnId!.trim()
          : t.status.trim();
      var mapping = source?.columnMappings.firstWhereOrNull(
        (m) => m.columnId.trim() == effectiveColumn,
      );
      if (mapping == null &&
          source?.type == JiraSourceType.board &&
          (t.columnId ?? '').trim().isNotEmpty) {
        final target = inferredColumnIdToTargetStatuses[t.columnId!.trim()];
        if (target != null) {
          await _tryTransitionToAnyTargetStatus(
            client,
            issueIdOrKey: issueIdOrKey,
            targetStatusIds: target.statusIds,
            targetStatusNamesLower: target.statusNames,
          );
        }
      } else {
        await _tryTransitionForMapping(
          client,
          issueIdOrKey: issueIdOrKey,
          mapping: mapping,
          fallbackStatus: t.status,
        );
      }

      // After applying changes, refresh remoteUpdatedAtMs best-effort.
      int? finalRemoteUpdatedAtMs = remoteUpdatedAtMs;
      try {
        final refreshed = await client.getIssueExpanded(issueIdOrKey);
        finalRemoteUpdatedAtMs = _parseJiraUpdatedAtMs(refreshed.updatedAt) ?? finalRemoteUpdatedAtMs;
      } catch (_) {}

      final nextExternal = (ext).copyWith(
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        remoteUpdatedAtMs: finalRemoteUpdatedAtMs ?? previousRemoteUpdatedAtMs,
        syncState: 'ok',
      );
      final nextTask = t.copyWith(external: nextExternal);
      session.updateBlockText(pageId, b.id, nextTask.encode());
      pushed++;
    }

    return JiraPushResult(pushed: pushed, skipped: skipped);
  }

  JiraConnection? _resolveConnectionForExternal(
    VaultSession session,
    FolioExternalTaskLink ext,
  ) {
    final dep = (ext.deployment ?? '').trim().toLowerCase();
    if (dep == 'server') {
      final base = (ext.baseUrl ?? '').trim();
      return session.jiraConnections.firstWhereOrNull(
        (c) => c.deployment == JiraDeployment.server && (c.baseUrl ?? '').trim() == base,
      );
    }
    final cloudId = (ext.cloudId ?? '').trim();
    return session.jiraConnections.firstWhereOrNull(
      (c) => c.deployment == JiraDeployment.cloud && (c.cloudId ?? '').trim() == cloudId,
    );
  }

  Future<void> _tryTransitionForStatus(
    JiraApiClient client, {
    required String issueIdOrKey,
    required String status,
  }) async {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (normalized != 'todo' && normalized != 'in_progress' && normalized != 'done') return;
    try {
      final transitions = await client.listTransitions(issueIdOrKey);
      if (transitions.isEmpty) return;
      String? pick(String contains) {
        for (final t in transitions) {
          final to = (t.toStatusName ?? '').toLowerCase();
          if (to.contains(contains)) return t.id;
        }
        return null;
      }

      final transitionId = switch (normalized) {
        'done' => pick('done') ?? pick('closed') ?? pick('resolved'),
        'in_progress' => pick('progress') ?? pick('in progress') ?? pick('doing'),
        _ => pick('to do') ?? pick('todo') ?? pick('open'),
      };
      if (transitionId == null || transitionId.trim().isEmpty) return;
      await client.transitionIssue(issueIdOrKey: issueIdOrKey, transitionId: transitionId);
    } catch (_) {
      // No bloquear el push si el workflow no permite transiciones automáticas.
    }
  }

  Future<void> _tryTransitionForMapping(
    JiraApiClient client, {
    required String issueIdOrKey,
    required JiraColumnMapping? mapping,
    required String fallbackStatus,
  }) async {
    if (mapping == null) {
      return _tryTransitionForStatus(
        client,
        issueIdOrKey: issueIdOrKey,
        status: fallbackStatus,
      );
    }
    try {
      final transitionId = (mapping.transitionId ?? '').trim();
      if (transitionId.isNotEmpty) {
        await client.transitionIssue(
          issueIdOrKey: issueIdOrKey,
          transitionId: transitionId,
        );
        return;
      }
      final statusId = (mapping.statusId ?? '').trim();
      if (statusId.isNotEmpty) {
        final transitions = await client.listTransitions(issueIdOrKey);
        final picked = transitions.firstWhereOrNull(
          (t) => (t.toStatusId ?? '').trim() == statusId,
        );
        if (picked != null && picked.id.trim().isNotEmpty) {
          await client.transitionIssue(issueIdOrKey: issueIdOrKey, transitionId: picked.id);
          return;
        }
      }
      final statusName = (mapping.statusName ?? '').trim().toLowerCase();
      if (statusName.isEmpty) {
        return _tryTransitionForStatus(
          client,
          issueIdOrKey: issueIdOrKey,
          status: fallbackStatus,
        );
      }
      final transitions = await client.listTransitions(issueIdOrKey);
      final picked = transitions.firstWhereOrNull((t) {
        final to = (t.toStatusName ?? '').trim().toLowerCase();
        return to == statusName || to.contains(statusName);
      });
      if (picked == null || picked.id.trim().isEmpty) return;
      await client.transitionIssue(issueIdOrKey: issueIdOrKey, transitionId: picked.id);
    } catch (_) {
      // No bloquear si el workflow no permite la transición.
    }
  }

  Future<void> _tryTransitionToAnyTargetStatus(
    JiraApiClient client, {
    required String issueIdOrKey,
    required Set<String> targetStatusIds,
    required Set<String> targetStatusNamesLower,
  }) async {
    if (targetStatusIds.isEmpty && targetStatusNamesLower.isEmpty) return;
    try {
      final transitions = await client.listTransitions(issueIdOrKey);
      if (transitions.isEmpty) return;
      JiraTransition? picked;
      if (targetStatusIds.isNotEmpty) {
        picked = transitions.firstWhereOrNull((t) {
          final toId = (t.toStatusId ?? '').trim();
          return toId.isNotEmpty && targetStatusIds.contains(toId);
        });
      }
      picked ??= transitions.firstWhereOrNull((t) {
        final to = (t.toStatusName ?? '').trim().toLowerCase();
        return to.isNotEmpty && targetStatusNamesLower.any((n) => to == n || to.contains(n));
      });
      if (picked == null || picked.id.trim().isEmpty) return;
      await client.transitionIssue(issueIdOrKey: issueIdOrKey, transitionId: picked.id);
    } catch (_) {
      // Best-effort: do not block push on workflow constraints.
    }
  }

  Future<List<JiraIssue>> _loadIssues({
    required JiraApiClient client,
    required JiraSource source,
    required int max,
  }) async {
    final take = max.clamp(1, 500);
    switch (source.type) {
      case JiraSourceType.jql:
        final jql = (source.jql ?? '').trim();
        if (jql.isEmpty) return const [];
        return client.searchJql(jql: jql, maxResults: take);
      case JiraSourceType.project:
        final key = (source.projectKey ?? '').trim();
        if (key.isEmpty) return const [];
        return client.searchJql(
          jql: 'project=$key ORDER BY updated DESC',
          maxResults: take,
        );
      case JiraSourceType.board:
        final boardId = (source.boardId ?? '').trim();
        if (boardId.isEmpty) return const [];
        return client.listBoardIssues(boardId: boardId, maxResults: take);
    }
  }

  FolioTaskData _taskFromIssueExpanded(
    JiraIssueExpanded issue, {
    required JiraConnection connection,
    required JiraSource source,
    Map<String, String> boardStatusIdToColumnId = const {},
    Map<String, String> boardStatusNameToColumnId = const {},
  }) {
    final status = _mapStatus(issue.statusName);
    final mappedColumnId = _mapColumnIdFromJira(
      source: source,
      jiraStatusId: issue.statusId,
      jiraStatusName: issue.statusName,
      fallback: status,
      boardStatusIdToColumnId: boardStatusIdToColumnId,
      boardStatusNameToColumnId: boardStatusNameToColumnId,
    );
    final remoteUpdatedAtMs = _parseJiraUpdatedAtMs(issue.updatedAt);
    final external = FolioExternalTaskLink(
      provider: 'jira',
      issueId: issue.id,
      issueKey: issue.key.isEmpty ? null : issue.key,
      deployment: connection.deployment.name,
      baseUrl: connection.deployment == JiraDeployment.server ? connection.baseUrl : null,
      cloudId: connection.deployment == JiraDeployment.cloud ? connection.cloudId : null,
      lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
      remoteUpdatedAtMs: remoteUpdatedAtMs,
      etag: null,
      remoteVersion: null,
      syncState: 'ok',
    );

    final snapshotCustomFields = <String, Object?>{};
    for (final fieldId in source.customFieldIds) {
      final fid = fieldId.trim();
      if (fid.isEmpty) continue;
      final v = issue.rawFields[fid];
      if (v == null) continue;
      snapshotCustomFields[fid] = v is Map || v is List ? jsonDecode(jsonEncode(v)) : v as Object?;
    }

    final jira = FolioJiraIssueSnapshot(
      projectKey: issue.projectKey,
      issueType: issue.issueTypeName,
      statusId: issue.statusId,
      statusName: issue.statusName,
      assigneeAccountId: issue.assigneeAccountId,
      assigneeDisplayName: issue.assigneeDisplayName,
      reporterAccountId: issue.reporterAccountId,
      reporterDisplayName: issue.reporterDisplayName,
      labels: issue.labels,
      components: issue.components,
      customFields: snapshotCustomFields,
      originalEstimateMinutes: issue.timetracking?.originalEstimateSeconds == null
          ? null
          : (issue.timetracking!.originalEstimateSeconds! / 60).round(),
      remainingEstimateMinutes: issue.timetracking?.remainingEstimateSeconds == null
          ? null
          : (issue.timetracking!.remainingEstimateSeconds! / 60).round(),
      timeSpentMinutes: issue.timetracking?.timeSpentSeconds == null
          ? null
          : (issue.timetracking!.timeSpentSeconds! / 60).round(),
      attachmentCount: issue.attachments.length,
    );
    return FolioTaskData.defaults().copyWith(
      title: issue.summary,
      description: issue.descriptionText ?? '',
      status: status,
      columnId: mappedColumnId,
      priority: _mapFolioPriorityFromJira(issue.priorityName),
      dueDate: issue.dueDateIso,
      external: external,
      jira: jira,
    );
  }

  String _mapColumnIdFromJira({
    required JiraSource source,
    required String? jiraStatusId,
    required String? jiraStatusName,
    required String fallback,
    Map<String, String> boardStatusIdToColumnId = const {},
    Map<String, String> boardStatusNameToColumnId = const {},
  }) {
    final sid = (jiraStatusId ?? '').trim();
    final sname = (jiraStatusName ?? '').trim().toLowerCase();

    // 0) If we have a board-derived mapping, prefer it.
    final fromBoard = sid.isNotEmpty
        ? (boardStatusIdToColumnId[sid] ?? '').trim()
        : (sname.isNotEmpty ? (boardStatusNameToColumnId[sname] ?? '').trim() : '');
    if (fromBoard.isNotEmpty) return fromBoard;

    final mappings = source.columnMappings;
    if (mappings.isEmpty) return fallback;

    JiraColumnMapping? pick(bool Function(JiraColumnMapping m) pred) {
      for (final m in mappings) {
        if (pred(m)) return m;
      }
      return null;
    }

    final byId = sid.isEmpty
        ? null
        : pick((m) => (m.statusId ?? '').trim().isNotEmpty && (m.statusId ?? '').trim() == sid);
    final byName = sname.isEmpty
        ? null
        : pick((m) {
            final mn = (m.statusName ?? '').trim().toLowerCase();
            if (mn.isEmpty) return false;
            return mn == sname || sname.contains(mn) || mn.contains(sname);
          });

    final col = (byId ?? byName)?.columnId.trim();
    return (col == null || col.isEmpty) ? fallback : col;
  }

  FolioTaskData _childTaskFromIssueExpanded(
    JiraIssueExpanded issue, {
    required String parentTaskId,
    required JiraConnection connection,
    required JiraSource source,
    Map<String, String> boardStatusIdToColumnId = const {},
    Map<String, String> boardStatusNameToColumnId = const {},
  }) {
    final base = _taskFromIssueExpanded(
      issue,
      connection: connection,
      source: source,
      boardStatusIdToColumnId: boardStatusIdToColumnId,
      boardStatusNameToColumnId: boardStatusNameToColumnId,
    );
    return base.copyWith(parentTaskId: parentTaskId);
  }

  ({List<FolioKanbanColumnSpec> columns, Map<String, String> statusIdToColumnId, Map<String, String> statusNameToColumnId})
      _syncColumnsFromJiraBoard({
    required List<FolioKanbanColumnSpec> existing,
    required JiraBoardConfiguration config,
  }) {
    String slug(String input) {
      final lower = input.trim().toLowerCase();
      final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final trimmed = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
      return trimmed.isEmpty ? 'col' : trimmed;
    }

    final byId = {for (final c in existing) c.id: c};
    final byTitleLower = {
      for (final c in existing) (c.title.trim().toLowerCase()): c,
    };

    final nextCols = <FolioKanbanColumnSpec>[];
    final statusIdToCol = <String, String>{};
    final statusNameToCol = <String, String>{};

    for (final col in config.columns) {
      final title = col.name.trim();
      if (title.isEmpty) continue;
      final id = 'jira_${slug(title)}';

      final preserved = byId[id] ?? byTitleLower[title.toLowerCase()];
      nextCols.add(
        FolioKanbanColumnSpec(
          id: id,
          title: title,
          colorArgb: preserved?.colorArgb,
        ),
      );

      for (final sid in col.statusIds) {
        final t = sid.trim();
        if (t.isEmpty) continue;
        statusIdToCol[t] = id;
      }
      for (final sn in col.statusNames) {
        final t = sn.trim().toLowerCase();
        if (t.isEmpty) continue;
        statusNameToCol[t] = id;
      }
    }

    return (
      columns: nextCols.isEmpty ? FolioKanbanData.defaultColumns : nextCols,
      statusIdToColumnId: statusIdToCol,
      statusNameToColumnId: statusNameToCol,
    );
  }

  String _mapStatus(String? jiraStatusName) {
    final s = (jiraStatusName ?? '').trim().toLowerCase();
    if (s.isEmpty) return 'todo';
    // DONE
    if (s.contains('done') ||
        s.contains('closed') ||
        s.contains('resolved') ||
        s.contains('final') || // finalizado/finalized
        s.contains('hecho') ||
        s.contains('termin') || // terminado/terminated
        s.contains('complet') || // completado/completed
        s.contains('cerrad') ||
        s.contains('resuelt')) {
      return 'done';
    }
    // IN PROGRESS
    if (s.contains('in progress') ||
        s.contains('progress') ||
        s.contains('doing') ||
        s.contains('wip') ||
        s.contains('en curso') ||
        s.contains('progreso') ||
        s.contains('haciendo') ||
        s.contains('en marcha') ||
        s.contains('desarrollo') ||
        s.contains('review') ||
        s.contains('revisión')) {
      return 'in_progress';
    }
    // TODO / BACKLOG
    return 'todo';
  }

  bool _shouldUpdateLocal(FolioTaskData current, FolioTaskData next) {
    // Conservador: solo sobrescribe campos “espejo”.
    if (current.title.trim() != next.title.trim()) return true;
    if ((current.description).trim() != (next.description).trim()) return true;
    if ((current.dueDate ?? '').trim() != (next.dueDate ?? '').trim()) return true;
    if (current.status.trim() != next.status.trim()) return true;
    return false;
  }

  FolioTaskData _mergePull({
    required FolioTaskData current,
    required FolioTaskData pulled,
    required int? remoteUpdatedAtMs,
  }) {
    final ext = current.external;
    final pulledExt = pulled.external;
    if (ext == null || pulledExt == null) return pulled;

    // Si local necesita push, el Pull debe marcar conflicto para forzar resolución explícita
    // antes de hacer cualquier Push posterior (evita machacar cambios remotos o generar dudas).
    // Nunca machacamos campos locales en este caso; solo refrescamos snapshot/metadatos.
    final localNeedsPush = (ext.syncState ?? '').trim() == 'needsPush';
    final prevRemote = ext.remoteUpdatedAtMs;
    if (localNeedsPush) {
      final nextExt = ext.copyWith(
        remoteUpdatedAtMs: remoteUpdatedAtMs ?? prevRemote,
        syncState: 'conflict',
      );
      return current.copyWith(
        external: nextExt,
        jira: pulled.jira ?? current.jira,
      );
    }

    // Si no hay conflicto, aplicar pull y actualizar metadatos.
    final nextExt = ext.copyWith(
      remoteUpdatedAtMs: remoteUpdatedAtMs ?? prevRemote,
      syncState: 'ok',
      lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return pulled.copyWith(external: nextExt);
  }

  int? _parseJiraUpdatedAtMs(String? updatedAt) {
    final raw = (updatedAt ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }
}

class JiraSyncResult {
  const JiraSyncResult({
    required this.pulled,
    required this.created,
    required this.updated,
  });
  final int pulled;
  final int created;
  final int updated;
}

class JiraPushResult {
  const JiraPushResult({required this.pushed, required this.skipped});
  final int pushed;
  final int skipped;
}

