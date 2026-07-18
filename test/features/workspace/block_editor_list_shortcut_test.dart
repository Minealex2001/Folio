import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('Quill: "- " en párrafo vacío convierte a bullet', (tester) async {
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
    state.debugSimulateQuillTypingForTest(blockId, '- ');
    await tester.pump();

    final block = session.selectedPage!.blocks.firstWhere((b) => b.id == blockId);
    expect(block.type, 'bullet');
    expect(block.text, isEmpty);
  });

  testWidgets(
    'Quill: "- " en línea nueva parte el párrafo y crea bullet',
    (tester) async {
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
      state.debugSimulateQuillTypingForTest(blockId, 'hola\n- ');
      await tester.pump();

      final blocks = session.selectedPage!.blocks;
      final paragraph = blocks.firstWhere((b) => b.id == blockId);
      expect(paragraph.type, 'paragraph');
      expect(paragraph.text.trimRight(), 'hola');

      final bullet = blocks.where((b) => b.type == 'bullet').toList();
      expect(bullet, isNotEmpty);
      expect(bullet.first.text, isEmpty);

      final paraIdx = blocks.indexWhere((b) => b.id == blockId);
      final bulletIdx = blocks.indexWhere((b) => b.id == bullet.first.id);
      expect(bulletIdx, paraIdx + 1);
    },
  );
}
