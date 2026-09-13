import 'package:flutter_test/flutter_test.dart';

import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/vault_memory_fact.dart';
import 'package:folio/services/ai/quill_context_engine.dart';

FolioPage _page(
  String id, {
  String title = 'Untitled',
  String text = 'content',
  DateTime? trashedAt,
}) {
  return FolioPage(
    id: id,
    title: title,
    trashedAt: trashedAt,
    blocks: [FolioBlock(id: '${id}_b0', type: 'paragraph', text: text)],
  );
}

void main() {
  const engine = QuillContextEngine();

  group('resolveContextPageIds', () {
    test('devuelve vacío cuando el contexto de página está desactivado', () {
      final vault = {'a': _page('a')};
      final result = engine.resolveContextPageIds(
        includePageContext: false,
        contextPageIds: const ['a'],
        scopePageId: 'a',
        pageById: (id) => vault[id],
      );
      expect(result, isEmpty);
    });

    test('aislamiento entre vaults: ids de otro vault se excluyen', () {
      // pageById simula un vault donde solo existe 'a'; 'foreign' pertenece
      // a otro vault y nunca debe resolverse.
      final vault = {'a': _page('a')};
      final result = engine.resolveContextPageIds(
        includePageContext: true,
        contextPageIds: const ['a', 'foreign'],
        pageById: (id) => vault[id],
      );
      expect(result, ['a']);
    });

    test('exclusión de papelera: páginas trashed se excluyen', () {
      final vault = {
        'a': _page('a'),
        'b': _page('b', trashedAt: DateTime.utc(2026, 1, 1)),
      };
      final result = engine.resolveContextPageIds(
        includePageContext: true,
        contextPageIds: const ['a', 'b'],
        pageById: (id) => vault[id],
      );
      expect(result, ['a']);
    });

    test('contexto explícito tiene prioridad sobre scopePageId', () {
      final vault = {'a': _page('a'), 'b': _page('b')};
      final result = engine.resolveContextPageIds(
        includePageContext: true,
        contextPageIds: const ['b'],
        scopePageId: 'a',
        pageById: (id) => vault[id],
      );
      expect(result, ['b']);
    });

    test('sin contexto explícito, cae a scopePageId', () {
      final vault = {'a': _page('a')};
      final result = engine.resolveContextPageIds(
        includePageContext: true,
        contextPageIds: const [],
        scopePageId: 'a',
        pageById: (id) => vault[id],
      );
      expect(result, ['a']);
    });

    test('determinismo: misma entrada produce mismo resultado', () {
      final vault = {'a': _page('a'), 'b': _page('b')};
      List<String> run() => engine.resolveContextPageIds(
            includePageContext: true,
            contextPageIds: const ['b', 'a'],
            pageById: (id) => vault[id],
          );
      expect(run(), run());
    });
  });

  group('buildPagesTextContext', () {
    test('sin páginas devuelve el mensaje de fallback (es)', () {
      final result = engine.buildPagesTextContext(
        const [],
        isEs: true,
        pageById: (_) => null,
      );
      expect(result.sources, isEmpty);
      expect(result.combinedText, '(No hay folios de texto en el contexto.)');
    });

    test('sin páginas devuelve el mensaje de fallback (en)', () {
      final result = engine.buildPagesTextContext(
        const [],
        isEs: false,
        pageById: (_) => null,
      );
      expect(result.combinedText, '(No pages in the text context.)');
    });

    test('marca la página activa como ACTIVE_PAGE y cuenta como 1 fuente', () {
      final vault = {'a': _page('a', title: 'Home', text: 'hola')};
      final result = engine.buildPagesTextContext(
        const ['a'],
        isEs: true,
        activePageId: 'a',
        pageById: (id) => vault[id],
      );
      expect(result.sourceCount, 1);
      expect(result.sources.single.kind, QuillContextSourceKind.activePage);
      expect(result.combinedText, contains('[ACTIVE_PAGE] Home'));
      expect(result.combinedText, contains('hola'));
    });

    test('numera las páginas de referencia y cuenta una fuente por página', () {
      final vault = {
        'a': _page('a', title: 'Uno'),
        'b': _page('b', title: 'Dos'),
      };
      final result = engine.buildPagesTextContext(
        const ['a', 'b'],
        isEs: true,
        pageById: (id) => vault[id],
      );
      expect(result.sourceCount, 2);
      expect(result.combinedText, contains('[REFERENCE_PAGE 1] Uno'));
      expect(result.combinedText, contains('[REFERENCE_PAGE 2] Dos'));
    });

    test('determinismo: mismas páginas producen el mismo texto siempre', () {
      final vault = {'a': _page('a', title: 'Uno')};
      String run() => engine
          .buildPagesTextContext(
            const ['a'],
            isEs: true,
            pageById: (id) => vault[id],
          )
          .combinedText;
      expect(run(), run());
    });
  });

  group('assembleExtraContext', () {
    test('sin fuentes activas produce texto vacío y cero fuentes', () {
      final result = engine.assembleExtraContext(
        memoryFacts: const [],
        memoryFactsHeader: 'Memoria:',
        selectionHeader: 'Selección:',
        lastMeetingHeader: 'Última reunión:',
      );
      expect(result.sourceCount, 0);
      expect(result.combinedText, isEmpty);
    });

    test('hechos de memoria se cuentan como una única fuente', () {
      final facts = [
        VaultMemoryFact(
          id: '1',
          text: 'Le gusta el café',
          createdAt: DateTime.utc(2026, 1, 1),
          scope: MemoryFactScope.permanent,
        ),
        VaultMemoryFact(
          id: '2',
          text: 'Proyecto: Quill 2.0',
          createdAt: DateTime.utc(2026, 1, 1),
          scope: MemoryFactScope.temporary,
        ),
      ];
      final result = engine.assembleExtraContext(
        memoryFacts: facts,
        memoryFactsHeader: 'Memoria:',
        selectionHeader: 'Selección:',
        lastMeetingHeader: 'Última reunión:',
      );
      expect(result.sourceCount, 1);
      expect(result.sources.single.kind, QuillContextSourceKind.memoryFacts);
      expect(result.combinedText, contains('- Le gusta el café'));
      expect(result.combinedText, contains('- Proyecto: Quill 2.0'));
    });

    test('selección explícita aparece como fuente propia', () {
      final result = engine.assembleExtraContext(
        memoryFacts: const [],
        memoryFactsHeader: 'Memoria:',
        selectionSnippet: 'texto seleccionado',
        selectionHeader: 'Selección:',
        lastMeetingHeader: 'Última reunión:',
      );
      expect(result.sourceCount, 1);
      expect(result.sources.single.kind, QuillContextSourceKind.selection);
      expect(result.combinedText, contains('Selección:'));
      expect(result.combinedText, contains('texto seleccionado'));
    });

    test('selección vacía o null no genera fuente', () {
      final result = engine.assembleExtraContext(
        memoryFacts: const [],
        memoryFactsHeader: 'Memoria:',
        selectionSnippet: '   ',
        selectionHeader: 'Selección:',
        lastMeetingHeader: 'Última reunión:',
      );
      expect(result.sourceCount, 0);
    });

    test('conteo de fuentes combina memoria + selección + última reunión', () {
      final facts = [
        VaultMemoryFact(
          id: '1',
          text: 'hecho',
          createdAt: DateTime.utc(2026, 1, 1),
          scope: MemoryFactScope.permanent,
        ),
      ];
      final result = engine.assembleExtraContext(
        memoryFacts: facts,
        memoryFactsHeader: 'Memoria:',
        selectionSnippet: 'seleccion',
        selectionHeader: 'Selección:',
        lastMeetingSnippet: 'resumen reunión',
        lastMeetingHeader: 'Última reunión:',
      );
      expect(result.sourceCount, 3);
    });

    test('determinismo: misma entrada produce mismo texto y orden', () {
      final facts = [
        VaultMemoryFact(
          id: '1',
          text: 'hecho',
          createdAt: DateTime.utc(2026, 1, 1),
          scope: MemoryFactScope.permanent,
        ),
      ];
      QuillContextResult run() => engine.assembleExtraContext(
            memoryFacts: facts,
            memoryFactsHeader: 'Memoria:',
            selectionSnippet: 'seleccion',
            selectionHeader: 'Selección:',
            lastMeetingHeader: 'Última reunión:',
          );
      final r1 = run();
      final r2 = run();
      expect(r1.combinedText, r2.combinedText);
      expect(
        r1.sources.map((s) => s.kind).toList(),
        r2.sources.map((s) => s.kind).toList(),
      );
    });
  });
}
