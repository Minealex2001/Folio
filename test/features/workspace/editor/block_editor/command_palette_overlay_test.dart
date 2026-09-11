import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/command_palette/command_palette_overlay.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase C2 del rediseño UX del editor — overlay del Command Palette.
/// Mismo patrón de test que `block_editor_overlay_menus_test.dart`
/// (pumpear `BlockEditor`, alcanzar `BlockEditorState` vía
/// `tester.state<...>`).
Future<BlockEditorState> _pumpEditor(
  WidgetTester tester,
  VaultSession session,
) async {
  // El Palette se inserta en el Overlay raíz de la app (pantalla completa),
  // no en el árbol del Scaffold — se agranda la superficie de test para que
  // los 9 comandos de IA quepan sin necesitar scroll en las aserciones.
  tester.view.physicalSize = const Size(1000, 1400);
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

void main() {
  testWidgets('showCommandPaletteOverlay muestra el overlay con foco en la '
      'búsqueda', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    session.addPage();
    final state = await _pumpEditor(tester, session);

    expect(find.byType(CommandPaletteOverlay), findsNothing);
    state.showCommandPaletteOverlay();
    await tester.pump();

    expect(find.byType(CommandPaletteOverlay), findsOneWidget);
    expect(state.isCommandPaletteOpen, isTrue);
  });

  testWidgets('lista los 9 comandos de IA al abrir sin query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    session.addPage();
    final state = await _pumpEditor(tester, session);

    state.showCommandPaletteOverlay();
    await tester.pump();

    // `ListView` virtualiza — no todos los 9 caben simultáneamente en el
    // viewport de test. El conteo real ya está probado en
    // `command_palette_ai_provider_test.dart`; aquí solo se confirma que
    // el overlay realmente los está listando (no "Sin resultados").
    expect(find.text('Sin resultados'), findsNothing);
    expect(find.byType(ListTile), findsWidgets);
    expect(
      state.commandPaletteRegistry.resolve().length,
      9,
    );
  });

  testWidgets('escribir en la búsqueda filtra la lista', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    session.addPage();
    final state = await _pumpEditor(tester, session);

    state.showCommandPaletteOverlay();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'summ');
    await tester.pump();

    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('Escape cierra el overlay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    session.addPage();
    final state = await _pumpEditor(tester, session);

    state.showCommandPaletteOverlay();
    await tester.pump();
    expect(find.byType(CommandPaletteOverlay), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byType(CommandPaletteOverlay), findsNothing);
    expect(state.isCommandPaletteOpen, isFalse);
  });

  testWidgets('tocar fuera del panel cierra el overlay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    session.addPage();
    final state = await _pumpEditor(tester, session);

    state.showCommandPaletteOverlay();
    await tester.pump();

    // Esquina inferior derecha de la pantalla — fuera del panel centrado.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(state.isCommandPaletteOpen, isFalse);
  });

  testWidgets(
    'tocar un comando disponible lo ejecuta y cierra el overlay',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final blockId = session.selectedPage!.blocks.first.id;
      final state = await _pumpEditor(tester, session);
      state.debugRequestFocusForBlockForTest(blockId);
      await tester.pump();

      state.showCommandPaletteOverlay();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'summ');
      await tester.pump();

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(state.isCommandPaletteOpen, isFalse);
    },
  );

  testWidgets(
    'toggleCommandPaletteOverlay alterna abierto/cerrado',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final state = await _pumpEditor(tester, session);

      state.toggleCommandPaletteOverlay();
      await tester.pump();
      expect(state.isCommandPaletteOpen, isTrue);

      state.toggleCommandPaletteOverlay();
      await tester.pump();
      expect(state.isCommandPaletteOpen, isFalse);
    },
  );
}
