import '../../../models/folio_kanban_data.dart';
import '../../../session/vault_session.dart';

/// Pure data-mutation logic for a Kanban block: persisting
/// [FolioKanbanData] back to its block, and the cross-provider exclusivity
/// rules for the (Jira XOR YouTrack XOR Trello XOR GitHub XOR GitLab)
/// integration a board may have. Extracted from `_KanbanBoardPageState`
/// since these methods have no BuildContext/dialog dependency, unlike the
/// column-rename/color-picker/add-column dialogs that call them -- those
/// stay in the page state as genuinely UI-coupled code.
class KanbanPersistenceController {
  KanbanPersistenceController(this._session);

  final VaultSession _session;

  void persist(String pageId, String blockId, FolioKanbanData data) {
    if (blockId.trim().isEmpty) return;
    _session.updateBlockText(pageId, blockId, data.encode());
  }

  /// Un Kanban solo puede tener una integración (Jira XOR YouTrack XOR Trello XOR GitHub XOR GitLab).
  FolioKanbanData normalizeExclusiveIntegration(FolioKanbanData data) {
    final hasJira = (data.jiraSourceId ?? '').trim().isNotEmpty;
    final hasYt = (data.youtrackSourceId ?? '').trim().isNotEmpty;
    final hasTr = (data.trelloSourceId ?? '').trim().isNotEmpty;
    final hasGh = (data.githubSourceId ?? '').trim().isNotEmpty;
    final hasGl = (data.gitlabSourceId ?? '').trim().isNotEmpty;
    final count = (hasJira ? 1 : 0) +
        (hasYt ? 1 : 0) +
        (hasTr ? 1 : 0) +
        (hasGh ? 1 : 0) +
        (hasGl ? 1 : 0);
    if (count <= 1) return data;
    if (hasJira) {
      return data.copyWith(
        youtrackSourceId: null,
        youtrackAutoImport: false,
        youtrackCreateIssuesOnQuickAdd: false,
        trelloSourceId: null,
        trelloAutoImport: false,
        trelloCreateCardsOnQuickAdd: false,
        githubSourceId: null,
        githubAutoImport: false,
        githubCreateIssuesOnQuickAdd: false,
        gitlabSourceId: null,
        gitlabAutoImport: false,
        gitlabCreateIssuesOnQuickAdd: false,
      );
    }
    if (hasYt) {
      return data.copyWith(
        trelloSourceId: null,
        trelloAutoImport: false,
        trelloCreateCardsOnQuickAdd: false,
        githubSourceId: null,
        githubAutoImport: false,
        githubCreateIssuesOnQuickAdd: false,
        gitlabSourceId: null,
        gitlabAutoImport: false,
        gitlabCreateIssuesOnQuickAdd: false,
      );
    }
    if (hasTr) {
      return data.copyWith(
        githubSourceId: null,
        githubAutoImport: false,
        githubCreateIssuesOnQuickAdd: false,
        gitlabSourceId: null,
        gitlabAutoImport: false,
        gitlabCreateIssuesOnQuickAdd: false,
      );
    }
    if (hasGh) {
      return data.copyWith(
        gitlabSourceId: null,
        gitlabAutoImport: false,
        gitlabCreateIssuesOnQuickAdd: false,
      );
    }
    return data;
  }

  FolioKanbanData selectIntegration({
    required FolioKanbanData data,
    required String provider,
    required String? sourceId,
  }) {
    final clear = sourceId == null || sourceId.trim().isEmpty;
    switch (provider) {
      case 'jira':
        if (clear) {
          return data.copyWith(
            jiraSourceId: null,
            jiraAutoImport: false,
            jiraCreateIssuesOnQuickAdd: false,
          );
        }
        return data.copyWith(
          jiraSourceId: sourceId,
          youtrackSourceId: null,
          youtrackAutoImport: false,
          youtrackCreateIssuesOnQuickAdd: false,
          trelloSourceId: null,
          trelloAutoImport: false,
          trelloCreateCardsOnQuickAdd: false,
        );
      case 'youtrack':
        if (clear) {
          return data.copyWith(
            youtrackSourceId: null,
            youtrackAutoImport: false,
            youtrackCreateIssuesOnQuickAdd: false,
          );
        }
        return data.copyWith(
          youtrackSourceId: sourceId,
          jiraSourceId: null,
          jiraAutoImport: false,
          jiraCreateIssuesOnQuickAdd: false,
          trelloSourceId: null,
          trelloAutoImport: false,
          trelloCreateCardsOnQuickAdd: false,
        );
      case 'trello':
        if (clear) {
          return data.copyWith(
            trelloSourceId: null,
            trelloAutoImport: false,
            trelloCreateCardsOnQuickAdd: false,
          );
        }
        return data.copyWith(
          trelloSourceId: sourceId,
          jiraSourceId: null,
          jiraAutoImport: false,
          jiraCreateIssuesOnQuickAdd: false,
          youtrackSourceId: null,
          youtrackAutoImport: false,
          youtrackCreateIssuesOnQuickAdd: false,
          githubSourceId: null,
          githubAutoImport: false,
          githubCreateIssuesOnQuickAdd: false,
        );
      case 'github':
        if (clear) {
          return data.copyWith(
            githubSourceId: null,
            githubAutoImport: false,
            githubCreateIssuesOnQuickAdd: false,
          );
        }
        return data.copyWith(
          githubSourceId: sourceId,
          jiraSourceId: null,
          jiraAutoImport: false,
          jiraCreateIssuesOnQuickAdd: false,
          youtrackSourceId: null,
          youtrackAutoImport: false,
          youtrackCreateIssuesOnQuickAdd: false,
          trelloSourceId: null,
          trelloAutoImport: false,
          trelloCreateCardsOnQuickAdd: false,
          gitlabSourceId: null,
          gitlabAutoImport: false,
          gitlabCreateIssuesOnQuickAdd: false,
        );
      case 'gitlab':
        if (clear) {
          return data.copyWith(
            gitlabSourceId: null,
            gitlabAutoImport: false,
            gitlabCreateIssuesOnQuickAdd: false,
          );
        }
        return data.copyWith(
          gitlabSourceId: sourceId,
          jiraSourceId: null,
          jiraAutoImport: false,
          jiraCreateIssuesOnQuickAdd: false,
          youtrackSourceId: null,
          youtrackAutoImport: false,
          youtrackCreateIssuesOnQuickAdd: false,
          trelloSourceId: null,
          trelloAutoImport: false,
          trelloCreateCardsOnQuickAdd: false,
          githubSourceId: null,
          githubAutoImport: false,
          githubCreateIssuesOnQuickAdd: false,
        );
      default:
        return data;
    }
  }
}
