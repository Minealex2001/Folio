import 'dart:convert';

// ─── Tipos de nodo ───────────────────────────────────────────────────────────

enum CanvasNodeType { text, shape, image, folioBlock }

enum CanvasShapeType { rectangle, ellipse, diamond, triangle }

enum CanvasEdgeStyle { straight, curve, arrow }

// ─── Nodo ────────────────────────────────────────────────────────────────────

class FolioCanvasNode {
  FolioCanvasNode({
    required this.id,
    required this.type,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 200.0,
    this.height = 120.0,
    this.text = '',
    this.shapeType = CanvasShapeType.rectangle,
    this.color,
    this.imageUrl,
    this.folioBlockType,
    this.folioBlockText,
    this.folioBlockChecked,
  });

  final String id;
  CanvasNodeType type;
  double x;
  double y;
  double width;
  double height;
  String text;
  CanvasShapeType shapeType;
  String? color; // '#RRGGBB'
  String? imageUrl;

  /// Para nodos tipo folioBlock: tipo del bloque original (p. ej. 'database')
  String? folioBlockType;

  /// Texto/título del bloque Folio embebido
  String? folioBlockText;

  /// Estado de check para bloques tipo 'todo'
  bool? folioBlockChecked;

  FolioCanvasNode copyWith({
    CanvasNodeType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    String? text,
    CanvasShapeType? shapeType,
    String? color,
    String? imageUrl,
    String? folioBlockType,
    String? folioBlockText,
    bool? folioBlockChecked,
  }) {
    return FolioCanvasNode(
      id: id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      shapeType: shapeType ?? this.shapeType,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      folioBlockType: folioBlockType ?? this.folioBlockType,
      folioBlockText: folioBlockText ?? this.folioBlockText,
      folioBlockChecked: folioBlockChecked ?? this.folioBlockChecked,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    if (text.isNotEmpty) 'text': text,
    'shapeType': shapeType.name,
    if (color != null) 'color': color,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (folioBlockType != null) 'folioBlockType': folioBlockType,
    if (folioBlockText != null) 'folioBlockText': folioBlockText,
    if (folioBlockChecked != null) 'folioBlockChecked': folioBlockChecked,
  };

  factory FolioCanvasNode.fromJson(Map<String, dynamic> j) {
    return FolioCanvasNode(
      id: j['id'] as String,
      type: CanvasNodeType.values.firstWhere(
        (e) => e.name == j['type'],
        orElse: () => CanvasNodeType.text,
      ),
      x: (j['x'] as num?)?.toDouble() ?? 0.0,
      y: (j['y'] as num?)?.toDouble() ?? 0.0,
      width: (j['width'] as num?)?.toDouble() ?? 200.0,
      height: (j['height'] as num?)?.toDouble() ?? 120.0,
      text: j['text'] as String? ?? '',
      shapeType: CanvasShapeType.values.firstWhere(
        (e) => e.name == j['shapeType'],
        orElse: () => CanvasShapeType.rectangle,
      ),
      color: j['color'] as String?,
      imageUrl: j['imageUrl'] as String?,
      folioBlockType: j['folioBlockType'] as String?,
      folioBlockText: j['folioBlockText'] as String?,
      folioBlockChecked: j['folioBlockChecked'] as bool?,
    );
  }
}

// ─── Stroke de dibujo libre ──────────────────────────────────────────────────

class FolioCanvasStroke {
  FolioCanvasStroke({
    required this.id,
    required this.points,
    this.color = '#000000',
    this.strokeWidth = 2.0,
  });

  final String id;
  final List<CanvasPoint> points;
  final String color;
  final double strokeWidth;

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points.map((p) => p.toJson()).toList(),
    'color': color,
    'strokeWidth': strokeWidth,
  };

  factory FolioCanvasStroke.fromJson(Map<String, dynamic> j) {
    final rawPoints = j['points'] as List? ?? [];
    return FolioCanvasStroke(
      id: j['id'] as String,
      points: rawPoints
          .map((p) => CanvasPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      color: j['color'] as String? ?? '#000000',
      strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 2.0,
    );
  }
}

class CanvasPoint {
  const CanvasPoint(this.x, this.y);
  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory CanvasPoint.fromJson(Map<String, dynamic> j) =>
      CanvasPoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}

// ─── Conector/flecha ─────────────────────────────────────────────────────────

class FolioCanvasEdge {
  FolioCanvasEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.label = '',
    this.style = CanvasEdgeStyle.arrow,
    this.color,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final CanvasEdgeStyle style;
  final String? color;

  FolioCanvasEdge copyWith({
    String? label,
    CanvasEdgeStyle? style,
    String? color,
  }) {
    return FolioCanvasEdge(
      id: id,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      label: label ?? this.label,
      style: style ?? this.style,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
    if (label.isNotEmpty) 'label': label,
    'style': style.name,
    if (color != null) 'color': color,
  };

  factory FolioCanvasEdge.fromJson(Map<String, dynamic> j) {
    return FolioCanvasEdge(
      id: j['id'] as String,
      fromNodeId: j['fromNodeId'] as String,
      toNodeId: j['toNodeId'] as String,
      label: j['label'] as String? ?? '',
      style: CanvasEdgeStyle.values.firstWhere(
        (e) => e.name == j['style'],
        orElse: () => CanvasEdgeStyle.arrow,
      ),
      color: j['color'] as String?,
    );
  }
}

// ─── Datos completos del canvas ───────────────────────────────────────────────

class FolioCanvasData {
  FolioCanvasData({
    required this.nodes,
    required this.edges,
    required this.strokes,
    this.viewportX = 0.0,
    this.viewportY = 0.0,
    this.viewportScale = 1.0,
  });

  final List<FolioCanvasNode> nodes;
  final List<FolioCanvasEdge> edges;
  final List<FolioCanvasStroke> strokes;
  final double viewportX;
  final double viewportY;
  final double viewportScale;

  static FolioCanvasData defaults() => FolioCanvasData(
    nodes: [],
    edges: [],
    strokes: [],
    viewportX: 0.0,
    viewportY: 0.0,
    viewportScale: 1.0,
  );

  String encode() => jsonEncode({
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'viewportX': viewportX,
    'viewportY': viewportY,
    'viewportScale': viewportScale,
  });

  static FolioCanvasData? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final rawNodes = j['nodes'] as List? ?? [];
      final rawEdges = j['edges'] as List? ?? [];
      final rawStrokes = j['strokes'] as List? ?? [];
      return FolioCanvasData(
        nodes: rawNodes
            .map((n) => FolioCanvasNode.fromJson(n as Map<String, dynamic>))
            .toList(),
        edges: rawEdges
            .map((e) => FolioCanvasEdge.fromJson(e as Map<String, dynamic>))
            .toList(),
        strokes: rawStrokes
            .map((s) => FolioCanvasStroke.fromJson(s as Map<String, dynamic>))
            .toList(),
        viewportX: (j['viewportX'] as num?)?.toDouble() ?? 0.0,
        viewportY: (j['viewportY'] as num?)?.toDouble() ?? 0.0,
        viewportScale: (j['viewportScale'] as num?)?.toDouble() ?? 1.0,
      );
    } catch (_) {
      return null;
    }
  }

  FolioCanvasData copyWith({
    List<FolioCanvasNode>? nodes,
    List<FolioCanvasEdge>? edges,
    List<FolioCanvasStroke>? strokes,
    double? viewportX,
    double? viewportY,
    double? viewportScale,
  }) {
    return FolioCanvasData(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      strokes: strokes ?? this.strokes,
      viewportX: viewportX ?? this.viewportX,
      viewportY: viewportY ?? this.viewportY,
      viewportScale: viewportScale ?? this.viewportScale,
    );
  }
}
