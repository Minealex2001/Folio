import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/kanban/kanban_integration_sync_controller.dart';

void main() {
  group('KanbanIntegrationSyncController', () {
    test('isBusy is false before and after a successful run', () async {
      final controller = KanbanIntegrationSyncController();
      var stateChanges = 0;

      expect(controller.isBusy('jira'), false);

      await controller.run(
        'jira',
        () async {
          expect(controller.isBusy('jira'), true);
        },
        onStateChanged: () => stateChanges++,
      );

      expect(controller.isBusy('jira'), false);
      expect(stateChanges, 2);
    });

    test('isBusy resets to false even if the action throws', () async {
      final controller = KanbanIntegrationSyncController();

      await expectLater(
        controller.run(
          'github',
          () async => throw StateError('boom'),
          onStateChanged: () {},
        ),
        throwsA(isA<StateError>()),
      );

      expect(controller.isBusy('github'), false);
    });

    test('a second run for the same key is skipped while one is in flight', () async {
      final controller = KanbanIntegrationSyncController();
      var runCount = 0;
      final gate = Completer<void>();

      final first = controller.run('gitlab', () async {
        runCount++;
        await gate.future;
      }, onStateChanged: () {});

      // Started but not yet completed: a concurrent call for the same key
      // should be a no-op rather than running the action again.
      await controller.run('gitlab', () async {
        runCount++;
      }, onStateChanged: () {});

      expect(runCount, 1);

      gate.complete();
      await first;
      expect(controller.isBusy('gitlab'), false);
    });

    test('different keys track busy state independently', () async {
      final controller = KanbanIntegrationSyncController();
      final gate = Completer<void>();

      final jiraRun = controller.run('jira', () => gate.future, onStateChanged: () {});

      expect(controller.isBusy('jira'), true);
      expect(controller.isBusy('trello'), false);

      gate.complete();
      await jiraRun;
    });
  });
}
