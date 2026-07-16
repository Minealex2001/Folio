import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/shell/ai_tool_activity_indicator.dart';

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
    test('devuelve una etiqueta conocida en español', () {
      expect(
        aiToolActivityLabel(toolName: 'create_page', isEs: true),
        'Quill está creando una página…',
      );
    });

    test('devuelve una etiqueta conocida en inglés', () {
      expect(
        aiToolActivityLabel(toolName: 'create_page', isEs: false),
        'Quill is creating a page…',
      );
    });

    test('cae a una etiqueta genérica para tools desconocidas', () {
      expect(aiToolActivityLabel(toolName: 'unknown_tool', isEs: true), 'Quill está trabajando…');
      expect(aiToolActivityLabel(toolName: 'unknown_tool', isEs: false), 'Quill is working…');
    });
  });
}
