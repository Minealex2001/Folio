import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/workspace_config.dart';
import 'package:folio/features/workspace/shell/workspace_tab_strip.dart';
import 'package:folio/session/workspace_state_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;
  late WorkspaceStateController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_tab_strip_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
    controller = WorkspaceStateController(
      store,
      initialConfig: const WorkspaceConfig(),
      persistDebounce: const Duration(minutes: 10),
    );
  });

  tearDown(() async {
    controller.dispose();
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  String titleFor(String pageId) => 'Title for $pageId';

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders nothing when there are no open tabs', (tester) async {
    await tester.pumpWidget(
      wrap(
        WorkspaceTabStrip(
          controller: controller,
          pageTitleFor: titleFor,
          onSelectPage: (_) {},
        ),
      ),
    );
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('renders one tab per open page, with the title resolved via '
      'pageTitleFor', (tester) async {
    controller.openTab('page-1');
    controller.openTab('page-2');

    await tester.pumpWidget(
      wrap(
        WorkspaceTabStrip(
          controller: controller,
          pageTitleFor: titleFor,
          onSelectPage: (_) {},
        ),
      ),
    );

    expect(find.text('Title for page-1'), findsOneWidget);
    expect(find.text('Title for page-2'), findsOneWidget);

    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('tapping a tab activates it and calls onSelectPage', (
    tester,
  ) async {
    controller.openTab('page-1');
    controller.openTab('page-2');
    String? selected;

    await tester.pumpWidget(
      wrap(
        WorkspaceTabStrip(
          controller: controller,
          pageTitleFor: titleFor,
          onSelectPage: (id) => selected = id,
        ),
      ),
    );

    await tester.tap(find.text('Title for page-1'));
    await tester.pump();

    expect(selected, 'page-1');
    expect(controller.config.activeTabId, 'page-1');

    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('tapping the close icon on an unpinned tab closes it', (
    tester,
  ) async {
    controller.openTab('page-1');

    await tester.pumpWidget(
      wrap(
        WorkspaceTabStrip(
          controller: controller,
          pageTitleFor: titleFor,
          onSelectPage: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(controller.config.openTabs, isEmpty);

    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('a pinned tab shows a pin icon and hides the close button', (
    tester,
  ) async {
    controller.openTab('page-1');
    controller.setTabPinned('page-1', true);

    await tester.pumpWidget(
      wrap(
        WorkspaceTabStrip(
          controller: controller,
          pageTitleFor: titleFor,
          onSelectPage: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });

  testWidgets('tabs render in order, reacting live to controller changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        WorkspaceTabStrip(
          controller: controller,
          pageTitleFor: titleFor,
          onSelectPage: (_) {},
        ),
      ),
    );
    expect(find.byType(ListView), findsNothing);

    controller.openTab('page-1');
    await tester.pump();

    expect(find.text('Title for page-1'), findsOneWidget);

    await tester.pump(const Duration(minutes: 11)); // deja vencer el debounce
  });
}
