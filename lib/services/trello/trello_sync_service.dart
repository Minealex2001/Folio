import 'package:collection/collection.dart';
import '../../models/block.dart';
import '../../models/folio_kanban_data.dart';
import '../../models/folio_task_data.dart';
import '../../models/trello_integration_state.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import 'trello_api_client.dart';

class TrelloSyncResult {
  const TrelloSyncResult({
    required this.pulled,
    required this.created,
    required this.updated,
  });
  final int pulled;
  final int created;
  final int updated;
}

class TrelloPushResult {
  const TrelloPushResult({required this.pushed, required this.skipped});
  final int pushed;
  final int skipped;
}

class TrelloSyncService {
  const TrelloSyncService();

  Future<TrelloSyncResult> pullCardsIntoPage({
    required VaultSession session,
    required String pageId,
    required String trelloSourceId,
    int maxCards = 200,
  }) async {
    final source = session.trelloSources.firstWhereOrNull((s) => s.id == trelloSourceId);
    if (source == null) {
      throw StateError('Fuente Trello no encontrada.');
    }
    final connection = session.trelloConnections.firstWhereOrNull(
      (c) => c.id == source.connectionId,
    );
    if (connection == null) {
      throw StateError('Conexión Trello no encontrada.');
    }

    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    final client = TrelloApiClient(connection: connection);
    final cards = await client.getCards(source.boardId);
    final limited = cards.length > maxCards ? cards.sublist(0, maxCards) : cards;

    final includeChecklists = source.importOptions.includeChecklists;
    final checklistsByCardId = <String, List<TrelloChecklist>>{};
    if (includeChecklists) {
      final boardChecklists = await client.getBoardChecklists(source.boardId);
      for (final cl in boardChecklists) {
        final cardId = cl.idCard.trim();
        if (cardId.isEmpty) continue;
        (checklistsByCardId[cardId] ??= <TrelloChecklist>[]).add(cl);
      }
    }

    final existingByCardId = <String, ({FolioBlock block, FolioTaskData task})>{};
    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null) continue;
      if (ext.provider != 'trello') continue;
      final cardId = ext.issueId.trim();
      if (cardId.isEmpty) continue;
      existingByCardId[cardId] = (block: b, task: t);
    }

    var created = 0;
    var updated = 0;
    final toAddBlocks = <FolioBlock>[];

    for (final card in limited) {
      if (card.id.isEmpty) continue;

      final folioPriority = _mapPriorityFromTrello(card.labels, source.priorityLabelMappings);
      final folioStatus = _mapColumnFromTrello(card.idList, source.columnMappings);
      final mapping = source.columnMappings.firstWhereOrNull((m) => m.listId == card.idList);
      final tags = _tagsFromTrelloLabels(card.labels);
      final existing = existingByCardId[card.id];
      final List<FolioTaskSubtask> subtasks;
      if (includeChecklists) {
        subtasks = _subtasksFromChecklists(checklistsByCardId[card.id] ?? const []);
      } else {
        // No importar checklists: conservar subtareas locales si ya existían.
        subtasks = existing?.task.subtasks ?? const <FolioTaskSubtask>[];
      }

      final nextSnapshot = FolioTrelloCardSnapshot(
        boardId: card.idBoard,
        boardName: source.boardName,
        listId: card.idList,
        listName: mapping?.listName,
        labels: card.labels.isEmpty
            ? null
            : card.labels.map((l) => l.name.isNotEmpty ? l.name : (l.color ?? '')).join(', '),
        memberNames: card.memberNames,
        checklistItemCount: card.checklistItemCount,
        checklistCheckedCount: card.checklistCheckedCount,
        commentCount: card.commentCount,
        attachmentCount: card.attachmentCount,
        due: card.due,
        shortUrl: card.browseUrl,
      );

      final nextExternal = FolioExternalTaskLink(
        provider: 'trello',
        issueId: card.id,
        issueKey: card.id,
        // Reutilizamos cloudId (libre para proveedores no-Jira) para guardar el
        // connectionId de Trello y así resolver la conexión correcta al hacer push.
        cloudId: connection.id,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
        remoteUpdatedAtMs: card.updatedAtMs,
        syncState: 'ok',
      );

      final pulledTask = FolioTaskData(
        title: card.name.trim(),
        description: card.desc,
        priority: folioPriority,
        status: folioStatus,
        columnId: folioStatus,
        dueDate: _normalizeDueDate(card.due),
        assignee: card.memberNames,
        tags: tags,
        subtasks: subtasks,
        external: nextExternal,
        trello: nextSnapshot,
      );

      final match = existing;
      if (match != null) {
        final merged = _mergePull(
          current: match.task,
          pulled: pulledTask,
          remoteUpdatedAtMs: card.updatedAtMs,
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

    return TrelloSyncResult(
      pulled: limited.length,
      created: created,
      updated: updated,
    );
  }

  Future<TrelloPushResult> pushLinkedTasksFromPage({
    required VaultSession session,
    required String pageId,
  }) async {
    final page = session.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) throw StateError('Página no encontrada.');

    var pushed = 0;
    var skipped = 0;

    String? pageTrelloSourceId;
    for (final b in page.blocks) {
      if (b.type != 'kanban') continue;
      final kd = FolioKanbanData.tryParse(b.text);
      final sid = (kd?.trelloSourceId ?? '').trim();
      if (sid.isNotEmpty) {
        pageTrelloSourceId = sid;
        break;
      }
    }
    final source = pageTrelloSourceId == null
        ? null
        : session.trelloSources.firstWhereOrNull((s) => s.id == pageTrelloSourceId);

    for (final b in page.blocks) {
      if (b.type != 'task') continue;
      final t = FolioTaskData.tryParse(b.text);
      if (t == null) continue;
      final ext = t.external;
      if (ext == null || ext.provider != 'trello') continue;
      final cardId = ext.issueId.trim();
      if (cardId.isEmpty) continue;

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
          : session.trelloConnections.firstWhereOrNull((c) => c.id == connectionId);
      if (connection == null) {
        AppLogger.warn(
          'Trello push skipped: connection not found',
          tag: 'trello',
          context: {
            'cardId': cardId,
            'cloudId': ext.cloudId,
            'sourceConnectionId': source?.connectionId,
          },
        );
        skipped++;
        continue;
      }

      final client = TrelloApiClient(connection: connection);

      try {
        final remote = await client.getCard(cardId);
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
        final desiredListId = mapping?.listId;

        await client.updateCard(
          cardId: cardId,
          name: t.title.trim(),
          desc: t.description,
          idList: desiredListId,
          due: (t.dueDate ?? '').trim().isEmpty ? null : t.dueDate!.trim(),
        );

        if (source != null && source.priorityLabelMappings.isNotEmpty) {
          final desiredLabelId = _mapPriorityToTrello(t.priority, source.priorityLabelMappings);
          final priorityLabelIds = source.priorityLabelMappings.map((m) => m.labelId).toSet();
          final nextLabelIds = remote.labels
              .map((l) => l.id)
              .where((id) => !priorityLabelIds.contains(id))
              .toList();
          if (desiredLabelId != null) nextLabelIds.add(desiredLabelId);
          await client.updateCardLabels(cardId: cardId, idLabels: nextLabelIds);
        }

        // Push checklist item completion (Folio subtasks → Trello check items).
        if (t.subtasks.isNotEmpty) {
          await _pushSubtasksAsCheckItems(
            client: client,
            cardId: cardId,
            subtasks: t.subtasks,
          );
        }

        final updatedRemote = await client.getCard(cardId);

        final nextSnapshot = FolioTrelloCardSnapshot(
          boardId: updatedRemote.idBoard,
          boardName: source?.boardName,
          listId: updatedRemote.idList,
          listName: source?.columnMappings
              .firstWhereOrNull((m) => m.listId == updatedRemote.idList)
              ?.listName,
          labels: updatedRemote.labels.isEmpty
              ? null
              : updatedRemote.labels
                  .map((l) => l.name.isNotEmpty ? l.name : (l.color ?? ''))
                  .join(', '),
          memberNames: updatedRemote.memberNames,
          checklistItemCount: updatedRemote.checklistItemCount,
          checklistCheckedCount: updatedRemote.checklistCheckedCount,
          commentCount: updatedRemote.commentCount,
          attachmentCount: updatedRemote.attachmentCount,
          due: updatedRemote.due,
          shortUrl: updatedRemote.browseUrl,
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
            trello: nextSnapshot,
          ).encode(),
        );

        pushed++;
      } catch (e) {
        AppLogger.warn(
          'Error pushing task to Trello',
          tag: 'trello',
          context: {'cardId': cardId, 'error': '$e'},
        );
        skipped++;
      }
    }

    return TrelloPushResult(pushed: pushed, skipped: skipped);
  }

  String? _mapPriorityFromTrello(
    List<TrelloLabel> labels,
    List<TrelloPriorityLabelMapping> mappings,
  ) {
    if (labels.isEmpty || mappings.isEmpty) return null;
    for (final label in labels) {
      final mapping = mappings.firstWhereOrNull((m) => m.labelId == label.id);
      if (mapping != null) return mapping.priority;
    }
    return null;
  }

  String? _mapPriorityToTrello(
    String? folioPriority,
    List<TrelloPriorityLabelMapping> mappings,
  ) {
    final p = (folioPriority ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    return mappings.firstWhereOrNull((m) => m.priority.toLowerCase() == p)?.labelId;
  }

  Future<void> _pushSubtasksAsCheckItems({
    required TrelloApiClient client,
    required String cardId,
    required List<FolioTaskSubtask> subtasks,
  }) async {
    final checklists = await client.getCardChecklists(cardId);
    final remoteById = <String, TrelloCheckItem>{};
    final checklistByItemId = <String, String>{};
    for (final cl in checklists) {
      for (final item in cl.checkItems) {
        final id = item.id.trim();
        if (id.isEmpty) continue;
        remoteById[id] = item;
        checklistByItemId[id] = cl.id;
      }
    }

    String? defaultChecklistId =
        checklists.isNotEmpty ? checklists.first.id.trim() : null;
    if ((defaultChecklistId == null || defaultChecklistId.isEmpty) &&
        subtasks.isNotEmpty) {
      final created = await client.createChecklist(
        cardId: cardId,
        name: 'Folio',
      );
      defaultChecklistId = created.id.trim();
    }

    final seenRemoteIds = <String>{};
    for (final sub in subtasks) {
      final id = sub.id.trim();
      final title = sub.title.trim();
      if (title.isEmpty && id.isEmpty) continue;
      final wantComplete = sub.status.trim() == 'done';
      final remote = id.isEmpty ? null : remoteById[id];
      if (remote != null) {
        seenRemoteIds.add(id);
        final nameChanged = title.isNotEmpty && title != remote.name.trim();
        final stateChanged = wantComplete != remote.isComplete;
        if (nameChanged || stateChanged) {
          await client.updateCheckItem(
            cardId: cardId,
            checkItemId: id,
            name: nameChanged ? title : null,
            complete: stateChanged ? wantComplete : null,
          );
        }
        continue;
      }
      if (defaultChecklistId == null || defaultChecklistId.isEmpty) continue;
      final created = await client.createCheckItem(
        checklistId: defaultChecklistId,
        name: title.isEmpty ? 'Untitled' : title,
        checked: wantComplete,
      );
      final newId = created.id.trim();
      if (newId.isNotEmpty) seenRemoteIds.add(newId);
    }

    // Remotos huérfanos (estaban en Trello y ya no en Folio): borrar.
    for (final entry in remoteById.entries) {
      final remoteId = entry.key;
      if (seenRemoteIds.contains(remoteId)) continue;
      final checklistId = checklistByItemId[remoteId];
      if (checklistId == null || checklistId.isEmpty) continue;
      await client.deleteCheckItem(
        checklistId: checklistId,
        checkItemId: remoteId,
      );
    }
  }

  String _mapColumnFromTrello(String listId, List<TrelloColumnMapping> mappings) {
    final mapped = mappings.firstWhereOrNull((m) => m.listId == listId);
    if (mapped != null) return mapped.columnId;
    return 'todo';
  }

  String? _normalizeDueDate(String? due) {
    final raw = (due ?? '').trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toUtc().toIso8601String();
  }

  List<String> _tagsFromTrelloLabels(List<TrelloLabel> labels) {
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

  List<FolioTaskSubtask> _subtasksFromChecklists(List<TrelloChecklist> checklists) {
    if (checklists.isEmpty) return const [];
    final sorted = List<TrelloChecklist>.from(checklists)
      ..sort((a, b) => a.pos.compareTo(b.pos));
    final prefixChecklistName = sorted.length > 1;
    final subtasks = <FolioTaskSubtask>[];
    for (final checklist in sorted) {
      final checklistName = checklist.name.trim();
      for (final item in checklist.checkItems) {
        final itemId = item.id.trim();
        final itemTitle = item.name.trim();
        if (itemId.isEmpty && itemTitle.isEmpty) continue;
        final title = prefixChecklistName && checklistName.isNotEmpty
            ? '$checklistName: $itemTitle'
            : itemTitle;
        subtasks.add(
          FolioTaskSubtask(
            id: itemId.isEmpty ? title.hashCode.toString() : itemId,
            title: title,
            status: item.isComplete ? 'done' : 'todo',
          ),
        );
      }
    }
    return subtasks;
  }

  bool _subtasksEqual(List<FolioTaskSubtask> a, List<FolioTaskSubtask> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].title.trim() != b[i].title.trim()) return false;
      if (a[i].status.trim() != b[i].status.trim()) return false;
    }
    return true;
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
    if ((current.dueDate ?? '').trim() != (next.dueDate ?? '').trim()) return true;
    if (!_tagsEqual(current.tags, next.tags)) return true;
    if (!_subtasksEqual(current.subtasks, next.subtasks)) return true;

    final curTr = current.trello;
    final nxtTr = next.trello;
    if (curTr?.listId != nxtTr?.listId) return true;
    if (curTr?.labels != nxtTr?.labels) return true;
    if (curTr?.memberNames != nxtTr?.memberNames) return true;
    if (curTr?.checklistItemCount != nxtTr?.checklistItemCount) return true;
    if (curTr?.checklistCheckedCount != nxtTr?.checklistCheckedCount) return true;
    if (curTr?.commentCount != nxtTr?.commentCount) return true;
    if (curTr?.attachmentCount != nxtTr?.attachmentCount) return true;
    if (curTr?.due != nxtTr?.due) return true;

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
          trello: pulled.trello ?? current.trello,
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
