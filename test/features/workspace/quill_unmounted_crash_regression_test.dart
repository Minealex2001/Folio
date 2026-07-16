import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('clicking WYSIWYG toolbar does not crash after rebuilds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    final appSettings = AppSettings();

    session.addPage();
    final pageId = session.selectedPageId!;

    // Texto simple para tener un bloque WYSIWYG.
    session.updateBlockText(pageId, '${pageId}_b0', 'hola mundo');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BlockEditor(session: session, appSettings: appSettings)),
      ),
    );
    await tester.pumpAndSettle();

    final editorState = tester.state<BlockEditorState>(find.byType(BlockEditor));
    editorState.debugShowFormatToolbarOverlayForTest();
    await tester.pumpAndSettle();

    final boldIcon = find.descendant(
      of: find.byType(Overlay),
      matching: find.byIcon(Icons.format_bold_rounded),
    );
    expect(boldIcon, findsOneWidget);
    await tester.tap(boldIcon);
    await tester.pump();

    // Fuerza rebuild por notifyListeners típico tras mutación.
    session.notifyListeners();
    await tester.pumpAndSettle();

    // Si hay crash tipo "widget unmounted" aparecerá como excepción en test.
    expect(tester.takeException(), isNull);
  });
}

