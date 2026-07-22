import 'package:folio/features/workspace/graph/graph_model.dart';
import 'package:folio/models/folio_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FolioPage page({
    required String id,
    String title = 'Page',
    String? parentId,
    bool isFolder = false,
    DateTime? trashedAt,
  }) {
    return FolioPage(
      id: id,
      title: title,
      parentId: parentId,
      isFolder: isFolder,
      trashedAt: trashedAt,
    );
  }

  group('buildVaultGraph', () {
    test('carpeta con hijo genera arista hierarchy', () {
      final folder = page(id: 'folder', title: 'Carpeta', isFolder: true);
      final child = page(id: 'child', title: 'Hijo', parentId: 'folder');

      final graph = buildVaultGraph(
        pages: [folder, child],
        backlinkPagesFor: (_) => const [],
        includeOrphans: true,
      );

      expect(graph.edges, hasLength(1));
      expect(graph.edges.first.kind, GraphEdgeKind.hierarchy);
      expect(graph.edges.first.fromId, 'folder');
      expect(graph.edges.first.toId, 'child');
    });

    test('mención @ genera arista link', () {
      final source = page(id: 'source', title: 'Origen');
      final target = page(id: 'target', title: 'Destino');

      final graph = buildVaultGraph(
        pages: [source, target],
        backlinkPagesFor: (id) => id == 'target' ? [source] : const [],
        includeOrphans: true,
      );

      expect(graph.edges, hasLength(1));
      expect(graph.edges.first.kind, GraphEdgeKind.link);
      expect(graph.edges.first.fromId, 'source');
      expect(graph.edges.first.toId, 'target');
    });

    test('hijo con parentId huérfano no genera arista', () {
      final orphan = page(id: 'child', title: 'Hijo', parentId: 'missing');

      final graph = buildVaultGraph(
        pages: [orphan],
        backlinkPagesFor: (_) => const [],
        includeOrphans: true,
      );

      expect(graph.edges, isEmpty);
    });

    test('excluye páginas en papelera', () {
      final folder = page(id: 'folder', title: 'Carpeta', isFolder: true);
      final trashedChild = page(
        id: 'child',
        title: 'Hijo',
        parentId: 'folder',
        trashedAt: DateTime.utc(2026, 1, 1),
      );

      final graph = buildVaultGraph(
        pages: [folder, trashedChild],
        backlinkPagesFor: (_) => const [],
        includeOrphans: true,
      );

      expect(graph.edges, isEmpty);
      expect(graph.nodes.map((n) => n.id), ['folder']);
    });

    test('deduplica link y hierarchy en el mismo par', () {
      final parent = page(id: 'parent', title: 'Padre');
      final child = page(id: 'child', title: 'Hijo', parentId: 'parent');

      final graph = buildVaultGraph(
        pages: [parent, child],
        backlinkPagesFor: (id) => id == 'child' ? [parent] : const [],
        includeOrphans: true,
      );

      expect(graph.edges, hasLength(1));
      expect(graph.edges.first.kind, GraphEdgeKind.link);
      expect(graph.edges.first.fromId, 'parent');
      expect(graph.edges.first.toId, 'child');
    });

    test('sin includeOrphans solo muestra nodos conectados', () {
      final folder = page(id: 'folder', title: 'Carpeta', isFolder: true);
      final child = page(id: 'child', title: 'Hijo', parentId: 'folder');
      final lonely = page(id: 'lonely', title: 'Solo');

      final graph = buildVaultGraph(
        pages: [folder, child, lonely],
        backlinkPagesFor: (_) => const [],
        includeOrphans: false,
      );

      expect(graph.nodes.map((n) => n.id), containsAll(['folder', 'child']));
      expect(graph.nodes.map((n) => n.id), isNot(contains('lonely')));
    });

    test('nodos de carpeta llevan isFolder true', () {
      final folder = page(id: 'folder', title: 'Carpeta', isFolder: true);
      final child = page(id: 'child', title: 'Hijo', parentId: 'folder');

      final graph = buildVaultGraph(
        pages: [folder, child],
        backlinkPagesFor: (_) => const [],
        includeOrphans: true,
      );

      final folderNode = graph.nodes.firstWhere((n) => n.id == 'folder');
      final childNode = graph.nodes.firstWhere((n) => n.id == 'child');
      expect(folderNode.isFolder, isTrue);
      expect(childNode.isFolder, isFalse);
    });
  });
}
