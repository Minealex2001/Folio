import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/folio_section.dart';

/// Fase E0A del rediseño UX del editor — modelo `Section`/`BlockRange`/
/// `SectionMetadata` (capa estructural, NO un tipo de bloque nuevo) y el
/// helper puro `blocksInRange`. Tests puros, sin widget pump, mismo patrón
/// que el resto de `test/models/*_test.dart`.
void main() {
  group('BlockRange', () {
    test('round-trip de serialización', () {
      const range = BlockRange(firstBlockId: 'a', lastBlockId: 'c');
      final decoded = BlockRange.fromJson(range.toJson());
      expect(decoded, range);
    });

    test('igualdad estructural', () {
      const a = BlockRange(firstBlockId: 'x', lastBlockId: 'y');
      const b = BlockRange(firstBlockId: 'x', lastBlockId: 'y');
      const c = BlockRange(firstBlockId: 'x', lastBlockId: 'z');
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('SectionMetadata', () {
    test('round-trip de serialización con todos los campos', () {
      const metadata = SectionMetadata(
        icon: '📋',
        color: 0xFFFF0000,
        state: 'inProgress',
        priority: 'high',
        tags: ['sprint', 'q1'],
        assignee: 'ale',
        progress: 0.5,
        collapsed: true,
      );
      final decoded = SectionMetadata.fromJson(metadata.toJson());
      expect(decoded.icon, metadata.icon);
      expect(decoded.color, metadata.color);
      expect(decoded.state, metadata.state);
      expect(decoded.priority, metadata.priority);
      expect(decoded.tags, metadata.tags);
      expect(decoded.assignee, metadata.assignee);
      expect(decoded.progress, metadata.progress);
      expect(decoded.collapsed, metadata.collapsed);
    });

    test('default vacío no serializa ninguna clave (payload mínimo)', () {
      const metadata = SectionMetadata();
      expect(metadata.toJson(), isEmpty);
    });

    test('copyWith reemplaza solo los campos indicados', () {
      const base = SectionMetadata(state: 'notStarted', priority: 'low');
      final updated = base.copyWith(state: 'done');
      expect(updated.state, 'done');
      expect(updated.priority, 'low');
    });

    test('copyWith con clearX limpia el campo a null', () {
      const base = SectionMetadata(assignee: 'ale');
      final updated = base.copyWith(clearAssignee: true);
      expect(updated.assignee, isNull);
    });
  });

  group('Section', () {
    test('round-trip de serialización', () {
      final section = Section(
        id: 's1',
        title: 'Sprint 1',
        range: const BlockRange(firstBlockId: 'b0', lastBlockId: 'b2'),
        metadata: const SectionMetadata(state: 'inProgress'),
      );
      final decoded = Section.fromJson(section.toJson());
      expect(decoded.id, 's1');
      expect(decoded.title, 'Sprint 1');
      expect(decoded.range, section.range);
      expect(decoded.metadata.state, 'inProgress');
    });
  });

  group('FolioPage.sections — aditivo nullable, sin regresión', () {
    test('una página sin sections serializa/deserializa sin la clave', () {
      final page = FolioPage(id: 'p1', title: 'Test');
      final json = page.toJson();
      expect(json.containsKey('sections'), isFalse);

      final decoded = FolioPage.fromJson(json);
      expect(decoded.sections, isNull);
    });

    test('una página con sections hace round-trip completo', () {
      final page = FolioPage(
        id: 'p1',
        title: 'Test',
        blocks: [
          FolioBlock(id: 'b0', type: 'h1', text: 'Intro'),
          FolioBlock(id: 'b1', type: 'paragraph', text: 'hola'),
          FolioBlock(id: 'b2', type: 'paragraph', text: 'mundo'),
        ],
        sections: [
          Section(
            id: 's1',
            title: 'Intro',
            range: const BlockRange(firstBlockId: 'b0', lastBlockId: 'b2'),
          ),
        ],
      );
      final decoded = FolioPage.fromJson(page.toJson());
      expect(decoded.sections, isNotNull);
      expect(decoded.sections!.length, 1);
      expect(decoded.sections!.first.id, 's1');
      expect(
        decoded.sections!.first.range,
        const BlockRange(firstBlockId: 'b0', lastBlockId: 'b2'),
      );
    });
  });

  group('blocksInRange', () {
    late FolioPage page;

    setUp(() {
      page = FolioPage(
        id: 'p1',
        title: 'Test',
        blocks: [
          FolioBlock(id: 'b0', type: 'h1', text: 'Intro'),
          FolioBlock(id: 'b1', type: 'paragraph', text: 'uno'),
          FolioBlock(id: 'b2', type: 'paragraph', text: 'dos'),
          FolioBlock(id: 'b3', type: 'paragraph', text: 'tres'),
        ],
      );
    });

    test('rango normal de varios bloques', () {
      final blocks = blocksInRange(
        page,
        const BlockRange(firstBlockId: 'b1', lastBlockId: 'b2'),
      );
      expect(blocks.map((b) => b.id).toList(), ['b1', 'b2']);
    });

    test('rango de un solo bloque', () {
      final blocks = blocksInRange(
        page,
        const BlockRange(firstBlockId: 'b1', lastBlockId: 'b1'),
      );
      expect(blocks.map((b) => b.id).toList(), ['b1']);
    });

    test('id inexistente para firstBlockId devuelve lista vacía', () {
      final blocks = blocksInRange(
        page,
        const BlockRange(firstBlockId: 'missing', lastBlockId: 'b2'),
      );
      expect(blocks, isEmpty);
    });

    test('id inexistente para lastBlockId devuelve lista vacía', () {
      final blocks = blocksInRange(
        page,
        const BlockRange(firstBlockId: 'b1', lastBlockId: 'missing'),
      );
      expect(blocks, isEmpty);
    });

    test('rango invertido (lastBlockId antes que firstBlockId) devuelve '
        'lista vacía en vez de lanzar', () {
      final blocks = blocksInRange(
        page,
        const BlockRange(firstBlockId: 'b2', lastBlockId: 'b0'),
      );
      expect(blocks, isEmpty);
    });

    test('rango que cubre toda la página', () {
      final blocks = blocksInRange(
        page,
        const BlockRange(firstBlockId: 'b0', lastBlockId: 'b3'),
      );
      expect(blocks.length, 4);
    });
  });
}
