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

    // Entra en edición tocando el texto.
    await tester.tap(find.textContaining('hola').first);
    await tester.pumpAndSettle();

    // Pulsa negrita (IconButton). En desktop lo activamos en pointerDown.
    await tester.tap(find.byIcon(Icons.format_bold_rounded).first);
    await tester.pump();

    // Fuerza rebuild por notifyListeners típico tras mutación.
    session.notifyListeners();
    await tester.pumpAndSettle();

    // Si hay crash tipo "widget unmounted" aparecerá como excepción en test.
    expect(tester.takeException(), isNull);
  });
}

