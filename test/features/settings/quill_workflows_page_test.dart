import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/settings/quill_workflows_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/quill_workflow.dart';

Future<void> _pump(WidgetTester tester, AppSettings settings) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: QuillWorkflowsPage(appSettings: settings),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sin workflows muestra el estado vacío', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await _pump(tester, settings);

    final l10n = AppLocalizations.of(tester.element(find.byType(QuillWorkflowsPage)));
    expect(find.text(l10n.quillWorkflowsEmpty), findsOneWidget);
  });

  testWidgets('lista un workflow existente con su número de versión', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await settings.addQuillWorkflow(
      const QuillWorkflow(id: 'w1', name: 'Reunión semanal', currentVersion: 1, promptTemplate: 'A'),
    );

    await _pump(tester, settings);

    expect(find.text('Reunión semanal'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(QuillWorkflowsPage)));
    expect(find.text(l10n.quillWorkflowsVersionLabel(1)), findsOneWidget);
  });

  testWidgets('borrar un workflow lo quita de la lista', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await settings.addQuillWorkflow(
      const QuillWorkflow(id: 'w1', name: 'Reunión semanal', currentVersion: 1, promptTemplate: 'A'),
    );

    await _pump(tester, settings);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Reunión semanal'), findsNothing);
    expect(settings.quillWorkflows, isEmpty);
  });
}
