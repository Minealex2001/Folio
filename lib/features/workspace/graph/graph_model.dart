import '../../../models/folio_page.dart';

enum GraphEdgeKind { link, hierarchy }

class GraphEdge {
  const GraphEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
  });

  final String fromId;
  final String toId;
  final GraphEdgeKind kind;
}

class GraphNodeData {
  const GraphNodeData({
    required this.id,
    required this.label,
    required this.isFolder,
    this.emoji,
    /// Id de la carpeta que colorea este nodo (ella misma si es carpeta).
    this.colorGroupId,
  });

  final String id;
  final String label;
  final bool isFolder;
  final String? emoji;
  final String? colorGroupId;
}

class VaultGraphData {
  const VaultGraphData({
    required this.nodes,
    required this.edges,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdge> edges;
}

/// Carpeta más cercana en la jerarquía `parentId` (o el propio id si es carpeta).
String? resolveGraphColorGroupId(
  FolioPage page,
  Map<String, FolioPage> byId,
) {
  if (page.isFolder) return page.id;
  var current = page;
  final seen = <String>{page.id};
  while (true) {
    final parentId = current.parentId?.trim();
    if (parentId == null || parentId.isEmpty) return null;
    if (!seen.add(parentId)) return null;
    final parent = byId[parentId];
    if (parent == null) return null;
    if (parent.isFolder) return parent.id;
    current = parent;
  }
}

/// Construye nodos y aristas del grafo a partir de páginas activas,
/// backlinks internos y jerarquía `parentId`.
VaultGraphData buildVaultGraph({
  required List<FolioPage> pages,
  required List<FolioPage> Function(String targetPageId) backlinkPagesFor,
  required bool includeOrphans,
}) {
  final activePages = pages.where((p) => !p.isTrashed).toList();
  final byId = {for (final p in activePages) p.id: p};
  final edges = <GraphEdge>[];
  final edgeKindsByKey = <String, GraphEdgeKind>{};
  final linkedPageIds = <String>{};

  void markLinked(String a, String b) {
    linkedPageIds.add(a);
    linkedPageIds.add(b);
  }

  void addEdge(String fromId, String toId, GraphEdgeKind kind) {
    final key = '$fromId→$toId';
    final existing = edgeKindsByKey[key];
    if (existing == GraphEdgeKind.link) return;
    if (existing == GraphEdgeKind.hierarchy && kind == GraphEdgeKind.hierarchy) {
      return;
    }
    if (existing == GraphEdgeKind.hierarchy && kind == GraphEdgeKind.link) {
      edges.removeWhere((e) => e.fromId == fromId && e.toId == toId);
      edgeKindsByKey[key] = GraphEdgeKind.link;
      edges.add(GraphEdge(fromId: fromId, toId: toId, kind: GraphEdgeKind.link));
      markLinked(fromId, toId);
      return;
    }
    edgeKindsByKey[key] = kind;
    edges.add(GraphEdge(fromId: fromId, toId: toId, kind: kind));
    markLinked(fromId, toId);
  }

  // Aristas por backlinks (menciones @, folio://, child_page).
  final undirectedLinkKeys = <String>{};
  for (final page in activePages) {
    final backlinks = backlinkPagesFor(page.id);
    for (final src in backlinks) {
      if (src.isTrashed) continue;
      final undirectedKey = src.id.compareTo(page.id) < 0
          ? '${src.id}→${page.id}'
          : '${page.id}→${src.id}';
      if (undirectedLinkKeys.contains(undirectedKey)) continue;
      undirectedLinkKeys.add(undirectedKey);
      addEdge(src.id, page.id, GraphEdgeKind.link);
    }
  }

  // Aristas por jerarquía carpeta/folio (parentId).
  for (final page in activePages) {
    final parentId = page.parentId?.trim();
    if (parentId == null || parentId.isEmpty) continue;
    if (parentId == page.id) continue;
    final parent = byId[parentId];
    if (parent == null) continue;
    addEdge(parentId, page.id, GraphEdgeKind.hierarchy);
  }

  final visiblePages = includeOrphans
      ? activePages
      : activePages.where((p) => linkedPageIds.contains(p.id)).toList();

  final nodes = visiblePages
      .map(
        (p) => GraphNodeData(
          id: p.id,
          label: p.title.trim().isEmpty ? '…' : p.title.trim(),
          isFolder: p.isFolder,
          emoji: p.emoji,
          colorGroupId: resolveGraphColorGroupId(p, byId),
        ),
      )
      .toList(growable: false);

  final visibleIds = visiblePages.map((p) => p.id).toSet();
  final visibleEdges = edges
      .where(
        (e) => visibleIds.contains(e.fromId) && visibleIds.contains(e.toId),
      )
      .toList(growable: false);

  return VaultGraphData(nodes: nodes, edges: visibleEdges);
}
