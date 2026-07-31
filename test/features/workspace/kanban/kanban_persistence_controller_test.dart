import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/features/workspace/kanban/kanban_persistence_controller.dart';
import 'package:folio/models/folio_kanban_data.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('KanbanPersistenceController', () {
    late VaultSession session;
    late KanbanPersistenceController controller;
    late String pageId;
    late String blockId;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      session = VaultSession();
      controller = KanbanPersistenceController(session);
      session.addPage();
      pageId = session.selectedPageId!;
      blockId = session.pages
          .firstWhere((p) => p.id == pageId)
          .blocks
          .first
          .id;
    });

    test('persist writes encoded data to the block and round-trips', () {
      final data = FolioKanbanData.defaults().copyWith(
        jiraSourceId: 'jira_1',
      );

      controller.persist(pageId, blockId, data);

      final page = session.pages.firstWhere((p) => p.id == pageId);
      final block = page.blocks.firstWhere((b) => b.id == blockId);
      final parsed = FolioKanbanData.tryParse(block.text ?? '');
      expect(parsed, isNotNull);
      expect(parsed!.jiraSourceId, 'jira_1');
    });

    test('persist is a no-op when blockId is blank', () {
      final page = session.pages.firstWhere((p) => p.id == pageId);
      final before = page.blocks.length;

      controller.persist(pageId, '   ', FolioKanbanData.defaults());

      final after = session.pages.firstWhere((p) => p.id == pageId).blocks.length;
      expect(after, before);
    });

    group('normalizeExclusiveIntegration', () {
      test('leaves data untouched when at most one provider is set', () {
        final data = FolioKanbanData.defaults().copyWith(
          jiraSourceId: 'jira_1',
        );
        final result = controller.normalizeExclusiveIntegration(data);
        expect(result.jiraSourceId, 'jira_1');
      });

      test('Jira wins and clears every other provider', () {
        final data = FolioKanbanData.defaults().copyWith(
          jiraSourceId: 'jira_1',
          youtrackSourceId: 'yt_1',
          trelloSourceId: 'trello_1',
          githubSourceId: 'gh_1',
          gitlabSourceId: 'gl_1',
        );
        final result = controller.normalizeExclusiveIntegration(data);
        expect(result.jiraSourceId, 'jira_1');
        expect(result.youtrackSourceId, isNull);
        expect(result.trelloSourceId, isNull);
        expect(result.githubSourceId, isNull);
        expect(result.gitlabSourceId, isNull);
      });

      test('without Jira, YouTrack wins over Trello/GitHub/GitLab', () {
        final data = FolioKanbanData.defaults().copyWith(
          youtrackSourceId: 'yt_1',
          trelloSourceId: 'trello_1',
          githubSourceId: 'gh_1',
        );
        final result = controller.normalizeExclusiveIntegration(data);
        expect(result.youtrackSourceId, 'yt_1');
        expect(result.trelloSourceId, isNull);
        expect(result.githubSourceId, isNull);
      });
    });

    group('selectIntegration', () {
      test('selecting Jira clears YouTrack and Trello', () {
        final data = FolioKanbanData.defaults().copyWith(
          youtrackSourceId: 'yt_1',
          trelloSourceId: 'trello_1',
        );
        final result = controller.selectIntegration(
          data: data,
          provider: 'jira',
          sourceId: 'jira_1',
        );
        expect(result.jiraSourceId, 'jira_1');
        expect(result.youtrackSourceId, isNull);
        expect(result.trelloSourceId, isNull);
      });

      test('clearing a provider (null/blank sourceId) only resets its own fields', () {
        final data = FolioKanbanData.defaults().copyWith(
          jiraSourceId: 'jira_1',
          jiraAutoImport: true,
        );
        final result = controller.selectIntegration(
          data: data,
          provider: 'jira',
          sourceId: '',
        );
        expect(result.jiraSourceId, isNull);
        expect(result.jiraAutoImport, isFalse);
      });

      test('unknown provider returns data unchanged', () {
        final data = FolioKanbanData.defaults().copyWith(
          jiraSourceId: 'jira_1',
        );
        final result = controller.selectIntegration(
          data: data,
          provider: 'not-a-real-provider',
          sourceId: 'x',
        );
        expect(result, same(data));
      });
    });
  });
}
