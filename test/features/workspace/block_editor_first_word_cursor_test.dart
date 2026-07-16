import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('flush Quill conserva el caret tras la primera palabra', (
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
    state.debugSimulateQuillTypingForTest(blockId, 'hola');
    expect(state.debugQuillRawCaretForTest(blockId), 4);
    expect(session.pages.first.blocks.first.text, contains('hola'));
  });
}
