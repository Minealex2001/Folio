import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/workspace_config.dart';
import 'package:folio/session/workspace_state_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_workspace_state_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  WorkspaceStateController makeController({Duration? debounce}) {
    return WorkspaceStateController(
      store,
      initialConfig: const WorkspaceConfig(),
      persistDebounce: debounce ?? const Duration(minutes: 10),
    );
  }

  test('load() falls back to a default WorkspaceConfig when nothing is '
      'persisted yet', () async {
    final controller = await WorkspaceStateController.load(store);
    expect(controller.config.focusMode, isFalse);
    expect(controller.config.aiPanelOpen, isFalse);
    expect(controller.config.openTabs, isEmpty);
  });

  test('load() returns the persisted document when one exists', () async {
    await store.saveWorkspaceState(const WorkspaceConfig(focusMode: true));
    final controller = await WorkspaceStateController.load(store);
    expect(controller.config.focusMode, isTrue);
  });

  test('setFocusMode toggles the flag and notifies listeners', () {
    final controller = makeController();
    var notified = false;
    controller.addListener(() => notified = true);

    controller.setFocusMode(true);

    expect(controller.config.focusMode, isTrue);
    expect(notified, isTrue);
  });

  test('setActivePageId / clearing sets and clears the field', () {
    final controller = makeController();
    controller.setActivePageId('page-1');
    expect(controller.config.activePageId, 'page-1');

    controller.setActivePageId(null);
    expect(controller.config.activePageId, isNull);
  });

  test('togglePinnedPage adds then removes a page id', () {
    final controller = makeController();
    controller.togglePinnedPage('page-1');
    expect(controller.config.pinnedPageIds, ['page-1']);

    controller.togglePinnedPage('page-1');
    expect(controller.config.pinnedPageIds, isEmpty);
  });

  group('tabs (Fase 29 UI builds on these)', () {
    test('openTab adds a new tab and activates it', () {
      final controller = makeController();
      controller.openTab('page-1');

      expect(controller.config.openTabs.map((t) => t.pageId), ['page-1']);
      expect(controller.config.activeTabId, 'page-1');
    });

    test('openTab on an already-open page just activates it, no duplicate', () {
      final controller = makeController();
      controller.openTab('page-1');
      controller.openTab('page-2');
      controller.openTab('page-1');

      expect(controller.config.openTabs.length, 2);
      expect(controller.config.activeTabId, 'page-1');
    });

    test('closeTab removes the tab and, if it was active, activates the '
        'last remaining tab', () {
      final controller = makeController();
      controller.openTab('page-1');
      controller.openTab('page-2');
      expect(controller.config.activeTabId, 'page-2');

      controller.closeTab('page-2');

      expect(controller.config.openTabs.map((t) => t.pageId), ['page-1']);
      expect(controller.config.activeTabId, 'page-1');
    });

    test('closing the only open tab clears activeTabId entirely', () {
      final controller = makeController();
      controller.openTab('page-1');
      controller.closeTab('page-1');

      expect(controller.config.openTabs, isEmpty);
      expect(controller.config.activeTabId, isNull);
    });

    test('closing a non-active tab leaves activeTabId untouched', () {
      final controller = makeController();
      controller.openTab('page-1');
      controller.openTab('page-2');
      controller.activateTab('page-1');

      controller.closeTab('page-2');

      expect(controller.config.activeTabId, 'page-1');
    });

    test('setTabPinned pins only the targeted tab', () {
      final controller = makeController();
      controller.openTab('page-1');
      controller.openTab('page-2');

      controller.setTabPinned('page-1', true);

      final tab1 = controller.config.openTabs.firstWhere((t) => t.pageId == 'page-1');
      final tab2 = controller.config.openTabs.firstWhere((t) => t.pageId == 'page-2');
      expect(tab1.pinned, isTrue);
      expect(tab2.pinned, isFalse);
    });
  });

  test('mutations schedule persistence — round-trips through the store', () async {
    final controller = WorkspaceStateController(
      store,
      initialConfig: const WorkspaceConfig(),
      persistDebounce: const Duration(milliseconds: 10),
    );

    controller.setFocusMode(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final loaded = await store.loadWorkspaceState();
    expect(loaded?.focusMode, isTrue);
  });
}
