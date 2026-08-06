import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase F3 del rediseño UX del editor — reducción de chrome más allá de
/// Zen mode: la pista de atajos de la cabecera de página se atenúa en
/// cuanto el usuario enfoca un bloque y escribe, y reaparece con hover,
/// siguiendo la misma convención "oculto hasta hover/focus" que ya usan
/// el menú "⋮" y el asa de arrastre por fila.
Future<BlockEditorState> _pumpEditor(WidgetTester tester, VaultSession session) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlockEditor(
          session: session,
          appSettings: AppSettings(),
          onAiSlashCommand: (_) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<BlockEditorState>(find.byType(BlockEditor));
}

double _hintOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(BlockEditor),
          matching: find.byType(AnimatedOpacity),
        ).first,
      )
      .opacity;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'visible por defecto (sin bloque enfocado) y se atenúa al enfocar un bloque',
    (tester) async {
      final session = VaultSession();
      session.addPage();
      final blockId = session.selectedPage!.blocks.first.id;

      final state = await _pumpEditor(tester, session);
      expect(_hintOpacity(tester), 1.0);

      state.debugRequestFocusForBlockForTest(blockId);
      await tester.pumpAndSettle();

      expect(_hintOpacity(tester), 0.0);
    },
  );

  testWidgets('reaparece con hover aunque haya un bloque enfocado', (tester) async {
    final session = VaultSession();
    session.addPage();
    final blockId = session.selectedPage!.blocks.first.id;

    final state = await _pumpEditor(tester, session);
    state.debugRequestFocusForBlockForTest(blockId);
    await tester.pumpAndSettle();
    expect(_hintOpacity(tester), 0.0);

    final hintFinder = find.descendant(
      of: find.byType(BlockEditor),
      matching: find.byType(AnimatedOpacity),
    ).first;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(hintFinder));
    await tester.pumpAndSettle();

    expect(_hintOpacity(tester), 1.0);
  });
}
