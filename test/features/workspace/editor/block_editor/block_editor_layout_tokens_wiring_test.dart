import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/config/models/editor_layout_tokens.dart';
import 'package:folio/config/models/token_ref.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/block_editor/block_row_chrome.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase A1 del rediseño UX del editor: `EditorLayoutTokens`
/// (`LayoutConfig.editor`) ya existía y estaba testeado, pero no se leía en
/// ningún sitio del editor real (`BlockEditor.editorLayoutTokens` no
/// existía). Estos tests prueban la conexión real, no solo el modelo.
Future<void> _pump(
  WidgetTester tester,
  VaultSession session,
  AppSettings appSettings, {
  EditorLayoutTokens? editorLayoutTokens,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlockEditor(
          session: session,
          appSettings: appSettings,
          editorLayoutTokens: editorLayoutTokens,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'omitting editorLayoutTokens reproduces the default 2.0 block spacing '
    '(zero-regression parity)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      final appSettings = AppSettings();
      session.addPage();

      await _pump(tester, session, appSettings);

      final chrome = tester.widget<BlockRowChrome>(
        find.byType(BlockRowChrome).first,
      );
      expect(chrome.verticalPadding, 2.0);
    },
  );

  testWidgets(
    'a non-default blockSpacing literal in editorLayoutTokens changes the '
    'rendered block row spacing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      final appSettings = AppSettings();
      session.addPage();

      await _pump(
        tester,
        session,
        appSettings,
        editorLayoutTokens: const EditorLayoutTokens(
          blockSpacing: TokenRef<double>.literal(14.0),
        ),
      );

      final chrome = tester.widget<BlockRowChrome>(
        find.byType(BlockRowChrome).first,
      );
      expect(chrome.verticalPadding, 14.0);
    },
  );

  testWidgets(
    'a blockSpacing TokenRef.ref (unresolved reference) falls back to the '
    'default instead of throwing or resolving to a bogus value',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      final appSettings = AppSettings();
      session.addPage();

      await _pump(
        tester,
        session,
        appSettings,
        editorLayoutTokens: const EditorLayoutTokens(
          blockSpacing: TokenRef<double>.ref('space.md'),
        ),
      );

      final chrome = tester.widget<BlockRowChrome>(
        find.byType(BlockRowChrome).first,
      );
      expect(chrome.verticalPadding, 2.0);
    },
  );

  testWidgets(
    'a callout block picks up LayoutConfig.editor.calloutStyle (minimal '
    'preset disables the border) — proves the Fase A2 wiring, not just the '
    'already-tested pure preset functions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      final appSettings = AppSettings();
      session.addPage();
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(session.selectedPageId!, blockId, 'callout');

      await _pump(
        tester,
        session,
        appSettings,
        editorLayoutTokens: const EditorLayoutTokens(calloutStyle: 'minimal'),
      );

      // El contenedor del callout es el único Container con borderRadius de
      // 12 y decoración con borde — se localiza por forma, no por posición
      // en el árbol, ya que el chrome compartido envuelve varios Container.
      final calloutContainers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) {
            final decoration = c.decoration;
            return decoration is BoxDecoration &&
                decoration.borderRadius == BorderRadius.circular(12) &&
                decoration.border != null;
          })
          .toList();
      expect(calloutContainers, hasLength(1));
      final decoration = calloutContainers.single.decoration as BoxDecoration;
      final borderSide = decoration.border!.top;
      // kCalloutStyleMinimal.showBorder == false -> totalmente transparente.
      expect(borderSide.color, Colors.transparent);
    },
  );
}
