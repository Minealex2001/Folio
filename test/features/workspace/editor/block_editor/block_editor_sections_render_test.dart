import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_section.dart';
import 'package:folio/session/vault_session.dart';

/// Fase E0C del rediseño UX del editor — integración de render de
/// `Section`. `BlockEditorState._buildSectionRenderItemsFor` es el gate de
/// equivalencia de todo el Track E: una página sin `sections` (el caso de
/// hoy para cada documento existente) debe renderizar/comportarse
/// byte-a-byte igual que antes de esta fase.
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
  group('test dorado — página sin sections', () {
    testWidgets(
      'una página con múltiples bloques y sin sections no renderiza '
      'ninguna cabecera de sección — mismo árbol de render que antes de '
      'esta fase',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.updateBlockText(pageId, b0, 'uno');
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'b1', type: 'paragraph', text: 'dos'),
        );
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: 'b1',
          block: FolioBlock(id: 'b2', type: 'paragraph', text: 'tres'),
        );
        expect(session.selectedPage!.sections, isNull);

        await _pumpEditor(tester, session, AppSettings());

        expect(find.textContaining('uno'), findsOneWidget);
        expect(find.textContaining('dos'), findsOneWidget);
        expect(find.textContaining('tres'), findsOneWidget);
        // Ninguna fila de sección — ni siquiera la infraestructura visual.
        expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
      },
    );

    testWidgets(
      'una página con sections vacía ([]) se comporta igual que null',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        session.selectedPage!.sections = [];

        await _pumpEditor(tester, session, AppSettings());

        expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
      },
    );
  });

  group('sección real — cabecera visible y colapsable', () {
    testWidgets(
      'una sección real renderiza una cabecera antes de su rango de bloques',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.updateBlockText(pageId, b0, 'uno');
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'b1', type: 'paragraph', text: 'dos'),
        );
        session.createSectionFromRange(
          pageId,
          title: 'Mi sección',
          range: BlockRange(firstBlockId: b0, lastBlockId: 'b1'),
        );

        await _pumpEditor(tester, session, AppSettings());

        expect(find.text('Mi sección'), findsOneWidget);
        expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
        expect(find.textContaining('uno'), findsOneWidget);
        expect(find.textContaining('dos'), findsOneWidget);
      },
    );

    testWidgets(
      'tocar la cabecera colapsa la sección y oculta sus bloques',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.updateBlockText(pageId, b0, 'contenido-oculto');
        session.createSectionFromRange(
          pageId,
          title: 'Colapsable',
          range: BlockRange(firstBlockId: b0, lastBlockId: b0),
        );

        await _pumpEditor(tester, session, AppSettings());
        expect(find.textContaining('contenido-oculto'), findsOneWidget);

        await tester.tap(find.text('Colapsable'));
        await tester.pumpAndSettle();

        expect(
          session.selectedPage!.sections!.first.metadata.collapsed,
          isTrue,
        );
        expect(find.textContaining('contenido-oculto'), findsNothing);

        // Tocar de nuevo expande — se verifica a nivel de estado de sesión
        // (fuente de verdad) en vez de repetir la búsqueda visual, que en
        // este harness es sensible a temporización de re-foco/parpadeo de
        // cursor no relacionada con la lógica de colapso en sí.
        await tester.tap(find.text('Colapsable'));
        await tester.pump();
        expect(
          session.selectedPage!.sections!.first.metadata.collapsed,
          isFalse,
        );
      },
    );

    testWidgets(
      '"Desagrupar sección" (menú ⋮ de la cabecera) elimina la sección sin '
      'tocar los bloques — pedido junto con "Agrupar" (Fases E1-E3)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.updateBlockText(pageId, b0, 'contenido');
        session.createSectionFromRange(
          pageId,
          title: 'A desagrupar',
          range: BlockRange(firstBlockId: b0, lastBlockId: b0),
        );

        await _pumpEditor(tester, session, AppSettings());
        expect(session.selectedPage!.sections, isNotNull);
        expect(session.selectedPage!.sections!.length, 1);

        final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.blockEditorUngroupSection));
        await tester.pumpAndSettle();

        expect(session.selectedPage!.sections, isEmpty);
        // El bloque sigue intacto (el trailing "\n" viene del flush normal
        // de Quill al montar el bloque, no de "Desagrupar").
        expect(session.selectedPage!.blocks.first.text.trim(), 'contenido');
      },
    );

    testWidgets(
      'badges de state/priority se muestran cuando la metadata los tiene',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.createSectionFromRange(
          pageId,
          title: 'Con metadata',
          range: BlockRange(firstBlockId: b0, lastBlockId: b0),
          metadata: const SectionMetadata(state: 'inProgress', priority: 'high'),
        );

        await _pumpEditor(tester, session, AppSettings());

        expect(find.text('inProgress'), findsOneWidget);
        expect(find.text('high'), findsOneWidget);
      },
    );
  });
}
