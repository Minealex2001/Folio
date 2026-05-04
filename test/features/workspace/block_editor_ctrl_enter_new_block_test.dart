import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('forced new block works when Enter creates block is off', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    final appSettings = AppSettings();
    await appSettings.setEnterCreatesNewBlock(false);

    session.addPage();
    final pageId = session.selectedPageId!;
    session.updateBlockText(pageId, '${pageId}_b0', 'hello');

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

    expect(session.pages.first.blocks.length, 1);

    await tester.tap(find.textContaining('hello').first);
    await tester.pumpAndSettle();

    final state = tester.state<BlockEditorState>(find.byType(BlockEditor));
    expect(state.debugInvokeTryInsertNewBlockForTest(force: true), isTrue);
    await tester.pumpAndSettle();

    // Puede haber un bloque centinela al final del editor. El cursor puede no
    // estar al final del texto en el harness; lo importante es no perder "hello".
    final blocks = session.pages.first.blocks;
    expect(blocks.length, greaterThanOrEqualTo(2));
    expect((blocks[0].text + blocks[1].text).replaceAll(RegExp(r'[\r\n]+$'), ''), 'hello');
    expect(blocks[0].type, 'paragraph');
    expect(blocks[1].type, 'paragraph');
  });
}
