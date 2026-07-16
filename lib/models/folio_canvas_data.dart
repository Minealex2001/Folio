import 'dart:convert';

// ─── Tipos de nodo ───────────────────────────────────────────────────────────

enum CanvasNodeType { text, shape, image, folioBlock, frame }

enum CanvasShapeType { rectangle, ellipse, diamond, triangle }

enum CanvasEdgeStyle { straight, curve, arrow, bezier }

/// Tipo de trazo para dibujo libre (lápiz, resaltador; borrador en UI).
enum FolioCanvasStrokeKind { ink, highlighter }

// ─── Grupo (metadatos; los nodos referencian [groupId]) ──────────────────────

class FolioCanvasGroup {
  FolioCanvasGroup({
    required this.id,
    this.name,
    required this.childNodeIds,
  });

  final String id;
  final String? name;
  final List<String> childNodeIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null && name!.isNotEmpty) 'name': name,
    'childNodeIds': childNodeIds,
  };

  factory FolioCanvasGroup.fromJson(Map<String, dynamic> j) {
    final raw = j['childNodeIds'] as List? ?? [];
    return FolioCanvasGroup(
      id: j['id'] as String,
      name: j['name'] as String?,
      childNodeIds: raw.map((e) => e as String).toList(),
    );
  }

  FolioCanvasGroup copyWith({
    String? name,
    List<String>? childNodeIds,
  }) {
    return FolioCanvasGroup(
      id: id,
      name: name ?? this.name,
      childNodeIds: childNodeIds ?? this.childNodeIds,
    );
  }
}

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
    this.folioBlockPayload,
    this.visible = true,
    this.locked = false,
    this.rotation = 0.0,
    this.groupId,
    this.frameChildIds = const [],
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

  /// JSON opcional con contenido rico del bloque (p. ej. Delta) para render avanzado
  String? folioBlockPayload;

  bool visible;
  bool locked;

  /// Rotación en radianes (sentido matemático estándar)
  double rotation;

  /// Id de [FolioCanvasGroup] si el nodo pertenece a un grupo
  String? groupId;

  /// Ids de nodos contenidos en un marco ([CanvasNodeType.frame])
  List<String> frameChildIds;

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
    String? folioBlockPayload,
    bool? visible,
    bool? locked,
    double? rotation,
    String? groupId,
    List<String>? frameChildIds,
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
      folioBlockPayload: folioBlockPayload ?? this.folioBlockPayload,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
      groupId: groupId ?? this.groupId,
      frameChildIds: frameChildIds ?? this.frameChildIds,
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
    if (folioBlockPayload != null && folioBlockPayload!.isNotEmpty)
      'folioBlockPayload': folioBlockPayload,
    if (!visible) 'visible': visible,
    if (locked) 'locked': locked,
    if (rotation != 0.0) 'rotation': rotation,
    if (groupId != null) 'groupId': groupId,
    if (frameChildIds.isNotEmpty) 'frameChildIds': frameChildIds,
  };

  factory FolioCanvasNode.fromJson(Map<String, dynamic> j) {
    final typeName = j['type'] as String? ?? 'text';
    final type = CanvasNodeType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => CanvasNodeType.text,
    );
    final rawFrame = j['frameChildIds'] as List? ?? [];
    return FolioCanvasNode(
      id: j['id'] as String,
      type: type,
      x: (j['x'] as num?)?.toDouble() ?? 0.0,
      y: (j['y'] as num?)?.toDouble() ?? 0.0,
      width: (j['width'] as num?)?.toDouble() ?? 200.0,
      height: (j['height'] as num?)?.toDouble() ?? 120.0,
      text: j['text'] as String? ?? '',
      shapeType: CanvasShapeType.values.firstWhere(
        (e) => e.name == (j['shapeType'] as String? ?? 'rectangle'),
        orElse: () => CanvasShapeType.rectangle,
      ),
      color: j['color'] as String?,
      imageUrl: j['imageUrl'] as String?,
      folioBlockType: j['folioBlockType'] as String?,
      folioBlockText: j['folioBlockText'] as String?,
      folioBlockChecked: j['folioBlockChecked'] as bool?,
      folioBlockPayload: j['folioBlockPayload'] as String?,
      visible: j['visible'] as bool? ?? true,
      locked: j['locked'] as bool? ?? false,
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0.0,
      groupId: j['groupId'] as String?,
      frameChildIds: rawFrame.map((e) => e as String).toList(),
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
    this.kind = FolioCanvasStrokeKind.ink,
    this.pressures,
  });

  final String id;
  final List<CanvasPoint> points;
  final String color;
  final double strokeWidth;
  final FolioCanvasStrokeKind kind;

  /// Presión normalizada 0–1 por punto (opcional, stylus)
  final List<double>? pressures;

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points.map((p) => p.toJson()).toList(),
    'color': color,
    'strokeWidth': strokeWidth,
    'kind': kind.name,
    if (pressures != null && pressures!.isNotEmpty) 'pressures': pressures,
  };

  factory FolioCanvasStroke.fromJson(Map<String, dynamic> j) {
    final rawPoints = j['points'] as List? ?? [];
    final rawPressures = j['pressures'] as List?;
    return FolioCanvasStroke(
      id: j['id'] as String,
      points: rawPoints
          .map((p) => CanvasPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      color: j['color'] as String? ?? '#000000',
      strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      kind: FolioCanvasStrokeKind.values.firstWhere(
        (e) => e.name == (j['kind'] as String? ?? 'ink'),
        orElse: () => FolioCanvasStrokeKind.ink,
      ),
      pressures: rawPressures
          ?.map((p) => (p as num).toDouble())
          .toList(),
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
    this.cp1x,
    this.cp1y,
    this.cp2x,
    this.cp2y,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final CanvasEdgeStyle style;
  final String? color;

  /// Puntos de control Bezier cúbico (coordenadas lienzo); solo [bezier]
  final double? cp1x;
  final double? cp1y;
  final double? cp2x;
  final double? cp2y;

  FolioCanvasEdge copyWith({
    String? label,
    CanvasEdgeStyle? style,
    String? color,
    double? cp1x,
    double? cp1y,
    double? cp2x,
    double? cp2y,
  }) {
    return FolioCanvasEdge(
      id: id,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      label: label ?? this.label,
      style: style ?? this.style,
      color: color ?? this.color,
      cp1x: cp1x ?? this.cp1x,
      cp1y: cp1y ?? this.cp1y,
      cp2x: cp2x ?? this.cp2x,
      cp2y: cp2y ?? this.cp2y,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
    if (label.isNotEmpty) 'label': label,
    'style': style.name,
    if (color != null) 'color': color,
    if (cp1x != null) 'cp1x': cp1x,
    if (cp1y != null) 'cp1y': cp1y,
    if (cp2x != null) 'cp2x': cp2x,
    if (cp2y != null) 'cp2y': cp2y,
  };

  factory FolioCanvasEdge.fromJson(Map<String, dynamic> j) {
    return FolioCanvasEdge(
      id: j['id'] as String,
      fromNodeId: j['fromNodeId'] as String,
      toNodeId: j['toNodeId'] as String,
      label: j['label'] as String? ?? '',
      style: CanvasEdgeStyle.values.firstWhere(
        (e) => e.name == (j['style'] as String? ?? 'arrow'),
        orElse: () => CanvasEdgeStyle.arrow,
      ),
      color: j['color'] as String?,
      cp1x: (j['cp1x'] as num?)?.toDouble(),
      cp1y: (j['cp1y'] as num?)?.toDouble(),
      cp2x: (j['cp2x'] as num?)?.toDouble(),
      cp2y: (j['cp2y'] as num?)?.toDouble(),
    );
  }
}

// ─── Datos completos del canvas ───────────────────────────────────────────────

class FolioCanvasData {
  FolioCanvasData({
    required this.nodes,
    required this.edges,
    required this.strokes,
    this.groups = const [],
    this.viewportX = 0.0,
    this.viewportY = 0.0,
    this.viewportScale = 1.0,
    this.collabContentVersion = 0,
  });

  final List<FolioCanvasNode> nodes;
  final List<FolioCanvasEdge> edges;
  final List<FolioCanvasStroke> strokes;
  final List<FolioCanvasGroup> groups;
  final double viewportX;
  final double viewportY;
  final double viewportScale;

  /// Versión opaca para fusionar remotos sin pisar debounce local (opcional)
  final int collabContentVersion;

  static FolioCanvasData defaults() => FolioCanvasData(
    nodes: [],
    edges: [],
    strokes: [],
    groups: [],
    viewportX: 0.0,
    viewportY: 0.0,
    viewportScale: 1.0,
  );

  String encode() => jsonEncode({
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
    'strokes': strokes.map((s) => s.toJson()).toList(),
    if (groups.isNotEmpty) 'groups': groups.map((g) => g.toJson()).toList(),
    'viewportX': viewportX,
    'viewportY': viewportY,
    'viewportScale': viewportScale,
    if (collabContentVersion != 0) 'collabContentVersion': collabContentVersion,
  });

  static FolioCanvasData? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final rawNodes = j['nodes'] as List? ?? [];
      final rawEdges = j['edges'] as List? ?? [];
      final rawStrokes = j['strokes'] as List? ?? [];
      final rawGroups = j['groups'] as List? ?? [];
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
        groups: rawGroups
            .map((g) => FolioCanvasGroup.fromJson(g as Map<String, dynamic>))
            .toList(),
        viewportX: (j['viewportX'] as num?)?.toDouble() ?? 0.0,
        viewportY: (j['viewportY'] as num?)?.toDouble() ?? 0.0,
        viewportScale: (j['viewportScale'] as num?)?.toDouble() ?? 1.0,
        collabContentVersion: (j['collabContentVersion'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  FolioCanvasData copyWith({
    List<FolioCanvasNode>? nodes,
    List<FolioCanvasEdge>? edges,
    List<FolioCanvasStroke>? strokes,
    List<FolioCanvasGroup>? groups,
    double? viewportX,
    double? viewportY,
    double? viewportScale,
    int? collabContentVersion,
  }) {
    return FolioCanvasData(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      strokes: strokes ?? this.strokes,
      groups: groups ?? this.groups,
      viewportX: viewportX ?? this.viewportX,
      viewportY: viewportY ?? this.viewportY,
      viewportScale: viewportScale ?? this.viewportScale,
      collabContentVersion: collabContentVersion ?? this.collabContentVersion,
    );
  }
}
