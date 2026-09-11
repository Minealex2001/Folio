/// Fase 5 de la evolución de `meeting_note` — meeting_get_context.
///
/// La tool envuelve infraestructura ya existente (`backlinkPagesFor`,
/// `childrenOf`, `page.tags`) — este test verifica que el bundle que arma
/// sea correcto, no reimplementa la lógica de grafo que ya tiene cobertura
/// propia en otros tests de `VaultSession`.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
import 'package:folio/session/vault_session.dart';

/// Fase 23 (privacidad): con allowlist MCP activa, deniega todo lo que no
/// esté explícitamente en [allowed] — simula el caso más restrictivo de un
/// cliente MCP externo.
Future<McpReadAccessDecision> Function(String, String) _denyUnlessAllowed(
  Set<String> allowed,
) {
  return (pageId, _) async => allowed.contains(pageId)
      ? McpReadAccessDecision.allowOnce
      : McpReadAccessDecision.deny;
}

void main() {
  group('FolioToolRegistry — meeting_get_context', () {
    late VaultSession session;
    late FolioToolRegistry registry;

    setUp(() {
      session = VaultSession();
      registry = FolioToolRegistry(session);
    });

    test('está presente en las definiciones', () {
      expect(registry.definitionByName('meeting_get_context'), isNotNull);
    });

    test('devuelve error si la página no existe', () async {
      final result = await registry.execute(
        AiToolCall(
          id: 'c1',
          name: 'meeting_get_context',
          arguments: {'pageId': 'no-existe'},
        ),
      );
      expect(result.isError, isTrue);
    });

    test('incluye tags, padre, hijos y backlinks de la página', () async {
      // Padre
      session.addPage();
      final parent = session.selectedPage!;
      session.renamePage(parent.id, 'Proyecto Cloud Teams');

      // Página objetivo (la del meeting_note), hija de parent
      session.addPage(parentId: parent.id);
      final target = session.selectedPage!;
      session.renamePage(target.id, 'Weekly sync');
      session.addPageTag(target.id, 'reunion');

      // Hija de la página objetivo
      session.addPage(parentId: target.id);
      final child = session.selectedPage!;
      session.renamePage(child.id, 'Action items');

      // Otra página que enlaza (backlink) a la página objetivo.
      session.addPage();
      final linker = session.selectedPage!;
      session.renamePage(linker.id, 'Notas relacionadas');
      session.updateBlockText(
        linker.id,
        linker.blocks.first.id,
        'Ver folio://open/${target.id} para más contexto.',
      );

      final result = await registry.execute(
        AiToolCall(
          id: 'c2',
          name: 'meeting_get_context',
          arguments: {'pageId': target.id},
        ),
      );

      expect(result.isError, isFalse);
      expect(result.content, contains('"pageTitle":"Weekly sync"'));
      expect(result.content, contains('"reunion"'));
      expect(result.content, contains('Proyecto Cloud Teams'));
      expect(result.content, contains('Action items'));
      expect(result.content, contains('Notas relacionadas'));
    });

    test('página sin padre/hijos/backlinks devuelve arrays vacíos, no null ni error', () async {
      session.addPage();
      final page = session.selectedPage!;

      final result = await registry.execute(
        AiToolCall(
          id: 'c3',
          name: 'meeting_get_context',
          arguments: {'pageId': page.id},
        ),
      );

      expect(result.isError, isFalse);
      expect(result.content, contains('"tags":[]'));
      expect(result.content, contains('"parent":null'));
      expect(result.content, contains('"children":[]'));
      expect(result.content, contains('"relatedPages":[]'));
    });

    test('soporta pageId "current" vía scopePageId', () async {
      session.addPage();
      final page = session.selectedPage!;
      session.renamePage(page.id, 'Página actual');
      final scopedRegistry = FolioToolRegistry(session, scopePageId: page.id);

      final result = await scopedRegistry.execute(
        AiToolCall(
          id: 'c4',
          name: 'meeting_get_context',
          arguments: {'pageId': 'current'},
        ),
      );

      expect(result.isError, isFalse);
      expect(result.content, contains('"pageTitle":"Página actual"'));
    });

    group('Fase 23 — allowlist MCP (clientes externos)', () {
      test(
        'sin acceso a la página del meeting_note, deniega la tool por completo',
        () async {
          session.addPage();
          final target = session.selectedPage!;

          final gatedRegistry = FolioToolRegistry(
            session,
            onRequestMcpReadAccess: _denyUnlessAllowed(const {}),
          );

          final result = await gatedRegistry.execute(
            AiToolCall(
              id: 'g1',
              name: 'meeting_get_context',
              arguments: {'pageId': target.id},
            ),
          );

          expect(result.isError, isTrue);
        },
      );

      test(
        'con acceso solo a la página objetivo, NO revela títulos de padre/hijos/relacionadas fuera de la allowlist',
        () async {
          session.addPage();
          final parent = session.selectedPage!;
          session.renamePage(parent.id, 'Proyecto secreto');

          session.addPage(parentId: parent.id);
          final target = session.selectedPage!;
          session.renamePage(target.id, 'Weekly sync');

          session.addPage(parentId: target.id);
          final child = session.selectedPage!;
          session.renamePage(child.id, 'Subpágina secreta');

          session.addPage();
          final linker = session.selectedPage!;
          session.renamePage(linker.id, 'Nota secreta relacionada');
          session.updateBlockText(
            linker.id,
            linker.blocks.first.id,
            'Ver folio://open/${target.id}.',
          );

          final gatedRegistry = FolioToolRegistry(
            session,
            onRequestMcpReadAccess: _denyUnlessAllowed({target.id}),
          );

          final result = await gatedRegistry.execute(
            AiToolCall(
              id: 'g2',
              name: 'meeting_get_context',
              arguments: {'pageId': target.id},
            ),
          );

          expect(result.isError, isFalse);
          expect(result.content, contains('"pageTitle":"Weekly sync"'));
          // La página objetivo sí está autorizada, pero ninguna de las
          // relacionadas lo está — sus títulos no deben aparecer.
          expect(result.content, isNot(contains('Proyecto secreto')));
          expect(result.content, isNot(contains('Subpágina secreta')));
          expect(result.content, isNot(contains('Nota secreta relacionada')));
          expect(result.content, contains('"parent":null'));
          expect(result.content, contains('"children":[]'));
          expect(result.content, contains('"relatedPages":[]'));
        },
      );

      test(
        'allowAndRemember en la página objetivo evita repreguntar en llamadas siguientes',
        () async {
          session.addPage();
          final target = session.selectedPage!;
          var askCount = 0;

          final gatedRegistry = FolioToolRegistry(
            session,
            onRequestMcpReadAccess: (pageId, _) async {
              askCount++;
              return McpReadAccessDecision.allowAndRemember;
            },
          );

          await gatedRegistry.execute(
            AiToolCall(
              id: 'g3',
              name: 'meeting_get_context',
              arguments: {'pageId': target.id},
            ),
          );
          await gatedRegistry.execute(
            AiToolCall(
              id: 'g4',
              name: 'meeting_get_context',
              arguments: {'pageId': target.id},
            ),
          );

          expect(askCount, 1);
        },
      );
    });
  });
}
