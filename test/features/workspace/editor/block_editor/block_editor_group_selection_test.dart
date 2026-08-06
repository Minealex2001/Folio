import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_columns_data.dart';
import 'package:folio/session/vault_session.dart';

/// Fases E1/E2/E3 del rediseño UX del editor — "Agrupar" (Primary Surface
/// de convertir-a-columnas y agrupar-en-sección) en la barra de selección
/// múltiple ya existente. Se testea a través de los debug hooks (mismo
/// patrón que el resto del editor) más un test de integración de la barra
/// real.
Future<BlockEditorState> _pumpEditor(
  WidgetTester tester,
  VaultSession session,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlockEditor(session: session, appSettings: AppSettings()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<BlockEditorState>(find.byType(BlockEditor));
}

void main() {
  group('_isContiguousSelection', () {
    testWidgets('menos de 2 bloques nunca es contigua', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final b0 = session.selectedPage!.blocks.first.id;
      final state = await _pumpEditor(tester, session);

      state.debugSelectBlocksForTest([b0]);
      expect(
        state.debugIsContiguousSelectionForTest(session.selectedPage!),
        isFalse,
      );
    });

    testWidgets('bloques consecutivos son contiguos', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final b0 = session.selectedPage!.blocks.first.id;
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: b0,
        block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
      );
      final state = await _pumpEditor(tester, session);

      state.debugSelectBlocksForTest([b0, 'b1']);
      expect(
        state.debugIsContiguousSelectionForTest(session.selectedPage!),
        isTrue,
      );
    });

    testWidgets('bloques no consecutivos NO son contiguos', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final b0 = session.selectedPage!.blocks.first.id;
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: b0,
        block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
      );
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: 'b1',
        block: FolioBlock(id: 'b2', type: 'paragraph', text: ''),
      );
      final state = await _pumpEditor(tester, session);

      state.debugSelectBlocksForTest([b0, 'b2']); // b1 queda fuera
      expect(
        state.debugIsContiguousSelectionForTest(session.selectedPage!),
        isFalse,
      );
    });
  });

  group('_convertSelectionToColumns (Fase E2)', () {
    testWidgets(
      'convierte una selección contigua de 2 bloques en column_list de 2 '
      'columnas, y retira los bloques originales de su posición plana',
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
        final state = await _pumpEditor(tester, session);
        state.debugSelectBlocksForTest([b0, 'b1']);

        state.debugConvertSelectionToColumnsForTest(
          session.selectedPage!,
          2,
        );

        final blocks = session.selectedPage!.blocks;
        expect(blocks.where((b) => b.id == b0), isEmpty);
        expect(blocks.where((b) => b.id == 'b1'), isEmpty);
        final columnsBlock = blocks.firstWhere((b) => b.type == 'column_list');
        final data = FolioColumnsData.tryParse(columnsBlock.text)!;
        expect(data.columns.length, 2);
        expect(data.columns[0].blocks.single.text, 'uno');
        expect(data.columns[1].blocks.single.text, 'dos');
      },
    );

    testWidgets('no hace nada si la selección no es contigua', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final b0 = session.selectedPage!.blocks.first.id;
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: b0,
        block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
      );
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: 'b1',
        block: FolioBlock(id: 'b2', type: 'paragraph', text: ''),
      );
      final state = await _pumpEditor(tester, session);
      state.debugSelectBlocksForTest([b0, 'b2']);

      final before = session.selectedPage!.blocks.length;
      state.debugConvertSelectionToColumnsForTest(session.selectedPage!, 2);

      expect(session.selectedPage!.blocks.length, before);
      expect(
        session.selectedPage!.blocks.any((b) => b.type == 'column_list'),
        isFalse,
      );
    });
  });

  group('_groupSelectionIntoSection (Fase E3)', () {
    testWidgets(
      'crea una Section real cubriendo el rango seleccionado, sin tocar '
      'los bloques',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
        );
        final state = await _pumpEditor(tester, session);
        final blocksBefore = session.selectedPage!.blocks.length;
        state.debugSelectBlocksForTest([b0, 'b1']);

        state.debugGroupSelectionIntoSectionForTest(
          session.selectedPage!,
          title: 'Mi sección',
        );

        expect(session.selectedPage!.blocks.length, blocksBefore);
        final sections = session.selectedPage!.sections;
        expect(sections, isNotNull);
        expect(sections!.single.title, 'Mi sección');
        expect(sections.single.range.firstBlockId, b0);
        expect(sections.single.range.lastBlockId, 'b1');
      },
    );
  });

  group('"Desagrupar columnas" (menú ⋮ del bloque, pedido junto con '
      '"Agrupar")', () {
    testWidgets(
      'convierte primero a columnas y luego desagrupa, recuperando los '
      'bloques planos',
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
        final state = await _pumpEditor(tester, session);
        state.debugSelectBlocksForTest([b0, 'b1']);
        state.debugConvertSelectionToColumnsForTest(session.selectedPage!, 2);
        await tester.pump();

        final columnsBlock = session.selectedPage!.blocks.firstWhere(
          (b) => b.type == 'column_list',
        );
        final index = session.selectedPage!.blocks.indexOf(columnsBlock);
        state.debugInvokeBlockMenuActionForTest(
          'ungroup_columns',
          session.selectedPage!,
          columnsBlock,
          index,
        );

        final blocks = session.selectedPage!.blocks;
        expect(blocks.any((b) => b.type == 'column_list'), isFalse);
        expect(blocks.map((b) => b.text.trim()), containsAll(['uno', 'dos']));
      },
    );
  });

  group('barra de selección real (integración)', () {
    testWidgets(
      'el botón "Agrupar" -> "2 columnas" convierte la selección visible',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
        );
        final state = await _pumpEditor(tester, session);
        state.debugSelectBlocksForTest([b0, 'b1']);
        await tester.pump();

        final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
        expect(find.text(l10n.blockEditorGroupAction), findsOneWidget);

        await tester.tap(find.text(l10n.blockEditorGroupAction));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.blockEditorGroupAsColumns2));
        await tester.pumpAndSettle();

        expect(
          session.selectedPage!.blocks.any((b) => b.type == 'column_list'),
          isTrue,
        );
      },
    );
  });
}
