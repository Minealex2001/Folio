import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/features/settings/widgets/dashboard_template_picker.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;
  late DashboardGridController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_template_picker_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
    controller = DashboardGridController(
      store,
      initialConfig: DashboardConfig(id: 'active', name: 'Inicio'),
      persistDebounce: const Duration(minutes: 10),
    );
  });

  tearDown(() async {
    controller.dispose();
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders one chip per builtin template', (tester) async {
    await tester.pumpWidget(wrap(DashboardTemplatePicker(controller: controller)));

    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('Writer'), findsOneWidget);
    expect(find.text('Research'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Gaming'), findsOneWidget);
  });

  testWidgets('tapping a chip calls onSelected without throwing — full '
      'switchToTemplate completion is covered by the pure-Dart tests in '
      'dashboard_grid_controller_test.dart, not here: awaiting real '
      'ConfigStore file I/O to completion inside a testWidgets body hangs '
      'in this environment (reproduced with a minimal repro against plain '
      'ConfigStore.loadDashboard — a general dart:io/test-binding '
      'interaction, not specific to this widget or to switchToTemplate)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(DashboardTemplatePicker(controller: controller)));

    await tester.tap(find.text('Developer'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the chip matching the controller\'s current dashboard id is '
      'selected — constructed directly (not via switchToTemplate, see the '
      'note above) so this test does no real file I/O', (tester) async {
    controller.dispose();
    controller = DashboardGridController(
      store,
      initialConfig: DashboardConfig(id: 'template-writer', name: 'Writer'),
      persistDebounce: const Duration(minutes: 10),
    );

    await tester.pumpWidget(wrap(DashboardTemplatePicker(controller: controller)));

    final chip = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('Writer'), matching: find.byType(ChoiceChip)),
    );
    expect(chip.selected, isTrue);
  });
}
