import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/settings/quill_workflows_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/quill_workflow.dart';

/// Fase 6 de Quill 2.0 — `AppSettings.load()` siempre trae 4 presets por
/// defecto (`isSystemDefault: true`), así que el picker/página de gestión
/// nunca está realmente "vacía" desde esta fase; los tests reflejan eso y
/// añaden cobertura del guard de solo-lectura para esos presets.
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

  testWidgets('sin workflows de usuario, se listan los 4 presets por defecto (no el estado vacío)', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await _pump(tester, settings);

    final l10n = AppLocalizations.of(tester.element(find.byType(QuillWorkflowsPage)));
    expect(find.text(l10n.quillWorkflowsEmpty), findsNothing);
    expect(find.text(l10n.quillWorkflowPrepMeetingName), findsOneWidget);
    expect(find.text(l10n.quillWorkflowWeeklyReviewName), findsOneWidget);
    expect(find.text(l10n.quillWorkflowPendingTasksName), findsOneWidget);
    expect(find.text(l10n.quillWorkflowAnalyzeProjectName), findsOneWidget);
  });

  testWidgets('lista un workflow existente con su número de versión', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await settings.addQuillWorkflow(
      const QuillWorkflow(id: 'w1', name: 'Mi workflow', currentVersion: 7, promptTemplate: 'A'),
    );

    await _pump(tester, settings);

    expect(find.text('Mi workflow'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(QuillWorkflowsPage)));
    expect(find.text(l10n.quillWorkflowsVersionLabel(7)), findsOneWidget);
  });

  testWidgets('borrar un workflow de usuario lo quita de la lista, sin afectar a los presets por defecto', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await settings.addQuillWorkflow(
      const QuillWorkflow(id: 'w1', name: 'Mi workflow', currentVersion: 1, promptTemplate: 'A'),
    );

    await _pump(tester, settings);
    // Solo los workflows de usuario muestran botón de borrar — con un único
    // workflow de usuario entre los 4 presets, hay exactamente un icono.
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mi workflow'), findsNothing);
    expect(settings.quillWorkflows.where((w) => w.isSystemDefault), hasLength(4));
  });

  testWidgets('un preset por defecto no tiene botón de borrar', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await _pump(tester, settings);

    // Sin ningún workflow de usuario, no debe haber ningún icono de borrar.
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('tocar un preset por defecto abre el diálogo de solo lectura', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await _pump(tester, settings);

    final l10n = AppLocalizations.of(tester.element(find.byType(QuillWorkflowsPage)));
    await tester.tap(find.text(l10n.quillWorkflowPrepMeetingName));
    await tester.pumpAndSettle();

    expect(find.text(l10n.quillWorkflowsViewTitle), findsOneWidget);
    expect(find.text(l10n.quillWorkflowsSave), findsNothing);
    expect(find.text(l10n.quillPromptBack), findsOneWidget);
  });
}
