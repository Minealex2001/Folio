import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase B3 del rediseño UX del editor: gestión de foco predecible tras
/// crear/duplicar un bloque — ambos casos comparten el mismo mecanismo
/// interno (`_pendingFocusIndex`, consumido en la sincronización de
/// `_focusNodes` tras cada rebuild), que es el mismo que ya usa
/// Backspace-merge (caracterizado a nivel de `VaultSession` en
/// `block_editor_keyboard_nav_characterization_test.dart`) — probar los dos
/// casos de aquí cubre también esa ruta sin un tercer test end-to-end
/// redundante sobre el mismo mecanismo interno.
Future<BlockEditorState> _pumpEditor(
  WidgetTester tester,
  VaultSession session,
  AppSettings appSettings,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlockEditor(session: session, appSettings: appSettings),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<BlockEditorState>(find.byType(BlockEditor));
}

KeyDownEvent _keyDown(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
      logicalKey: key,
      physicalKey: physical,
      timeStamp: Duration.zero,
    );

void main() {
  testWidgets(
    'crear un bloque nuevo (Enter) coloca el foco en el bloque recién '
    'creado automáticamente, sin acción adicional del usuario',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      final appSettings = AppSettings();
      session.addPage();
      final pageId = session.selectedPageId!;
      final firstId = '${pageId}_b0';
      session.updateBlockText(pageId, firstId, 'hola');

      final state = await _pumpEditor(tester, session, appSettings);
      state.debugRequestFocusForBlockForTest(firstId);
      await tester.pump();
      expect(state.debugFocusedBlockIdForTest(), firstId);

      expect(
        state.debugInvokeTryInsertNewBlockForTest(force: false),
        isTrue,
      );
      await tester.pumpAndSettle();

      final blocks = session.selectedPage!.blocks;
      expect(blocks.length, greaterThanOrEqualTo(2));
      final secondBlockId = blocks[1].id;
      expect(state.debugFocusedBlockIdForTest(), secondBlockId);
    },
  );

  testWidgets(
    'duplicar un bloque (Ctrl+D) mueve el foco al bloque duplicado — '
    'destino predecible, nunca un foco huérfano ni el original abandonado a '
    'mitad de la nueva copia',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      final appSettings = AppSettings();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.updateBlockText(pageId, blockId, 'hola');

      final state = await _pumpEditor(tester, session, appSettings);
      state.debugRequestFocusForBlockForTest(blockId);
      await tester.pump();
      expect(state.debugFocusedBlockIdForTest(), blockId);

      final baseline = session.selectedPage!.blocks.length;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      state.debugSendKeyEventToFocusedBlockForTest(
        _keyDown(LogicalKeyboardKey.keyD, PhysicalKeyboardKey.keyD),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final blocks = session.selectedPage!.blocks;
      expect(blocks.length, greaterThanOrEqualTo(baseline + 1));
      // El original sigue en la posición 0; el foco pasó a su duplicado
      // (posición 1) — no se queda huérfano en el original ni se pierde.
      expect(blocks[0].id, blockId);
      final duplicateId = blocks[1].id;
      expect(duplicateId, isNot(blockId));
      expect(state.debugFocusedBlockIdForTest(), duplicateId);
    },
  );
}
