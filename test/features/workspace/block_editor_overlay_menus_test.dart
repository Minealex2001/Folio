import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/block_editor_support_widgets.dart';
import 'package:folio/features/workspace/editor/folio_text_format.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Blocking prerequisite for the v0.8.0 Phase C extraction (format toolbar /
/// slash menu / mention menu controllers): none of the existing block
/// editor regression tests exercised these overlays showing at all --
/// they cover caret/cursor position, not overlay visibility. These tests
/// establish that baseline before block_editor_state.dart's overlay
/// management is touched.
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

void main() {
  testWidgets('format toolbar overlay shows when a text selection is forced', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    final appSettings = AppSettings();
    session.addPage();
    final blockId = session.selectedPage!.blocks.first.id;
    session.updateBlockText(session.selectedPageId!, blockId, 'hello world');

    final state = await _pumpEditor(tester, session, appSettings);

    // 'paragraph' is a stylable (Quill) block type, so the overlay renders
    // FolioQuillFormatToolbar rather than the plain-controller variant.
    expect(find.byType(FolioQuillFormatToolbar), findsNothing);

    state.debugShowFormatToolbarOverlayForTest();
    await tester.pump();

    expect(find.byType(FolioQuillFormatToolbar), findsOneWidget);
  });

  testWidgets('typing "/" opens the inline slash command menu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    final appSettings = AppSettings();
    session.addPage();
    final blockId = session.selectedPage!.blocks.first.id;

    final state = await _pumpEditor(tester, session, appSettings);

    expect(find.byType(BlockEditorInlineSlashList), findsNothing);

    state.debugSimulateQuillTypingForTest(blockId, '/');
    await tester.pump();
    await tester.pump();

    expect(find.byType(BlockEditorInlineSlashList), findsOneWidget);
  });

  testWidgets('typing "@" opens the inline mention menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    final appSettings = AppSettings();
    session.addPage();
    // A second page gives the mention catalog something to match against.
    session.addPage();
    final blockId = session.selectedPage!.blocks.first.id;

    final state = await _pumpEditor(tester, session, appSettings);

    expect(find.byType(BlockEditorInlineMentionList), findsNothing);

    state.debugSimulateQuillTypingForTest(blockId, '@');
    await tester.pump();
    await tester.pump();

    expect(find.byType(BlockEditorInlineMentionList), findsOneWidget);
  });
}
