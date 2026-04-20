import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_canvas_data.dart';
import '../editor/block_editor_support_widgets.dart';
import '../editor/block_type_catalog.dart';
import 'canvas_edge_painter.dart';
import 'canvas_node_widget.dart';

const _uuid = Uuid();

/// Motor principal del lienzo infinito de Folio.
///
/// Soporta:
/// - Pan & zoom ilimitados via [InteractiveViewer]
/// - Notas de texto, formas geométricas y nodos de imagen
/// - Conectores/flechas entre nodos
/// - Dibujo libre (strokes)
/// - Persiste cambios con debounce de 500 ms
class FolioCanvasBoard extends StatefulWidget {
  const FolioCanvasBoard({
    super.key,
    required this.initialData,
    required this.onDataChanged,
    required this.onOpenClassicEditor,
  });

  final FolioCanvasData initialData;
  final ValueChanged<FolioCanvasData> onDataChanged;
  final VoidCallback onOpenClassicEditor;

  @override
  State<FolioCanvasBoard> createState() => _FolioCanvasBoardState();
}

class _FolioCanvasBoardState extends State<FolioCanvasBoard> {
  late FolioCanvasData _data;

  CanvasMode _mode = CanvasMode.select;
  String? _selectedNodeId;
  String? _connectFromNodeId;

  // Dibujo libre
  List<Offset> _currentStrokePoints = [];
  bool _isDrawing = false;
  Color _drawColor = Colors.black;
  double _drawWidth = 2.5;

  // Color de nuevos nodos/formas
  Color _nodeColor = const Color(0xFFFFF9C4); // amarillo suave

  final _transformController = TransformationController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    // Restaurar viewport
    final m = Matrix4.identity()
      ..scale(_data.viewportScale, _data.viewportScale, 1.0)
      ..setTranslationRaw(
        _data.viewportX * _data.viewportScale,
        _data.viewportY * _data.viewportScale,
        0,
      );
    _transformController.value = m;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  // ─── Persistencia ─────────────────────────────────────────────────────────

  void _persist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final m = _transformController.value;
      final scale = m.getMaxScaleOnAxis();
      final tx = m.getTranslation().x / scale;
      final ty = m.getTranslation().y / scale;
      widget.onDataChanged(
        _data.copyWith(viewportX: tx, viewportY: ty, viewportScale: scale),
      );
    });
  }

  void _update(FolioCanvasData newData) {
    setState(() => _data = newData);
    _persist();
  }

  // ─── Acciones sobre nodos ─────────────────────────────────────────────────

  void _addNote(Offset canvasPos) {
    final node = FolioCanvasNode(
      id: _uuid.v4(),
      type: CanvasNodeType.text,
      x: canvasPos.dx,
      y: canvasPos.dy,
      width: 200,
      height: 120,
      color:
          '#${_nodeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
    );
    _update(_data.copyWith(nodes: [..._data.nodes, node]));
    setState(() {
      _selectedNodeId = node.id;
      _mode = CanvasMode.select;
    });
  }

  void _addShape(Offset canvasPos) {
    final node = FolioCanvasNode(
      id: _uuid.v4(),
      type: CanvasNodeType.shape,
      x: canvasPos.dx,
      y: canvasPos.dy,
      width: 160,
      height: 100,
      shapeType: CanvasShapeType.rectangle,
      color:
          '#${_nodeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
    );
    _update(_data.copyWith(nodes: [..._data.nodes, node]));
    setState(() {
      _selectedNodeId = node.id;
      _mode = CanvasMode.select;
    });
  }

  Future<void> _addFolioBlockNode(
    BuildContext context,
    Offset canvasPos,
  ) async {
    // Capturar l10n antes del gap asíncrono
    final l10n = AppLocalizations.of(context);
    // Volver a select para que el GestureDetector no interfiera con el dialog
    setState(() => _mode = CanvasMode.select);
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BlockTypePickerSheet(),
    );
    if (type == null || !mounted) return;
    // Excluir el propio bloque canvas para evitar recursión
    if (type == 'canvas') return;
    final label = blockTypeLabelForKey(type, l10n);
    final node = FolioCanvasNode(
      id: _uuid.v4(),
      type: CanvasNodeType.folioBlock,
      x: canvasPos.dx,
      y: canvasPos.dy,
      width: 260,
      height: 140,
      folioBlockType: type,
      folioBlockText: label,
    );
    _update(_data.copyWith(nodes: [..._data.nodes, node]));
    setState(() => _selectedNodeId = node.id);
  }

  void _deleteNode(String id) {
    _update(
      _data.copyWith(
        nodes: _data.nodes.where((n) => n.id != id).toList(),
        edges: _data.edges
            .where((e) => e.fromNodeId != id && e.toNodeId != id)
            .toList(),
      ),
    );
    setState(() {
      if (_selectedNodeId == id) _selectedNodeId = null;
    });
  }

  void _moveNode(String id, Offset delta) {
    final nodes = _data.nodes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(x: n.x + delta.dx, y: n.y + delta.dy);
    }).toList();
    _update(_data.copyWith(nodes: nodes));
  }

  void _editNodeText(String id, String newText) {
    final nodes = _data.nodes.map((n) {
      if (n.id != id) return n;
      if (n.type == CanvasNodeType.folioBlock) {
        return n.copyWith(folioBlockText: newText);
      }
      return n.copyWith(text: newText);
    }).toList();
    _update(_data.copyWith(nodes: nodes));
  }

  void _toggleNodeChecked(String id) {
    final nodes = _data.nodes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(folioBlockChecked: !(n.folioBlockChecked ?? false));
    }).toList();
    _update(_data.copyWith(nodes: nodes));
  }

  void _handleConnectFrom(String fromId) {
    if (_connectFromNodeId == null) {
      setState(() => _connectFromNodeId = fromId);
    } else if (_connectFromNodeId != fromId) {
      final edge = FolioCanvasEdge(
        id: _uuid.v4(),
        fromNodeId: _connectFromNodeId!,
        toNodeId: fromId,
        style: CanvasEdgeStyle.arrow,
      );
      _update(_data.copyWith(edges: [..._data.edges, edge]));
      setState(() {
        _connectFromNodeId = null;
        _mode = CanvasMode.select;
      });
    }
  }

  // ─── Dibujo libre ─────────────────────────────────────────────────────────

  double get _viewportScale => _transformController.value.getMaxScaleOnAxis();

  void _onDrawStart(DragStartDetails d) {
    if (_mode != CanvasMode.draw) return;
    setState(() {
      _isDrawing = true;
      _currentStrokePoints = [d.localPosition];
    });
  }

  void _onDrawUpdate(DragUpdateDetails d) {
    if (!_isDrawing) return;
    setState(() {
      _currentStrokePoints = [..._currentStrokePoints, d.localPosition];
    });
  }

  void _onDrawEnd(DragEndDetails d) {
    if (!_isDrawing || _currentStrokePoints.isEmpty) return;
    final stroke = FolioCanvasStroke(
      id: _uuid.v4(),
      points: _currentStrokePoints.map((p) => CanvasPoint(p.dx, p.dy)).toList(),
      color:
          '#${_drawColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      strokeWidth: _drawWidth,
    );
    _update(_data.copyWith(strokes: [..._data.strokes, stroke]));
    setState(() {
      _isDrawing = false;
      _currentStrokePoints = [];
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Stack(
        children: [
          // ── Lienzo infinito ───────────────────────────────────────────────
          InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 5.0,
            panEnabled: _mode == CanvasMode.select,
            scaleEnabled: true,
            onInteractionUpdate: (_) => _persist(),
            child: GestureDetector(
              // En modo dibujo: captura pan (localPosition ya es canvas)
              onPanStart: _mode == CanvasMode.draw ? _onDrawStart : null,
              onPanUpdate: _mode == CanvasMode.draw ? _onDrawUpdate : null,
              onPanEnd: _mode == CanvasMode.draw ? _onDrawEnd : null,
              onTapUp: (details) {
                // localPosition ya está en coordenadas del canvas
                final p = details.localPosition;
                if (_mode == CanvasMode.addNote) {
                  _addNote(p);
                } else if (_mode == CanvasMode.addShape) {
                  _addShape(p);
                } else if (_mode == CanvasMode.addFolioBlock) {
                  _addFolioBlockNode(context, p);
                } else {
                  setState(() => _selectedNodeId = null);
                }
              },
              child: SizedBox(
                width: 10000,
                height: 10000,
                child: Stack(
                  children: [
                    // Fondo cuadriculado
                    CustomPaint(
                      size: const Size(10000, 10000),
                      painter: _GridPainter(scheme: scheme),
                    ),
                    // Edges
                    CustomPaint(
                      size: const Size(10000, 10000),
                      painter: CanvasEdgePainter(
                        edges: _data.edges,
                        nodes: _data.nodes,
                      ),
                    ),
                    // Strokes guardados
                    CustomPaint(
                      size: const Size(10000, 10000),
                      painter: _StrokesPainter(strokes: _data.strokes),
                    ),
                    // Stroke en curso
                    if (_isDrawing && _currentStrokePoints.isNotEmpty)
                      CustomPaint(
                        size: const Size(10000, 10000),
                        painter: _LiveStrokePainter(
                          points: _currentStrokePoints,
                          color: _drawColor,
                          width: _drawWidth,
                        ),
                      ),
                    // Nodos
                    for (final node in _data.nodes)
                      Positioned(
                        left: node.x,
                        top: node.y,
                        width: node.width,
                        height: node.height,
                        child: CanvasNodeWidget(
                          key: ValueKey(node.id),
                          node: node,
                          isSelected: _selectedNodeId == node.id,
                          mode: _mode,
                          viewportScale: _viewportScale,
                          onTap: () =>
                              setState(() => _selectedNodeId = node.id),
                          onDragDelta: (delta) => _moveNode(node.id, delta),
                          onEditText: (text) => _editNodeText(node.id, text),
                          onToggleChecked: () => _toggleNodeChecked(node.id),
                          onDelete: () => _deleteNode(node.id),
                          onConnectFrom: () => _handleConnectFrom(node.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Barra de herramientas flotante ────────────────────────────────
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _CanvasToolbar(
                mode: _mode,
                drawColor: _drawColor,
                nodeColor: _nodeColor,
                onModeChanged: (m) => setState(() {
                  _mode = m;
                  if (m != CanvasMode.connect) _connectFromNodeId = null;
                }),
                onDrawColorChanged: (c) => setState(() => _drawColor = c),
                onNodeColorChanged: (c) => setState(() => _nodeColor = c),
                onOpenClassicEditor: widget.onOpenClassicEditor,
                onClearStrokes: () => _update(_data.copyWith(strokes: [])),
                l10n: l10n,
                scheme: scheme,
              ),
            ),
          ),

          // ── Indicador de conexión ─────────────────────────────────────────
          if (_connectFromNodeId != null)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Toca el nodo de destino para conectar',
                      style: TextStyle(color: scheme.onInverseSurface),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Toolbar ─────────────────────────────────────────────────────────────────

class _CanvasToolbar extends StatelessWidget {
  const _CanvasToolbar({
    required this.mode,
    required this.drawColor,
    required this.nodeColor,
    required this.onModeChanged,
    required this.onDrawColorChanged,
    required this.onNodeColorChanged,
    required this.onOpenClassicEditor,
    required this.onClearStrokes,
    required this.l10n,
    required this.scheme,
  });

  final CanvasMode mode;
  final Color drawColor;
  final Color nodeColor;
  final ValueChanged<CanvasMode> onModeChanged;
  final ValueChanged<Color> onDrawColorChanged;
  final ValueChanged<Color> onNodeColorChanged;
  final VoidCallback onOpenClassicEditor;
  final VoidCallback onClearStrokes;
  final AppLocalizations l10n;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolBtn(
              icon: Icons.pan_tool_alt_outlined,
              label: l10n.canvasToolbarSelect,
              active: mode == CanvasMode.select,
              onTap: () => onModeChanged(CanvasMode.select),
            ),
            _ToolBtn(
              icon: Icons.sticky_note_2_outlined,
              label: l10n.canvasToolbarAddNode,
              active: mode == CanvasMode.addNote,
              onTap: () => onModeChanged(CanvasMode.addNote),
            ),
            _ToolBtn(
              icon: Icons.crop_square_rounded,
              label: l10n.canvasToolbarAddShape,
              active: mode == CanvasMode.addShape,
              onTap: () => onModeChanged(CanvasMode.addShape),
            ),
            _ToolBtn(
              icon: Icons.gesture_rounded,
              label: l10n.canvasToolbarDraw,
              active: mode == CanvasMode.draw,
              onTap: () => onModeChanged(CanvasMode.draw),
            ),
            _ToolBtn(
              icon: Icons.linear_scale_rounded,
              label: l10n.canvasToolbarConnect,
              active: mode == CanvasMode.connect,
              onTap: () => onModeChanged(CanvasMode.connect),
            ),
            _ToolBtn(
              icon: Icons.widgets_outlined,
              label: l10n.canvasToolbarAddBlock,
              active: mode == CanvasMode.addFolioBlock,
              onTap: () => onModeChanged(CanvasMode.addFolioBlock),
            ),
            const VerticalDivider(width: 16, indent: 4, endIndent: 4),
            _ColorDot(
              color: mode == CanvasMode.draw ? drawColor : nodeColor,
              onChanged: mode == CanvasMode.draw
                  ? onDrawColorChanged
                  : onNodeColorChanged,
            ),
            const VerticalDivider(width: 16, indent: 4, endIndent: 4),
            Tooltip(
              message: l10n.canvasToolbarOpenEditor,
              child: IconButton(
                icon: const Icon(Icons.edit_note_rounded),
                iconSize: 20,
                onPressed: onOpenClassicEditor,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  static const _palette = [
    Color(0xFFFFF9C4), // amarillo
    Color(0xFFC8E6C9), // verde
    Color(0xFFBBDEFB), // azul
    Color(0xFFFFCCBC), // naranja
    Color(0xFFE1BEE7), // morado
    Color(0xFFF8BBD9), // rosa
    Color(0xFFFFFFFF), // blanco
    Color(0xFF212121), // negro
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      tooltip: 'Color',
      offset: const Offset(0, 40),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            children: _palette
                .map(
                  (c) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onChanged(c);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c == color
                              ? Colors.blue
                              : Colors.grey.shade300,
                          width: c == color ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400),
        ),
      ),
    );
  }
}

// ─── Pintores auxiliares ──────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.scheme});
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => false;
}

class _StrokesPainter extends CustomPainter {
  const _StrokesPainter({required this.strokes});
  final List<FolioCanvasStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final hex = stroke.color.replaceAll('#', '');
      final v = int.tryParse(hex, radix: 16);
      final color = v != null
          ? Color(hex.length == 6 ? (0xFF000000 | v) : v)
          : Colors.black;
      final paint = Paint()
        ..color = color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      // Acceso interno: FolioCanvasStroke.points son _CanvasPoint pero con dx/dy
      // Usamos el hecho de que _StrokesPainter usa la API pública del modelo
      final pts = stroke.points;
      if (pts.isEmpty) continue;
      // _CanvasPoint no es pública, la accedemos via toJson round-trip no es viable.
      // En su lugar usamos la reflexión por acceso al campo public vía duck typing.
      // Como workaround correcto: haremos encode→decode del stroke para obtener Offsets.
      final json = stroke.toJson();
      final rawPts = json['points'] as List;
      if (rawPts.isEmpty) continue;
      final first = rawPts.first as Map<String, dynamic>;
      path.moveTo(
        (first['x'] as num).toDouble(),
        (first['y'] as num).toDouble(),
      );
      for (final rp in rawPts.skip(1)) {
        final mp = rp as Map<String, dynamic>;
        path.lineTo((mp['x'] as num).toDouble(), (mp['y'] as num).toDouble());
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter old) => old.strokes != strokes;
}

class _LiveStrokePainter extends CustomPainter {
  const _LiveStrokePainter({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiveStrokePainter old) => true;
}

// Shim público para pasar puntos al stroke eliminado — se usa CanvasPoint directamente.
