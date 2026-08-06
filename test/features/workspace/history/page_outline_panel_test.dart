import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/history/page_outline_panel.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_section.dart';
import 'package:folio/session/vault_session.dart';

/// Fase E4 del rediseño UX del editor — el panel de outline (ya existía,
/// ya conectado vía `AppSettings.workspacePageOutlineVisible`) pasa de una
/// lista plana de headings a una jerarquía mixta Sección→Heading. Un
/// documento sin secciones (el caso común) debe comportarse exactamente
/// igual que antes.
Future<void> _pumpPanel(
  WidgetTester tester,
  VaultSession session,
  GlobalKey<BlockEditorState> key,
) async {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PageOutlinePanel(
          page: session.selectedPage!,
          session: session,
          scheme: scheme,
          blockEditorKey: key,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('sin sections — comportamiento plano de siempre', () {
    testWidgets('lista los headings en orden, sin cabeceras de sección', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final b0 = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, b0, 'h1');
      session.updateBlockText(pageId, b0, 'Título uno');
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: b0,
        block: FolioBlock(id: 'h2a', type: 'h2', text: 'Sub uno'),
      );

      await _pumpPanel(tester, session, GlobalKey<BlockEditorState>());

      expect(find.text('Título uno'), findsOneWidget);
      expect(find.text('Sub uno'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    });

    testWidgets('página sin headings muestra el estado vacío', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();

      await _pumpPanel(tester, session, GlobalKey<BlockEditorState>());

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PageOutlinePanel)),
      );
      expect(find.text(l10n.pageOutlineEmpty), findsOneWidget);
    });
  });

  group('con sections reales — jerarquía mixta', () {
    testWidgets(
      'muestra la cabecera de sección + sus headings anidados debajo',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.changeBlockType(pageId, b0, 'h1');
        session.updateBlockText(pageId, b0, 'Dentro de sección');
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
        );
        session.createSectionFromRange(
          pageId,
          title: 'Mi sección',
          range: BlockRange(firstBlockId: b0, lastBlockId: 'b1'),
        );

        await _pumpPanel(tester, session, GlobalKey<BlockEditorState>());

        expect(find.text('Mi sección'), findsOneWidget);
        expect(find.text('Dentro de sección'), findsOneWidget);
        expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'headings fuera de cualquier rango de sección siguen apareciendo '
      'como nivel superior',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.changeBlockType(pageId, b0, 'h1');
        session.updateBlockText(pageId, b0, 'En sección');
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'h2fuera', type: 'h2', text: 'Fuera de sección'),
        );
        session.createSectionFromRange(
          pageId,
          title: 'Solo b0',
          range: BlockRange(firstBlockId: b0, lastBlockId: b0),
        );

        await _pumpPanel(tester, session, GlobalKey<BlockEditorState>());

        expect(find.text('Solo b0'), findsOneWidget);
        expect(find.text('En sección'), findsOneWidget);
        expect(find.text('Fuera de sección'), findsOneWidget);
      },
    );

    testWidgets(
      'una sección colapsada oculta sus headings anidados, pero la '
      'cabecera sigue visible',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.changeBlockType(pageId, b0, 'h1');
        session.updateBlockText(pageId, b0, 'Heading oculto');
        session.createSectionFromRange(
          pageId,
          title: 'Colapsada',
          range: BlockRange(firstBlockId: b0, lastBlockId: b0),
          metadata: const SectionMetadata(collapsed: true),
        );

        await _pumpPanel(tester, session, GlobalKey<BlockEditorState>());

        expect(find.text('Colapsada'), findsOneWidget);
        expect(find.text('Heading oculto'), findsNothing);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'tocar el chevron de una sección alterna collapsed vía '
      'VaultSession.updateSectionMetadata',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.changeBlockType(pageId, b0, 'h1');
        session.updateBlockText(pageId, b0, 'Heading');
        session.createSectionFromRange(
          pageId,
          title: 'Toggle',
          range: BlockRange(firstBlockId: b0, lastBlockId: b0),
        );

        await _pumpPanel(tester, session, GlobalKey<BlockEditorState>());
        expect(session.selectedPage!.sections!.first.metadata.collapsed, isFalse);

        await tester.tap(find.byIcon(Icons.expand_more_rounded));
        await tester.pump();

        expect(session.selectedPage!.sections!.first.metadata.collapsed, isTrue);
      },
    );
  });
}
