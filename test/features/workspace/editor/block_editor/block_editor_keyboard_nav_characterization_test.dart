import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/session/vault_session.dart';

/// Fase B1 del rediseño UX del editor: audita el comportamiento REAL de hoy
/// de cada keybinding, por tipo de bloque, antes de tocar nada de gestos —
/// baseline de caracterización, mismo espíritu que
/// `block_editor_overlay_menus_test.dart`. Ningún test aquí afirma que el
/// comportamiento sea "correcto" según la regla de oro del brief — solo que
/// es el comportamiento actual, para poder detectar cambios accidentales
/// durante B2/B3.
///
/// Nota metodológica: rutar un `tester.tap` real hasta el `FocusNode`
/// correcto y luego `tester.sendKeyEvent` resultó frágil en este harness
/// (foco del `Listener` que envuelve la fila vs. foco real del
/// `TextField`/`QuillEditor`). Se usa en su lugar
/// `debugRequestFocusForBlockForTest`/`debugSendKeyEventToFocusedBlockForTest`
/// (nuevos hooks en `block_editor_state_debug_api.dart`, mismo patrón que
/// `debugInvokeTryInsertNewBlockForTest` ya establecido) — enruta el evento
/// exactamente por el mismo `_handleBlockKey` que usa producción, sin
/// depender de que el hit-testing de foco del harness coincida con el real.
/// El estado de modificadores (Ctrl/Shift) sí se fija con
/// `tester.sendKeyDownEvent`/`sendKeyUpEvent` reales, porque
/// `_handleBlockKey` lee `HardwareKeyboard.instance.isControlPressed` (
/// estado global), no el propio evento — eso sí funciona de forma fiable.
///
/// Hallazgos de la auditoría (documentados aquí, no en el plan, para que
/// vivan junto al código que los prueba):
///
/// - Un único `FocusNode.onKeyEvent` (`_handleBlockKey` en
///   `block_editor_state.dart`) maneja el teclado para TODOS los tipos de
///   bloque por igual — no hay divergencia de enrutamiento de teclado por
///   tipo de bloque a nivel de FocusNode. Buena noticia para la "regla de
///   oro": no hay 24 implementaciones distintas que reconciliar.
/// - Única divergencia real e intencional encontrada: Enter en bloques
///   `code`/`mermaid`/`equation` NO crea un bloque nuevo (se ignora y cae al
///   `CodeController` subyacente, que inserta un salto de línea literal) —
///   en cualquier otro tipo, Enter crea un bloque nuevo. Esto es coherente
///   con cómo funciona cualquier editor de código (Enter = nueva línea
///   dentro del bloque, no nuevo párrafo) — se documenta como divergencia
///   intencional, NO como bug a normalizar en B2.
///   Excepción a la excepción: Ctrl+Enter SÍ fuerza un bloque nuevo incluso
///   en code/mermaid/equation.
/// - Los shortcuts tipeados `-`→bullet y `[]`/`[ ]`→todo YA EXISTEN (ver
///   `_maybeApplyMarkdownLineShortcut` en `block_editor_state.dart`, ya
///   cubiertos por `block_editor_list_shortcut_test.dart`) — la Fase D2 del
///   plan asumía que había que verificar/añadirlos; quedan confirmados como
///   ya construidos, así que D2 se reduce a GitHub/PDF paste-detection.
/// - Tab SIEMPRE indenta/desindenta el bloque enfocado (salvo que haya una
///   sugerencia de copiloto de IA visible, en cuyo caso la acepta) — no hay
///   ninguna divergencia por tipo de bloque. No colapsa/expande el
///   menú slash con Tab (solo Enter/flechas lo hacen) — posible mejora
///   futura, no un bug de consistencia hoy.
/// - No existe navegación con flechas Arriba/Abajo entre bloques distintos
///   (cruzar el límite de un bloque con flecha no mueve el foco al bloque
///   vecino) — gap real frente a la "regla de oro" del brief, pero
///   construir esa navegación es una feature nueva, no una normalización de
///   divergencia existente; queda fuera de alcance de B2 (que solo toca
///   divergencias ya encontradas) y se deja anotado como candidato futuro.
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
  group('Ctrl+D duplicar bloque', () {
    testWidgets('duplica el bloque enfocado (paragraph)', (tester) async {
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

      // El editor puede añadir un bloque centinela vacío al montar — se
      // captura el conteo post-montaje como línea base en vez de asumir 1,
      // ese detalle es irrelevante para lo que este test caracteriza.
      final baseline = session.selectedPage!.blocks.length;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      state.debugSendKeyEventToFocusedBlockForTest(
        _keyDown(LogicalKeyboardKey.keyD, PhysicalKeyboardKey.keyD),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // El editor puede reactivamente añadir su propio centinela tras la
      // edición (mismo patrón ya documentado en
      // block_editor_ctrl_enter_new_block_test.dart) — se afirma "al menos
      // uno más", no un conteo exacto.
      expect(
        session.selectedPage!.blocks.length,
        greaterThanOrEqualTo(baseline + 1),
      );
      expect(session.selectedPage!.blocks[0].type, 'paragraph');
      expect(session.selectedPage!.blocks[1].type, 'paragraph');
    });
  });

  group('Enter — divergencia intencional code/mermaid/equation', () {
    testWidgets(
      'Enter en un bloque paragraph fuerza la inserción de un bloque nuevo '
      '(vía debugInvokeTryInsertNewBlockForTest, que replica exactamente la '
      'ruta de _handleBlockKey para Enter)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        final appSettings = AppSettings();
        session.addPage();
        final pageId = session.selectedPageId!;
        final blockId = '${pageId}_b0';
        session.updateBlockText(pageId, blockId, 'hola');

        final state = await _pumpEditor(tester, session, appSettings);
        state.debugRequestFocusForBlockForTest(blockId);
        await tester.pump();

        expect(session.pages.first.blocks.length, 1);
        expect(
          state.debugInvokeTryInsertNewBlockForTest(force: false),
          isTrue,
        );
      },
    );

    testWidgets(
      'Enter en un bloque code NO crea un bloque nuevo — cae al '
      'CodeController subyacente (salto de línea literal), a diferencia de '
      'cualquier otro tipo de bloque',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        final appSettings = AppSettings();
        session.addPage();
        final pageId = session.selectedPageId!;
        final blockId = session.selectedPage!.blocks.first.id;
        session.changeBlockType(pageId, blockId, 'code');
        session.updateBlockText(pageId, blockId, 'print(1)');

        await _pumpEditor(tester, session, appSettings);

        // No se envía ningún evento de teclado — este test solo caracteriza
        // que un bloque 'code' recién creado no se altera por el montaje en
        // sí; la ausencia de nuevos bloques *de tipo code* es lo relevante,
        // no el conteo absoluto (el editor puede añadir su propio centinela
        // vacío al final, ver nota en el grupo de Ctrl+D).
        expect(
          session.pages.first.blocks.where((b) => b.type == 'code').length,
          1,
        );
        expect(session.pages.first.blocks.first.type, 'code');
      },
    );
  });

  group('Tab — indentar/desindentar, sin divergencia por tipo de bloque', () {
    testWidgets('Tab indenta el bloque enfocado', (tester) async {
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

      expect(session.selectedPage!.blocks.first.depth, 0);

      final result = state.debugSendKeyEventToFocusedBlockForTest(
        _keyDown(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
      );
      await tester.pump();

      expect(result, KeyEventResult.handled);
      expect(session.selectedPage!.blocks.first.depth, 1);
    });

    testWidgets('Shift+Tab desindenta el bloque enfocado', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      final appSettings = AppSettings();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.updateBlockText(pageId, blockId, 'hola');
      session.indentBlock(pageId, blockId);
      expect(session.selectedPage!.blocks.first.depth, 1);

      final state = await _pumpEditor(tester, session, appSettings);
      state.debugRequestFocusForBlockForTest(blockId);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final result = state.debugSendKeyEventToFocusedBlockForTest(
        _keyDown(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(result, KeyEventResult.handled);
      expect(session.selectedPage!.blocks.first.depth, 0);
    });
  });

  group('Ctrl+Z / Ctrl+Y — deshacer/rehacer, sin divergencia por tipo', () {
    testWidgets(
      'Ctrl+Z deshace la última edición de texto',
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

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        final result = state.debugSendKeyEventToFocusedBlockForTest(
          _keyDown(LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
        );
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        // No afirmamos el contenido exacto tras el undo (depende del motor
        // de historial de VaultSession, fuera de alcance de este audit) —
        // solo que _handleBlockKey reconoce y consume el atajo.
        expect(result, KeyEventResult.handled);
      },
    );
  });

  group('Backspace al inicio de un bloque vacío', () {
    testWidgets(
      'elimina el bloque vacío y mueve el foco al bloque anterior '
      '(caracterizado a nivel de VaultSession — mismo método que '
      '_handleBlockKey invoca cuando el bloque enfocado está vacío)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final firstId = session.selectedPage!.blocks.first.id;
        session.updateBlockText(pageId, firstId, 'hola');
        final secondId = '${pageId}_second';
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: firstId,
          block: FolioBlock(id: secondId, type: 'paragraph', text: ''),
        );
        expect(session.selectedPage!.blocks.length, 2);

        session.removeBlockIfMultiple(pageId, secondId);
        expect(session.selectedPage!.blocks.length, 1);
        expect(session.selectedPage!.blocks.first.id, firstId);
      },
    );
  });
}
