import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/shell/ai_tool_activity_indicator.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('AiToolActivityIndicator muestra el label y un spinner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiToolActivityIndicator(
            label: 'Quill está creando una página…',
            colorScheme: ThemeData.light().colorScheme,
          ),
        ),
      ),
    );

    expect(find.text('Quill está creando una página…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AiToolErrorChip muestra el mensaje de error con icono', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiToolErrorChip(
            message: 'Página no encontrada',
            colorScheme: ThemeData.light().colorScheme,
          ),
        ),
      ),
    );

    expect(find.text('Página no encontrada'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  group('aiToolActivityLabel', () {
    late AppLocalizations es;
    late AppLocalizations en;

    setUpAll(() async {
      es = await AppLocalizations.delegate.load(const Locale('es'));
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('devuelve una etiqueta conocida en español', () {
      expect(
        aiToolActivityLabel(toolName: 'create_page', l10n: es),
        es.aiToolActivityCreatePage,
      );
    });

    test('devuelve una etiqueta conocida en inglés', () {
      expect(
        aiToolActivityLabel(toolName: 'create_page', l10n: en),
        en.aiToolActivityCreatePage,
      );
    });

    test('cae a una etiqueta genérica para tools desconocidas', () {
      expect(
        aiToolActivityLabel(toolName: 'unknown_tool', l10n: es),
        es.aiToolActivityWorking,
      );
      expect(
        aiToolActivityLabel(toolName: 'unknown_tool', l10n: en),
        en.aiToolActivityWorking,
      );
    });
  });
}
