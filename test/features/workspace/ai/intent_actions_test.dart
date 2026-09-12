import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/ai/intent_actions.dart';

/// Fase A2 del plan Quill/MCP — `IntentActionBar` es el componente genérico
/// de "aquí hay un resultado, elige qué hacer con él", reutilizado ahora por
/// el chat (Fase A2) y pensado para futuras superficies (D1, workflows).
/// Este archivo prueba el widget en aislamiento — sin `VaultSession` ni
/// `WorkspacePage` — porque no conoce ningún mecanismo de aplicar cambios,
/// solo pinta lo que el llamador le pasa.
void main() {
  Future<void> pump(WidgetTester tester, List<IntentAction> actions) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IntentActionBar(actions: actions)),
      ),
    );
  }

  testWidgets('sin acciones no renderiza nada', (tester) async {
    await pump(tester, const []);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('una acción primary se pinta como FilledButton.tonal', (tester) async {
    var tapped = false;
    await pump(tester, [
      IntentAction(id: 'a', label: 'Insertar', primary: true, onPressed: () => tapped = true),
    ]);

    expect(find.widgetWithText(FilledButton, 'Insertar'), findsOneWidget);
    await tester.tap(find.text('Insertar'));
    expect(tapped, isTrue);
  });

  testWidgets('una acción no-primary se pinta como OutlinedButton', (tester) async {
    await pump(tester, [
      IntentAction(id: 'a', label: 'Reemplazar', onPressed: () {}),
    ]);

    expect(find.widgetWithText(OutlinedButton, 'Reemplazar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('varias acciones se renderizan en el orden dado, cada una con su callback', (
    tester,
  ) async {
    final calls = <String>[];
    await pump(tester, [
      IntentAction(id: 'a', label: 'Insertar al final', primary: true, onPressed: () => calls.add('a')),
      IntentAction(id: 'b', label: 'Reemplazar folio', onPressed: () => calls.add('b')),
      IntentAction(id: 'c', label: 'Crear página', onPressed: () => calls.add('c')),
    ]);

    await tester.tap(find.text('Reemplazar folio'));
    await tester.tap(find.text('Crear página'));

    expect(calls, ['b', 'c']);
    expect(find.text('Insertar al final'), findsOneWidget);
  });

  testWidgets('una acción con icono lo muestra junto al label', (tester) async {
    await pump(tester, [
      IntentAction(
        id: 'a',
        label: 'Guardar como hecho',
        icon: Icons.bookmark_add_outlined,
        onPressed: () {},
      ),
    ]);

    expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
    expect(find.text('Guardar como hecho'), findsOneWidget);
  });
}
