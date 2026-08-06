import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/editor/paste_url_sheet.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

/// Fase D2 del rediseño UX del editor — el sheet de pegado muestra las
/// opciones de GitHub/PDF solo cuando la URL coincide, reutilizando el
/// mismo `showModalBottomSheet` de siempre (mismo sheet, opciones nuevas).
Future<void> _pumpAndOpenSheet(
  WidgetTester tester, {
  required String url,
}) async {
  // El viewport de test por defecto (800x600) es más bajo que el sheet con
  // las opciones de GitHub/PDF añadidas — no es un bug del widget en sí
  // (en pantalla real hay sitio de sobra), solo hace falta más alto aquí.
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showPasteUrlOptionsSheet(context, pastedUrl: url),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('una URL de GitHub muestra la opción de importar', (
    tester,
  ) async {
    await _pumpAndOpenSheet(
      tester,
      url: 'https://github.com/flutter/flutter',
    );

    final l10n = AppLocalizations.of(
      tester.element(find.text('open')),
    );
    expect(find.text(l10n.pasteAsGithubImport), findsOneWidget);
    expect(find.text(l10n.pasteAsPdfSummarize), findsNothing);
  });

  testWidgets('una URL de PDF muestra la opción de guardar como PDF', (
    tester,
  ) async {
    await _pumpAndOpenSheet(tester, url: 'https://example.com/report.pdf');

    final l10n = AppLocalizations.of(
      tester.element(find.text('open')),
    );
    expect(find.text(l10n.pasteAsPdfSummarize), findsOneWidget);
    expect(find.text(l10n.pasteAsGithubImport), findsNothing);
  });

  testWidgets('una URL genérica no muestra ni GitHub ni PDF', (tester) async {
    await _pumpAndOpenSheet(tester, url: 'https://example.com');

    final l10n = AppLocalizations.of(
      tester.element(find.text('open')),
    );
    expect(find.text(l10n.pasteAsGithubImport), findsNothing);
    expect(find.text(l10n.pasteAsPdfSummarize), findsNothing);
  });

  testWidgets('tocar "Importar de GitHub" devuelve githubImport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FolioPasteUrlMode? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPasteUrlOptionsSheet(
                    context,
                    pastedUrl: 'https://github.com/flutter/flutter',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.text('open')),
    );
    await tester.tap(find.text(l10n.pasteAsGithubImport));
    await tester.pumpAndSettle();

    expect(result, FolioPasteUrlMode.githubImport);
  });
}
