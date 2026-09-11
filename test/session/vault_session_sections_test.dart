import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_section.dart';
import 'package:folio/session/vault_session.dart';

/// Fase E0B del rediseño UX del editor — mutaciones de `Section` en
/// `VaultSession`. Foco especial en el caso crítico marcado en el plan:
/// qué pasa con `firstBlockId`/`lastBlockId` cuando se borra justo el
/// primer o el último bloque del rango (debe recalcularse, nunca quedar
/// apuntando a un id muerto).
void main() {
  group('createSectionFromRange', () {
    test('crea una sección real cuando el rango resuelve a bloques', () {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final b0 = session.selectedPage!.blocks.first.id;
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: b0,
        block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
      );

      final section = session.createSectionFromRange(
        pageId,
        title: 'Intro',
        range: BlockRange(firstBlockId: b0, lastBlockId: 'b1'),
      );

      expect(section, isNotNull);
      expect(session.selectedPage!.sections, isNotNull);
      expect(session.selectedPage!.sections!.length, 1);
      expect(session.selectedPage!.sections!.first.title, 'Intro');
    });

    test('devuelve null y no crea nada si el rango no resuelve a ningún '
        'bloque (ids inexistentes)', () {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;

      final section = session.createSectionFromRange(
        pageId,
        title: 'Fantasma',
        range: const BlockRange(firstBlockId: 'missing', lastBlockId: 'also'),
      );

      expect(section, isNull);
      expect(session.selectedPage!.sections, isNull);
    });
  });

  group('renameSection / updateSectionMetadata / deleteSection', () {
    late VaultSession session;
    late String pageId;
    late String sectionId;

    setUp(() {
      session = VaultSession();
      session.addPage();
      pageId = session.selectedPageId!;
      final b0 = session.selectedPage!.blocks.first.id;
      final section = session.createSectionFromRange(
        pageId,
        title: 'Original',
        range: BlockRange(firstBlockId: b0, lastBlockId: b0),
      )!;
      sectionId = section.id;
    });

    test('renameSection actualiza el título', () {
      session.renameSection(pageId, sectionId, 'Renombrada');
      expect(session.selectedPage!.sections!.first.title, 'Renombrada');
    });

    test('updateSectionMetadata reemplaza la metadata completa', () {
      session.updateSectionMetadata(
        pageId,
        sectionId,
        const SectionMetadata(state: 'done', priority: 'high'),
      );
      final metadata = session.selectedPage!.sections!.first.metadata;
      expect(metadata.state, 'done');
      expect(metadata.priority, 'high');
    });

    test('deleteSection elimina la sección pero no toca los bloques', () {
      final blocksBefore = session.selectedPage!.blocks.length;
      session.deleteSection(pageId, sectionId);
      expect(session.selectedPage!.sections, isEmpty);
      expect(session.selectedPage!.blocks.length, blocksBefore);
    });
  });

  group('reorderSections', () {
    test('reordena dos secciones', () {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final b0 = session.selectedPage!.blocks.first.id;
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: b0,
        block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
      );
      final s0 = session.createSectionFromRange(
        pageId,
        title: 'Primera',
        range: BlockRange(firstBlockId: b0, lastBlockId: b0),
      )!;
      final s1 = session.createSectionFromRange(
        pageId,
        title: 'Segunda',
        range: const BlockRange(firstBlockId: 'b1', lastBlockId: 'b1'),
      )!;

      expect(
        session.selectedPage!.sections!.map((s) => s.id).toList(),
        [s0.id, s1.id],
      );

      session.reorderSections(pageId, 0, 2);

      expect(
        session.selectedPage!.sections!.map((s) => s.id).toList(),
        [s1.id, s0.id],
      );
    });
  });

  group('reparación de rango tras borrar bloques (caso crítico del plan)', () {
    test(
      'borrar el PRIMER bloque de un rango multi-bloque desplaza '
      'firstBlockId al bloque que ocupa su lugar, sin dejar un id muerto',
      () {
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
        session.createSectionFromRange(
          pageId,
          title: 'Rango',
          range: BlockRange(firstBlockId: b0, lastBlockId: 'b2'),
        );

        session.removeBlockIfMultiple(pageId, b0);

        final section = session.selectedPage!.sections!.first;
        expect(section.range.firstBlockId, isNot(b0));
        expect(section.range.firstBlockId, 'b1');
        expect(section.range.lastBlockId, 'b2');
        // El rango reparado debe seguir resolviendo a bloques reales.
        expect(
          blocksInRange(session.selectedPage!, section.range),
          isNotEmpty,
        );
      },
    );

    test(
      'borrar el ÚLTIMO bloque de un rango multi-bloque desplaza '
      'lastBlockId al bloque anterior, sin dejar un id muerto',
      () {
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
        session.createSectionFromRange(
          pageId,
          title: 'Rango',
          range: BlockRange(firstBlockId: b0, lastBlockId: 'b2'),
        );

        session.removeBlockIfMultiple(pageId, 'b2');

        final section = session.selectedPage!.sections!.first;
        expect(section.range.firstBlockId, b0);
        expect(section.range.lastBlockId, isNot('b2'));
        expect(section.range.lastBlockId, 'b1');
        expect(
          blocksInRange(session.selectedPage!, section.range),
          isNotEmpty,
        );
      },
    );

    test(
      'borrar el único bloque de una sección de un solo bloque colapsa el '
      'rango al bloque anterior superviviente en vez de quedar inválido',
      () {
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
        );
        session.createSectionFromRange(
          pageId,
          title: 'Solo b1',
          range: const BlockRange(firstBlockId: 'b1', lastBlockId: 'b1'),
        );

        session.removeBlockIfMultiple(pageId, 'b1');

        final section = session.selectedPage!.sections!.first;
        expect(section.range.firstBlockId, section.range.lastBlockId);
        expect(section.range.firstBlockId, isNot('b1'));
        expect(section.range.firstBlockId, b0);
      },
    );

    test(
      'mergeBlockUp (Backspace al inicio de un bloque) repara el rango '
      'igual que removeBlockIfMultiple',
      () {
        final session = VaultSession();
        session.addPage();
        final pageId = session.selectedPageId!;
        final b0 = session.selectedPage!.blocks.first.id;
        session.updateBlockText(pageId, b0, 'hola');
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: b0,
          block: FolioBlock(id: 'b1', type: 'paragraph', text: ''),
        );
        session.createSectionFromRange(
          pageId,
          title: 'Solo b1',
          range: const BlockRange(firstBlockId: 'b1', lastBlockId: 'b1'),
        );

        final merged = session.mergeBlockUp(pageId, 'b1');

        expect(merged, isTrue);
        final section = session.selectedPage!.sections!.first;
        expect(section.range.firstBlockId, isNot('b1'));
        expect(section.range.firstBlockId, b0);
      },
    );

    test(
      'removeBlocksIfMultiple (borrado en lote) repara varios rangos a la vez',
      () {
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
        session.insertBlockAfter(
          pageId: pageId,
          afterBlockId: 'b2',
          block: FolioBlock(id: 'b3', type: 'paragraph', text: ''),
        );
        session.createSectionFromRange(
          pageId,
          title: 'Rango',
          range: BlockRange(firstBlockId: b0, lastBlockId: 'b3'),
        );

        session.removeBlocksIfMultiple(pageId, [b0, 'b3']);

        final section = session.selectedPage!.sections!.first;
        expect(section.range.firstBlockId, 'b1');
        expect(section.range.lastBlockId, 'b2');
      },
    );
  });
}
