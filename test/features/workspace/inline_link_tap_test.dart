import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/folio_text_format.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  testWidgets('markdown preview opens internal page links', (tester) async {
    String? openedPageId;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FolioMarkdownPreview(
              data: '[Abrir destino](folio://open/target-page)',
              styleSheet: folioMarkdownStyleSheet(
                context,
                Theme.of(context).textTheme.bodyMedium!,
                Theme.of(context).colorScheme,
              ),
              onFolioPageLink: (pageId) {
                openedPageId = pageId;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir destino').first);
    await tester.pumpAndSettle();

    expect(openedPageId, 'target-page');
  });

  testWidgets(
    'tapping an inline page link opens it instead of entering edit mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final session = VaultSession();
      final appSettings = AppSettings();

      session.addPage();
      final targetPageId = session.selectedPageId!;

      session.addPage();
      final sourcePageId = session.selectedPageId!;
      session.updateBlockText(
        sourcePageId,
        '${sourcePageId}_b0',
        '[Abrir destino](folio://open/$targetPageId)',
      );
      session.selectPage(sourcePageId);

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

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(session.selectedPageId, sourcePageId);

      await tester.tap(find.text('Abrir destino').first);
      await tester.pumpAndSettle();

      expect(session.selectedPageId, targetPageId);
    },
  );

  testWidgets('markdown preview opens external links via callback', (
    tester,
  ) async {
    String? openedHref;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FolioMarkdownPreview(
              data: '[Abrir web](https://example.com)',
              styleSheet: folioMarkdownStyleSheet(
                context,
                const TextStyle(fontSize: 14),
                const ColorScheme.light(),
              ),
              onTapLink: (text, href, title) {
                openedHref = href;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir web').first);
    await tester.pumpAndSettle();

    expect(openedHref, 'https://example.com');
  });
}
