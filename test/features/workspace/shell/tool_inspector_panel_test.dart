import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/shell/tool_inspector_panel.dart';

/// Fase A6 del plan Quill/MCP — antes de esta fase, un turno de IA con
/// varias tool-calls solo mostraba la etiqueta de la tool EN CURSO (cada
/// paso nuevo sobrescribía al anterior). `ToolInspectorPanel` acumula todos
/// los pasos del turno y los muestra con su estado (⏳/✔/✗) — tipo Cursor.
void main() {
  Future<void> pump(WidgetTester tester, List<ToolInspectorStep> steps) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToolInspectorPanel(
            steps: steps,
            colorScheme: const ColorScheme.light(),
          ),
        ),
      ),
    );
  }

  testWidgets('sin pasos no renderiza nada', (tester) async {
    await pump(tester, const []);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('un paso running muestra su label y un spinner', (tester) async {
    await pump(tester, const [
      ToolInspectorStep(label: 'Creando página...', status: ToolInspectorStepStatus.running),
    ]);
    expect(find.text('Creando página...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('muestra la secuencia completa del turno, no solo el último paso', (
    tester,
  ) async {
    await pump(tester, const [
      ToolInspectorStep(label: 'Buscando...', status: ToolInspectorStepStatus.success),
      ToolInspectorStep(label: 'Leyendo página...', status: ToolInspectorStepStatus.success),
      ToolInspectorStep(label: 'Creando página...', status: ToolInspectorStepStatus.running),
    ]);

    expect(find.text('Buscando...'), findsOneWidget);
    expect(find.text('Leyendo página...'), findsOneWidget);
    expect(find.text('Creando página...'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('un paso error muestra el icono de cancelación', (tester) async {
    await pump(tester, const [
      ToolInspectorStep(label: 'Falló al crear la carpeta', status: ToolInspectorStepStatus.error),
    ]);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
  });

  test('copyWith preserva el label y cambia solo el status', () {
    const step = ToolInspectorStep(label: 'x', status: ToolInspectorStepStatus.running);
    final updated = step.copyWith(status: ToolInspectorStepStatus.success);
    expect(updated.label, 'x');
    expect(updated.status, ToolInspectorStepStatus.success);
  });
}
