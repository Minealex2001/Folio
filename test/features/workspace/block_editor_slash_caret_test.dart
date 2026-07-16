import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('el caret permanece tras "/" cuando se abre el menú de bloques', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    final appSettings = AppSettings();
    await appSettings.setEnterCreatesNewBlock(false);

    session.addPage();
    final blockId = session.selectedPage!.blocks.first.id;

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

    final state = tester.state<BlockEditorState>(find.byType(BlockEditor));
    state.debugSimulateQuillTypingForTest(blockId, '/');
    expect(
      state.debugQuillRawCaretForTest(blockId),
      1,
      reason: 'el caret debe quedar justo después de "/" antes de repintar',
    );

    // Deja que Flutter procese el/los setState() que abren el menú "/" y
    // reconstruya la fila con el panel flotante añadido como hermano del
    // editor (esto es lo que dispara el reparent que puede perder el caret).
    await tester.pump();

    expect(
      state.debugQuillRawCaretForTest(blockId),
      1,
      reason:
          'el caret no debe saltar a 0 al reconstruirse la fila con el menú "/" abierto',
    );
    expect(session.selectedPage!.blocks.first.text.trimRight(), '/');
  });
}
