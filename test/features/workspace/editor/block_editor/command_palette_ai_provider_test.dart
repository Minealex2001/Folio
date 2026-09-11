import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/ai/ai_slash_intent.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase C1 del rediseño UX del editor — el proveedor de comandos de IA del
/// Command Palette no es una lista falsa: reutiliza el mismo pipeline de
/// ejecución que ya usan el slash menu y la barra de formato
/// (`_dispatchAiSlashFromToolbar` → `widget.onAiSlashCommand`).
Future<BlockEditorState> _pumpEditor(
  WidgetTester tester,
  VaultSession session,
  AppSettings appSettings, {
  required Future<void> Function(FolioAiSlashParams) onAiSlashCommand,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlockEditor(
          session: session,
          appSettings: appSettings,
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
    'devuelve los 9 comandos de IA, todos no disponibles sin bloque enfocado',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final state = await _pumpEditor(
        tester,
        session,
        AppSettings(),
        onAiSlashCommand: (_) async {},
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
      final commands = state.debugAiPaletteCommandsForTest(l10n);

      expect(commands.length, 9);
      expect(commands.every((c) => !c.isCurrentlyAvailable), isTrue);
    },
  );

  testWidgets(
    'con un bloque enfocado, execute() invoca el mismo pipeline de IA que '
    'el slash menu — mismo intent, mismo pageId/blockId',
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
        AppSettings(),
        onAiSlashCommand: (params) async {
          captured = params;
        },
      );
      state.debugRequestFocusForBlockForTest(blockId);
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
      final commands = state.debugAiPaletteCommandsForTest(l10n);
      final summarize = commands.firstWhere((c) => c.id == 'cmd_ai_summarize');

      expect(summarize.isCurrentlyAvailable, isTrue);
      summarize.execute();
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.intent, AiSlashIntent.summarize);
      expect(captured!.pageId, pageId);
      expect(captured!.blockId, blockId);
    },
  );
}
