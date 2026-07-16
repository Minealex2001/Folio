import 'package:uuid/uuid.dart';

import '../../../models/folio_canvas_data.dart';
import 'canvas_template_labels.dart';

const _uuid = Uuid();

/// Plantillas predefinidas para el lienzo (se fusionan con el estado actual).
enum CanvasBuiltInTemplate { mindmap, flowchart, userJourney, swot }

FolioCanvasNode _shapeNode({
  required String id,
  required double x,
  required double y,
  required double w,
  required double h,
  required String text,
  required CanvasShapeType shape,
  String color = '#FFF9C4',
}) {
  return FolioCanvasNode(
    id: id,
    type: CanvasNodeType.shape,
    x: x,
    y: y,
    width: w,
    height: h,
    text: text,
    shapeType: shape,
    color: color,
  );
}

/// Nodos y aristas adicionales para la plantilla.
FolioCanvasData canvasTemplateData(
  CanvasBuiltInTemplate kind,
  CanvasTemplateLabels L,
) {
  switch (kind) {
    case CanvasBuiltInTemplate.mindmap:
      return _mindmap(L);
    case CanvasBuiltInTemplate.flowchart:
      return _flowchart(L);
    case CanvasBuiltInTemplate.userJourney:
      return _journey(L);
    case CanvasBuiltInTemplate.swot:
      return _swot(L);
  }
}

FolioCanvasData _mindmap(CanvasTemplateLabels L) {
  final center = _uuid.v4();
  final a = _uuid.v4();
  final b = _uuid.v4();
  final c = _uuid.v4();
  final d = _uuid.v4();
  return FolioCanvasData(
    nodes: [
      FolioCanvasNode(
        id: center,
        type: CanvasNodeType.text,
        x: 400,
        y: 300,
        width: 180,
        height: 80,
        text: L.mindmapCenter,
        color: '#FFECB3',
      ),
      FolioCanvasNode(
        id: a,
        type: CanvasNodeType.text,
        x: 200,
        y: 150,
        width: 140,
        height: 64,
        text: L.mindmapBranch,
        color: '#C8E6C9',
      ),
      FolioCanvasNode(
        id: b,
        type: CanvasNodeType.text,
        x: 620,
        y: 150,
        width: 140,
        height: 64,
        text: L.mindmapBranch,
        color: '#BBDEFB',
      ),
      FolioCanvasNode(
        id: c,
        type: CanvasNodeType.text,
        x: 200,
        y: 450,
        width: 140,
        height: 64,
        text: L.mindmapBranch,
        color: '#E1BEE7',
      ),
      FolioCanvasNode(
        id: d,
        type: CanvasNodeType.text,
        x: 620,
        y: 450,
        width: 140,
        height: 64,
        text: L.mindmapBranch,
        color: '#FFCCBC',
      ),
    ],
    edges: [
      FolioCanvasEdge(id: _uuid.v4(), fromNodeId: center, toNodeId: a, style: CanvasEdgeStyle.arrow),
      FolioCanvasEdge(id: _uuid.v4(), fromNodeId: center, toNodeId: b, style: CanvasEdgeStyle.arrow),
      FolioCanvasEdge(id: _uuid.v4(), fromNodeId: center, toNodeId: c, style: CanvasEdgeStyle.arrow),
      FolioCanvasEdge(id: _uuid.v4(), fromNodeId: center, toNodeId: d, style: CanvasEdgeStyle.arrow),
    ],
    strokes: [],
  );
}

FolioCanvasData _flowchart(CanvasTemplateLabels L) {
  final s = _uuid.v4();
  final p1 = _uuid.v4();
  final d = _uuid.v4();
  final e = _uuid.v4();
  final end = _uuid.v4();
  return FolioCanvasData(
    nodes: [
      _shapeNode(
        id: s,
        x: 380,
        y: 80,
        w: 160,
        h: 72,
        text: L.flowStart,
        shape: CanvasShapeType.ellipse,
        color: '#C8E6C9',
      ),
      FolioCanvasNode(id: p1, type: CanvasNodeType.text, x: 360, y: 200, width: 200, height: 72, text: L.flowProcess, color: '#BBDEFB'),
      _shapeNode(
        id: d,
        x: 360,
        y: 320,
        w: 200,
        h: 80,
        text: L.flowDecision,
        shape: CanvasShapeType.diamond,
        color: '#FFF9C4',
      ),
      FolioCanvasNode(id: e, type: CanvasNodeType.text, x: 620, y: 330, width: 160, height: 64, text: L.flowBranchYes, color: '#E1BEE7'),
      _shapeNode(
        id: end,
        x: 380,
        y: 480,
        w: 160,
        h: 72,
        text: L.flowEnd,
        shape: CanvasShapeType.ellipse,
        color: '#FFCCBC',
      ),
    ],
    edges: [
      FolioCanvasEdge(id: _uuid.v4(), fromNodeId: s, toNodeId: p1, style: CanvasEdgeStyle.arrow),
      FolioCanvasEdge(id: _uuid.v4(), fromNodeId: p1, toNodeId: d, style: CanvasEdgeStyle.arrow),
      FolioCanvasEdge(
        id: _uuid.v4(),
        fromNodeId: d,
        toNodeId: e,
        label: L.flowEdgeYes,
        style: CanvasEdgeStyle.arrow,
      ),
      FolioCanvasEdge(
        id: _uuid.v4(),
        fromNodeId: d,
        toNodeId: end,
        label: L.flowEdgeNo,
        style: CanvasEdgeStyle.arrow,
      ),
      FolioCanvasEdge(id: _uuid.v4(), fromNodeId: e, toNodeId: end, style: CanvasEdgeStyle.arrow),
    ],
    strokes: [],
  );
}

FolioCanvasData _journey(CanvasTemplateLabels L) {
  final stages = [L.journeyDiscover, L.journeyConsider, L.journeyBuy, L.journeyRetain];
  final nodes = <FolioCanvasNode>[];
  final edges = <FolioCanvasEdge>[];
  String? prev;
  var x = 120.0;
  for (final label in stages) {
    final id = _uuid.v4();
    nodes.add(
      FolioCanvasNode(
        id: id,
        type: CanvasNodeType.text,
        x: x,
        y: 260,
        width: 160,
        height: 72,
        text: label,
        color: '#BBDEFB',
      ),
    );
    if (prev != null) {
      edges.add(FolioCanvasEdge(id: _uuid.v4(), fromNodeId: prev, toNodeId: id, style: CanvasEdgeStyle.arrow));
    }
    prev = id;
    x += 220;
  }
  nodes.add(
    FolioCanvasNode(
      id: _uuid.v4(),
      type: CanvasNodeType.text,
      x: 200,
      y: 120,
      width: 520,
      height: 56,
      text: L.journeyTitle,
      color: '#FFECB3',
    ),
  );
  return FolioCanvasData(nodes: nodes, edges: edges, strokes: []);
}

FolioCanvasData _swot(CanvasTemplateLabels L) {
  FolioCanvasNode q(String t, double x, double y, String col) => FolioCanvasNode(
    id: _uuid.v4(),
    type: CanvasNodeType.text,
    x: x,
    y: y,
    width: 240,
    height: 180,
    text: t,
    color: col,
  );
  return FolioCanvasData(
    nodes: [
      q(L.swotStrengths, 200, 200, '#C8E6C9'),
      q(L.swotWeaknesses, 480, 200, '#FFCCBC'),
      q(L.swotOpportunities, 200, 420, '#BBDEFB'),
      q(L.swotThreats, 480, 420, '#E1BEE7'),
      FolioCanvasNode(
        id: _uuid.v4(),
        type: CanvasNodeType.text,
        x: 300,
        y: 80,
        width: 320,
        height: 56,
        text: L.swotTitle,
        color: '#FFF9C4',
      ),
    ],
    edges: [],
    strokes: [],
  );
}

/// Fusiona [base] con [extra] (nodos, aristas y grupos al final).
FolioCanvasData mergeCanvasTemplate(FolioCanvasData base, FolioCanvasData extra) {
  return base.copyWith(
    nodes: [...base.nodes, ...extra.nodes],
    edges: [...base.edges, ...extra.edges],
    groups: [...base.groups, ...extra.groups],
  );
}
