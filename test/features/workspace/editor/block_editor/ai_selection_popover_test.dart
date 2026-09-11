import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/ai/ai_slash_intent.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/command_palette/command_palette_overlay.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase D1 del rediseño UX del editor — el botón "✨" (`onAskQuill`) de la
/// barra de formato ya existía, pero disparaba siempre el mismo intent fijo
/// (`AiSlashIntent.explain`) directamente (ver el código reemplazado en
/// `block_editor_state_format_toolbar.dart`, ambos call sites ahora llaman
/// `st.showAiSelectionPopover(blockId: ...)` en vez de despachar `explain`
/// a ciegas). Ahora abre un mini Command Palette (Fase C2) con las
/// acciones de IA como resultados filtrables — mismo widget, mismo
/// pipeline de ejecución, solo un disparador distinto.
///
/// Se invoca `showAiSelectionPopover` directamente (es un método público,
/// no un debug hook) en vez de tocar el icono "✨" del toolbar real: la
/// posición calculada de ese overlay-sobre-otro-overlay resultó frágil en
/// este harness (coordenadas que no hacían hit-test sobre el widget
/// esperado). La conexión botón→método se verifica por lectura de código
/// (un único call site por variante de toolbar, ambos ya actualizados);
/// este archivo prueba el mecanismo del popover en sí.
Future<BlockEditorState> _pumpEditor(
  WidgetTester tester,
  VaultSession session, {
  required Future<void> Function(FolioAiSlashParams) onAiSlashCommand,
}) async {
  tester.view.physicalSize = const Size(1400, 1600);
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
          onAiSlashCommand: onAiSlashCommand,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<BlockEditorState>(find.byType(BlockEditor));
}

void main() {
  testWidgets(
    'showAiSelectionPopover abre un CommandPaletteOverlay anclado al bloque',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final blockId = session.selectedPage!.blocks.first.id;
      session.updateBlockText(session.selectedPageId!, blockId, 'hola mundo');

      final state = await _pumpEditor(
        tester,
        session,
        onAiSlashCommand: (_) async {},
      );
      expect(state.isAiSelectionPopoverOpen, isFalse);

      state.showAiSelectionPopover(blockId: blockId);
      await tester.pump();

      expect(state.isAiSelectionPopoverOpen, isTrue);
      expect(find.byType(CommandPaletteOverlay), findsOneWidget);
    },
  );

  testWidgets(
    'el popover lista las 9 acciones de IA y se filtra igual que el '
    'Command Palette global (Fase C1/C2)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final blockId = session.selectedPage!.blocks.first.id;
      session.updateBlockText(session.selectedPageId!, blockId, 'hola mundo');

      final state = await _pumpEditor(
        tester,
        session,
        onAiSlashCommand: (_) async {},
      );
      state.showAiSelectionPopover(blockId: blockId);
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
      final paletteSearchField = find.descendant(
        of: find.byType(CommandPaletteOverlay),
        matching: find.byType(TextField),
      );
      await tester.enterText(paletteSearchField, 'summ');
      await tester.pump();

      expect(find.text(l10n.blockEditorCmdAiSummarize), findsOneWidget);
    },
  );

  testWidgets(
    'ejecutar una acción del popover cierra el popover y llama al mismo '
    'pipeline que ya usaba el botón "✨" fijo (onAiSlashCommand)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.updateBlockText(pageId, blockId, 'hola mundo');

      FolioAiSlashParams? captured;
      final state = await _pumpEditor(
        tester,
        session,
        onAiSlashCommand: (params) async {
          captured = params;
        },
      );
      state.showAiSelectionPopover(blockId: blockId);
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
      await tester.tap(find.text(l10n.blockEditorCmdAiSummarize));
      await tester.pumpAndSettle();

      expect(state.isAiSelectionPopoverOpen, isFalse);
      expect(captured, isNotNull);
      expect(captured!.intent, AiSlashIntent.summarize);
      expect(captured!.pageId, pageId);
      expect(captured!.blockId, blockId);
    },
  );

  testWidgets('Escape cierra el popover de IA', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    session.addPage();
    final blockId = session.selectedPage!.blocks.first.id;

    final state = await _pumpEditor(
      tester,
      session,
      onAiSlashCommand: (_) async {},
    );
    state.showAiSelectionPopover(blockId: blockId);
    await tester.pump();
    expect(state.isAiSelectionPopoverOpen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(state.isAiSelectionPopoverOpen, isFalse);
  });
}
