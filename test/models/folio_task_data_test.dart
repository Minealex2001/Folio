import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/services/tasks/task_reminder_service.dart';

void main() {
  group('FolioTaskData', () {
    test('serializa y parsea subtareas', () {
      final data = FolioTaskData(
        title: 'Implementar bloque',
        status: 'in_progress',
        priority: 'high',
        dueDate: '2026-03-31',
        subtasks: const [
          FolioTaskSubtask(id: 's1', title: 'Modelo', status: 'done'),
          FolioTaskSubtask(id: 's2', title: 'UI', status: 'todo'),
        ],
      );

      final parsed = FolioTaskData.tryParse(data.encode());
      expect(parsed, isNotNull);
      expect(parsed!.title, 'Implementar bloque');
      expect(parsed.status, 'in_progress');
      expect(parsed.priority, 'high');
      expect(parsed.dueDate, '2026-03-31');
      expect(parsed.subtasks.length, 2);
      expect(parsed.subtasks.first.status, 'done');
      expect(parsed.subtasks.last.title, 'UI');
    });

    test('mantiene compatibilidad con payload sin subtareas', () {
      const raw = '{"v":1,"title":"Legacy","status":"todo"}';
      final parsed = FolioTaskData.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.title, 'Legacy');
      expect(parsed.subtasks, isEmpty);
    });

    test('copyWith permite reemplazar subtareas', () {
      final base = FolioTaskData.defaults();
      final next = base.copyWith(
        subtasks: const [
          FolioTaskSubtask(id: 'a', title: 'Primera', status: 'todo'),
        ],
      );
      expect(next.subtasks.length, 1);
      expect(next.subtasks.first.id, 'a');
    });

    test('serializa y parsea external (Jira)', () {
      final data = FolioTaskData(
        title: 'Sync issue',
        status: 'todo',
        external: const FolioExternalTaskLink(
          provider: 'jira',
          issueId: '10001',
          issueKey: 'ABC-123',
          deployment: 'cloud',
          cloudId: 'cloud_1',
          remoteVersion: '42',
          syncState: 'ok',
        ),
      );
      final parsed = FolioTaskData.tryParse(data.encode());
      expect(parsed, isNotNull);
      expect(parsed!.external, isNotNull);
      expect(parsed.external!.provider, 'jira');
      expect(parsed.external!.issueId, '10001');
      expect(parsed.external!.issueKey, 'ABC-123');
      expect(parsed.external!.deployment, 'cloud');
      expect(parsed.external!.cloudId, 'cloud_1');
      expect(parsed.external!.remoteVersion, '42');
    });

    test('v4: serializa y parsea tags, assignee, dependencias y metadatos IA', () {
      final data = FolioTaskData(
        title: 'Tarea rica',
        status: 'todo',
        tags: const ['review', 'cliente'],
        assignee: '@ana',
        estimatedMinutes: 45,
        storyPoints: 3.5,
        customProperties: const {'area': 'work'},
        recurringRule: 'FREQ=DAILY',
        blockedByTaskIds: const ['page_block1', 'page_block2'],
        aiGenerated: true,
        createdFromBlockId: 'blk_src',
        aiContextPageId: 'page_ctx',
        confidenceScore: 0.82,
        suggestedDueDate: '2026-06-01',
      );
      final parsed = FolioTaskData.tryParse(data.encode());
      expect(parsed, isNotNull);
      expect(parsed!.tags, ['review', 'cliente']);
      expect(parsed.assignee, '@ana');
      expect(parsed.estimatedMinutes, 45);
      expect(parsed.storyPoints, 3.5);
      expect(parsed.customProperties['area'], 'work');
      expect(parsed.recurringRule, 'FREQ=DAILY');
      expect(parsed.blockedByTaskIds, ['page_block1', 'page_block2']);
      expect(parsed.aiGenerated, isTrue);
      expect(parsed.createdFromBlockId, 'blk_src');
      expect(parsed.aiContextPageId, 'page_ctx');
      expect(parsed.confidenceScore, closeTo(0.82, 1e-9));
      expect(parsed.suggestedDueDate, '2026-06-01');
      final map = jsonDecode(data.encode()) as Map<String, dynamic>;
      expect(map['v'], 4);
    });

    test('advanceRecurrence usa recurringRule FREQ=WEEKLY', () {
      final data = FolioTaskData(
        title: 'R',
        status: 'done',
        dueDate: '2026-06-01',
        recurringRule: 'FREQ=WEEKLY;INTERVAL=1',
      );
      final next = TaskReminderService.advanceRecurrence(data);
      expect(next, isNotNull);
      expect(next!.status, 'todo');
      expect(next.dueDate, startsWith('2026-06-08'));
    });

    test('serializa y parsea snapshot Jira', () {
      final data = FolioTaskData(
        title: 'Issue con snapshot',
        status: 'todo',
        external: const FolioExternalTaskLink(provider: 'jira', issueId: '1'),
        jira: const FolioJiraIssueSnapshot(
          projectKey: 'ABC',
          issueType: 'Task',
          statusId: '10000',
          statusName: 'To Do',
          assigneeAccountId: 'acc_1',
          assigneeDisplayName: 'Alice',
          labels: ['a', 'b'],
          components: ['Comp'],
          customFields: {'customfield_10016': 'X'},
          worklogCount: 2,
          commentCount: 3,
          attachmentCount: 4,
        ),
      );
      final parsed = FolioTaskData.tryParse(data.encode());
      expect(parsed, isNotNull);
      expect(parsed!.jira, isNotNull);
      expect(parsed.jira!.projectKey, 'ABC');
      expect(parsed.jira!.labels, ['a', 'b']);
      expect(parsed.jira!.customFields['customfield_10016'], 'X');
      expect(parsed.jira!.attachmentCount, 4);
    });
  });
}
