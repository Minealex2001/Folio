import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_canvas_data.dart';
import '../../../services/platform/browser_file_download.dart';
import '../editor/block_editor_support_widgets.dart';
import '../editor/block_type_catalog.dart';
import 'canvas_edge_painter.dart';
import 'canvas_export.dart';
import 'canvas_layers_panel.dart';
import 'canvas_node_widget.dart';
import 'canvas_snap.dart';
import 'canvas_template_labels.dart';
import 'canvas_templates.dart';

const _uuid = Uuid();
const _maxUndo = 48;

/// Motor principal del lienzo infinito de Folio.
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
  final Set<String> _selectedNodeIds = {};
  String? _connectFromNodeId;
  String? _selectedEdgeId;

  bool _snapEnabled = true;
  FolioCanvasStrokeKind _drawKind = FolioCanvasStrokeKind.ink;
  final List<double> _currentPressures = [];

  List<Offset> _currentStrokePoints = [];
  bool _isDrawing = false;
  Color _drawColor = Colors.black;
  final double _drawWidth = 2.5;

  Color _nodeColor = const Color(0xFFFFF9C4);

  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  bool _suppressNextSelectionClear = false;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  final _transformController = TransformationController();
  Timer? _debounce;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    final m = Matrix4.diagonal3Values(
      _data.viewportScale,
      _data.viewportScale,
      1.0,
    )..setTranslationRaw(
        _data.viewportX * _data.viewportScale,
        _data.viewportY * _data.viewportScale,
        0,
      );
    _transformController.value = m;
  }

  @override
  void didUpdateWidget(covariant FolioCanvasBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData.encode() != oldWidget.initialData.encode()) {
      setState(() {
        _data = widget.initialData;
        _selectedNodeIds.clear();
        _selectedEdgeId = null;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _transformController.dispose();
    super.dispose();
  }

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

  void _pushUndo() {
    _undoStack.add(_data.encode());
    if (_undoStack.length > _maxUndo) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _update(FolioCanvasData newData, {bool recordUndo = false}) {
    if (recordUndo) _pushUndo();
    setState(() => _data = newData);
    _persist();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_data.encode());
    final prev = _undoStack.removeLast();
    final parsed = FolioCanvasData.tryParse(prev);
    if (parsed != null) {
      setState(() {
        _data = parsed;
        _selectedNodeIds.clear();
        _selectedEdgeId = null;
      });
      _persist();
    }
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_data.encode());
    final next = _redoStack.removeLast();
    final parsed = FolioCanvasData.tryParse(next);
    if (parsed != null) {
      setState(() {
        _data = parsed;
        _selectedNodeIds.clear();
        _selectedEdgeId = null;
      });
      _persist();
    }
  }

  double get _viewportScale => _transformController.value.getMaxScaleOnAxis();

  Map<String, FolioCanvasNode> get _nodeById =>
      {for (final n in _data.nodes) n.id: n};

  Set<String> _expandMoveIds(Set<String> raw) {
    final out = <String>{};
    for (final id in raw) {
      final n = _nodeById[id];
      if (n == null || n.locked) continue;
      final gid = n.groupId;
      if (gid != null) {
        for (final o in _data.nodes) {
          if (o.groupId == gid && !o.locked) out.add(o.id);
        }
      } else {
        out.add(id);
      }
    }
    return out;
  }

  void _onNodeTap(String id, {required bool shift}) {
    if (_mode == CanvasMode.marquee) return;
    setState(() {
      _selectedEdgeId = null;
      if (shift) {
        if (_selectedNodeIds.contains(id)) {
          _selectedNodeIds.remove(id);
        } else {
          _selectedNodeIds.add(id);
        }
      } else {
        _selectedNodeIds
          ..clear()
          ..add(id);
      }
    });
  }

  void _clearNodeSelection() {
    setState(() {
      _selectedNodeIds.clear();
      _selectedEdgeId = null;
    });
  }

  void _moveNodes(Set<String> ids, Offset delta, {bool recordUndo = false}) {
    if (ids.isEmpty) return;
    if (recordUndo) _pushUndo();
    Offset d = delta;
    if (_snapEnabled) {
      if (ids.length == 1) {
        final id = ids.first;
        final n = _nodeById[id]!;
        final r = snapNodeMove(
          node: n,
          proposedDelta: delta,
          allNodes: _data.nodes,
          excludeIds: ids,
        );
        d = r.delta;
      } else {
        final movers = _data.nodes.where((e) => ids.contains(e.id)).toList();
        final r = snapGroupMove(
          moving: movers,
          proposedDelta: delta,
          allNodes: _data.nodes,
          movingIds: ids,
        );
        d = r.delta;
      }
    }
    final nodes = _data.nodes.map((n) {
      if (!ids.contains(n.id)) return n;
      return n.copyWith(x: n.x + d.dx, y: n.y + d.dy);
    }).toList();
    _update(_data.copyWith(nodes: nodes), recordUndo: false);
  }

  void _onDragNode(String id, Offset delta) {
    if (_nodeById[id]?.locked == true) return;
    final toMove = _expandMoveIds(
      _selectedNodeIds.contains(id) ? _selectedNodeIds : {id},
    );
    _moveNodes(toMove, delta, recordUndo: false);
  }

  void _beginNodeDragUndo() {
    _pushUndo();
  }

  FolioCanvasData _removeNodesAndRepairGroups(Set<String> removeIds) {
    var nodes = _data.nodes.where((n) => !removeIds.contains(n.id)).toList();
    final groupCounts = <String, int>{};
    for (final n in nodes) {
      final g = n.groupId;
      if (g != null) groupCounts[g] = (groupCounts[g] ?? 0) + 1;
    }
    nodes = nodes.map((n) {
      final g = n.groupId;
      if (g != null && (groupCounts[g] ?? 0) < 2) {
        return n.copyWith(groupId: null);
      }
      return n;
    }).toList();
    final groups = _data.groups
        .where((g) => (groupCounts[g.id] ?? 0) >= 2)
        .map(
          (g) => g.copyWith(
            childNodeIds: g.childNodeIds.where((id) => !removeIds.contains(id)).toList(),
          ),
        )
        .where((g) => g.childNodeIds.length >= 2)
        .toList();
    return _data.copyWith(
      nodes: nodes,
      groups: groups,
      edges: _data.edges
          .where(
            (e) =>
                !removeIds.contains(e.fromNodeId) && !removeIds.contains(e.toNodeId),
          )
          .toList(),
    );
  }

  void _deleteNode(String id) {
    _pushUndo();
    _update(_removeNodesAndRepairGroups({id}), recordUndo: false);
    setState(() => _selectedNodeIds.remove(id));
  }

  void _deleteSelection() {
    if (_selectedNodeIds.isEmpty) return;
    _pushUndo();
    final remove = Set<String>.from(_selectedNodeIds);
    _update(_removeNodesAndRepairGroups(remove), recordUndo: false);
    _selectedNodeIds.clear();
  }

  void _groupSelection() {
    if (_selectedNodeIds.length < 2) return;
    _pushUndo();
    final gid = _uuid.v4();
    final childIds = _selectedNodeIds.toList();
    final group = FolioCanvasGroup(id: gid, childNodeIds: childIds);
    final nodes = _data.nodes.map((n) {
      if (_selectedNodeIds.contains(n.id)) {
        return n.copyWith(groupId: gid);
      }
      return n;
    }).toList();
    _update(
      _data.copyWith(nodes: nodes, groups: [..._data.groups, group]),
      recordUndo: false,
    );
  }

  void _ungroupSelection() {
    if (_selectedNodeIds.isEmpty) return;
    _pushUndo();
    final gids = _selectedNodeIds
        .map((id) => _nodeById[id]?.groupId)
        .whereType<String>()
        .toSet();
    final nodes = _data.nodes.map((n) {
      if (n.groupId != null && gids.contains(n.groupId)) {
        return n.copyWith(groupId: null);
      }
      return n;
    }).toList();
    final groups = _data.groups.where((g) => !gids.contains(g.id)).toList();
    _update(_data.copyWith(nodes: nodes, groups: groups), recordUndo: false);
  }

  void _rotateSelection15() {
    if (_selectedNodeIds.length != 1) return;
    final id = _selectedNodeIds.first;
    _pushUndo();
    final nodes = _data.nodes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(rotation: n.rotation + math.pi / 12);
    }).toList();
    _update(_data.copyWith(nodes: nodes), recordUndo: false);
  }

  void _resizeNodeBr(String id, Offset delta) {
    if (_selectedNodeIds.length != 1 || !_selectedNodeIds.contains(id)) return;
    final nodes = _data.nodes.map((n) {
      if (n.id != id) return n;
      final nw = math.max(48.0, n.width + delta.dx / _viewportScale);
      final nh = math.max(48.0, n.height + delta.dy / _viewportScale);
      return n.copyWith(width: nw, height: nh);
    }).toList();
    _update(_data.copyWith(nodes: nodes), recordUndo: false);
  }

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
    _update(_data.copyWith(nodes: [..._data.nodes, node]), recordUndo: true);
    setState(() {
      _selectedNodeIds
        ..clear()
        ..add(node.id);
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
    _update(_data.copyWith(nodes: [..._data.nodes, node]), recordUndo: true);
    setState(() {
      _selectedNodeIds
        ..clear()
        ..add(node.id);
      _mode = CanvasMode.select;
    });
  }

  void _addFrame(Offset canvasPos, AppLocalizations l10n) {
    final node = FolioCanvasNode(
      id: _uuid.v4(),
      type: CanvasNodeType.frame,
      x: canvasPos.dx,
      y: canvasPos.dy,
      width: 420,
      height: 300,
      text: l10n.canvasFrameLabel,
      color: '#00000000',
    );
    _update(_data.copyWith(nodes: [..._data.nodes, node]), recordUndo: true);
    setState(() {
      _selectedNodeIds
        ..clear()
        ..add(node.id);
      _mode = CanvasMode.select;
    });
  }

  Future<void> _addFolioBlockNode(BuildContext context, Offset canvasPos) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _mode = CanvasMode.select);
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BlockTypePickerSheet(),
    );
    if (type == null || !mounted) return;
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
    _update(_data.copyWith(nodes: [..._data.nodes, node]), recordUndo: true);
    setState(() {
      _selectedNodeIds
        ..clear()
        ..add(node.id);
    });
  }

  void _editNodeText(String id, String newText) {
    final nodes = _data.nodes.map((n) {
      if (n.id != id) return n;
      if (n.type == CanvasNodeType.folioBlock) {
        return n.copyWith(folioBlockText: newText);
      }
      return n.copyWith(text: newText);
    }).toList();
    _update(_data.copyWith(nodes: nodes), recordUndo: true);
  }

  void _toggleNodeChecked(String id) {
    final nodes = _data.nodes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(folioBlockChecked: !(n.folioBlockChecked ?? false));
    }).toList();
    _update(_data.copyWith(nodes: nodes), recordUndo: true);
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
      _update(_data.copyWith(edges: [..._data.edges, edge]), recordUndo: true);
      setState(() {
        _connectFromNodeId = null;
        _mode = CanvasMode.select;
      });
    }
  }

  void _onDrawStart(DragStartDetails d) {
    if (_mode != CanvasMode.draw && _mode != CanvasMode.erase) return;
    if (_mode == CanvasMode.erase) {
      setState(() {
        _isDrawing = true;
        _currentStrokePoints = [d.localPosition];
      });
      return;
    }
    setState(() {
      _isDrawing = true;
      _currentStrokePoints = [d.localPosition];
      _currentPressures.clear();
    });
  }

  void _onDrawUpdate(DragUpdateDetails d) {
    if (!_isDrawing) return;
    setState(() {
      _currentStrokePoints = [..._currentStrokePoints, d.localPosition];
    });
  }

  void _onDrawEnd(DragEndDetails d) {
    if (!_isDrawing) return;
    if (_mode == CanvasMode.erase) {
      _eraseAtStroke(_currentStrokePoints);
      setState(() {
        _isDrawing = false;
        _currentStrokePoints = [];
      });
      return;
    }
    if (_mode != CanvasMode.draw || _currentStrokePoints.isEmpty) return;
    final stroke = FolioCanvasStroke(
      id: _uuid.v4(),
      points: _currentStrokePoints.map((p) => CanvasPoint(p.dx, p.dy)).toList(),
      color:
          '#${_drawColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      strokeWidth: _drawWidth,
      kind: _drawKind,
      pressures: _currentPressures.isEmpty ? null : List<double>.from(_currentPressures),
    );
    _update(_data.copyWith(strokes: [..._data.strokes, stroke]), recordUndo: true);
    setState(() {
      _isDrawing = false;
      _currentStrokePoints = [];
      _currentPressures.clear();
    });
  }

  void _eraseAtStroke(List<Offset> path) {
    if (path.isEmpty) return;
    const r = 28.0;
    bool near(Offset p, FolioCanvasStroke s) {
      for (var i = 0; i < s.points.length - 1; i++) {
        final a = Offset(s.points[i].x, s.points[i].y);
        final b = Offset(s.points[i + 1].x, s.points[i + 1].y);
        if (_distPointToSegment(p, a, b) < r) return true;
      }
      return false;
    }

    bool strokeHit(FolioCanvasStroke s) {
      for (final p in path) {
        if (near(p, s)) return true;
      }
      return false;
    }

    final kept = _data.strokes.where((s) => !strokeHit(s)).toList();
    if (kept.length != _data.strokes.length) {
      _update(_data.copyWith(strokes: kept), recordUndo: true);
    }
  }

  double _distPointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t = ab.dx * ab.dx + ab.dy * ab.dy < 1e-12
        ? 0.0
        : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy)).clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  void _finishMarquee() {
    if (_marqueeStart == null || _marqueeEnd == null) return;
    final rect = _normalizeMarqueeRect(Rect.fromPoints(_marqueeStart!, _marqueeEnd!));
    final picked = <String>{};
    for (final n in _data.nodes) {
      if (!n.visible) continue;
      final nr = Rect.fromLTWH(n.x, n.y, n.width, n.height);
      if (rect.overlaps(nr)) picked.add(n.id);
    }
    setState(() {
      _selectedNodeIds
        ..clear()
        ..addAll(picked);
      _marqueeStart = null;
      _marqueeEnd = null;
      _mode = CanvasMode.select;
      _suppressNextSelectionClear = true;
    });
  }

  Future<void> _export(
    BuildContext context,
    AppLocalizations l10n, {
    required String format,
  }) async {
    try {
      Uint8List? bytes;
      String ext;
      switch (format) {
        case 'png':
          bytes = await canvasToPngBytes(_data);
          ext = 'png';
        case 'svg':
          final svg = canvasToSvgString(_data);
          bytes = Uint8List.fromList(utf8.encode(svg));
          ext = 'svg';
        case 'pdf':
          bytes = await canvasToPdfBytes(_data);
          ext = 'pdf';
        default:
          return;
      }
      if (bytes == null) throw Exception('export');
      final name = 'folio-canvas.$ext';
      if (kIsWeb) {
        folioTriggerBrowserDownload(name, bytes);
      } else {
        final path = await FilePicker.saveFile(
          dialogTitle: l10n.canvasToolbarExport,
          fileName: name,
          type: FileType.custom,
          allowedExtensions: [ext],
        );
        if (path != null) {
          await File(path).writeAsBytes(bytes);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.canvasExportSuccess)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.canvasExportError)),
        );
      }
    }
  }

  void _applyTemplate(BuildContext context, CanvasBuiltInTemplate t) {
    final l10n = AppLocalizations.of(context);
    final labels = CanvasTemplateLabels.fromL10n(l10n);
    final extra = canvasTemplateData(t, labels);
    _update(mergeCanvasTemplate(_data, extra), recordUndo: true);
    Navigator.pop(context);
  }

  void _showTemplatePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(title: Text(l10n.canvasTemplateDialogTitle)),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(l10n.canvasTemplateMindmap),
              onTap: () => _applyTemplate(ctx, CanvasBuiltInTemplate.mindmap),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(l10n.canvasTemplateFlowchart),
              onTap: () => _applyTemplate(ctx, CanvasBuiltInTemplate.flowchart),
            ),
            ListTile(
              leading: const Icon(Icons.route_outlined),
              title: Text(l10n.canvasTemplateUserJourney),
              onTap: () => _applyTemplate(ctx, CanvasBuiltInTemplate.userJourney),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: Text(l10n.canvasTemplateSwot),
              onTap: () => _applyTemplate(ctx, CanvasBuiltInTemplate.swot),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.canvasTemplateMergeHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEdgeEditor(BuildContext context, FolioCanvasEdge edge) {
    final l10n = AppLocalizations.of(context);
    final labelCtrl = TextEditingController(text: edge.label);
    CanvasEdgeStyle style = edge.style;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(l10n.canvasEdgeInspector),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CanvasEdgeStyle>(
                key: ValueKey(style),
                initialValue: style,
                items: [
                  DropdownMenuItem(value: CanvasEdgeStyle.straight, child: Text(l10n.canvasEdgeStyleStraight)),
                  DropdownMenuItem(value: CanvasEdgeStyle.arrow, child: Text(l10n.canvasEdgeStyleArrow)),
                  DropdownMenuItem(value: CanvasEdgeStyle.curve, child: Text(l10n.canvasEdgeStyleCurve)),
                  DropdownMenuItem(value: CanvasEdgeStyle.bezier, child: Text(l10n.canvasEdgeStyleBezier)),
                ],
                onChanged: (v) {
                  if (v != null) setSt(() => style = v);
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: l10n.canvasEdgeLabelHint),
                controller: labelCtrl,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            FilledButton(
              onPressed: () {
                _pushUndo();
                final edges = _data.edges.map((e) {
                  if (e.id != edge.id) return e;
                  return e.copyWith(style: style, label: labelCtrl.text);
                }).toList();
                _update(_data.copyWith(edges: edges), recordUndo: false);
                Navigator.pop(ctx);
              },
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _reorderLayers(int oldI, int newI) {
    if (newI > oldI) newI--;
    _pushUndo();
    final disp = _data.nodes.reversed.toList();
    final item = disp.removeAt(oldI);
    disp.insert(newI, item);
    _update(_data.copyWith(nodes: disp.reversed.toList()), recordUndo: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 12,
      color: scheme.onSurface,
      backgroundColor: scheme.surface.withValues(alpha: 0.92),
    );

    final canvasStack = SizedBox(
      width: 10000,
      height: 10000,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(10000, 10000),
            painter: _GridPainter(scheme: scheme),
          ),
          CustomPaint(
            size: const Size(10000, 10000),
            painter: CanvasEdgePainter(
              edges: _data.edges,
              nodes: _data.nodes,
              selectedEdgeId: _selectedEdgeId,
              labelTextStyle: labelStyle,
            ),
          ),
          CustomPaint(
            size: const Size(10000, 10000),
            painter: _StrokesPainter(strokes: _data.strokes),
          ),
          if (_isDrawing && _currentStrokePoints.isNotEmpty && _mode == CanvasMode.draw)
            CustomPaint(
              size: const Size(10000, 10000),
              painter: _LiveStrokePainter(
                points: _currentStrokePoints,
                color: _drawColor.withValues(
                  alpha: _drawKind == FolioCanvasStrokeKind.highlighter ? 0.35 : 1,
                ),
                width: _drawWidth,
              ),
            ),
          if (_isDrawing && _currentStrokePoints.isNotEmpty && _mode == CanvasMode.erase)
            CustomPaint(
              size: const Size(10000, 10000),
              painter: _LiveStrokePainter(
                points: _currentStrokePoints,
                color: scheme.error.withValues(alpha: 0.35),
                width: 24,
              ),
            ),
          if (_marqueeStart != null && _marqueeEnd != null)
            CustomPaint(
              size: const Size(10000, 10000),
              painter: _MarqueePainter(
                a: _marqueeStart!,
                b: _marqueeEnd!,
                color: scheme.primary,
              ),
            ),
          for (final node in _data.nodes)
            Positioned(
              left: node.x,
              top: node.y,
              width: node.width,
              height: node.height,
              child: CanvasNodeWidget(
                key: ValueKey(node.id),
                node: node,
                isSelected: _selectedNodeIds.contains(node.id),
                mode: _mode,
                viewportScale: _viewportScale,
                onSelectTap: ({required bool shift}) => _onNodeTap(node.id, shift: shift),
                onDragStart: _beginNodeDragUndo,
                onDragDelta: (delta) => _onDragNode(node.id, delta),
                onEditText: (text) => _editNodeText(node.id, text),
                onToggleChecked: () => _toggleNodeChecked(node.id),
                onDelete: () => _deleteNode(node.id),
                onConnectFrom: () => _handleConnectFrom(node.id),
              ),
            ),
          if (_selectedNodeIds.length == 1)
            _ResizeCorner(
              node: _data.nodes.firstWhere((n) => _selectedNodeIds.contains(n.id)),
              viewportScale: _viewportScale,
              onResizeStart: _pushUndo,
              onResize: (d) => _resizeNodeBr(_selectedNodeIds.first, d),
            ),
        ],
      ),
    );

    return Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): const _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): const _RedoIntent(),
      },
      child: Actions(
        actions: {
          _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) {
            _undo();
            return null;
          }),
          _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) {
            _redo();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: scheme.surfaceContainerLowest,
            drawer: Drawer(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CanvasLayersPanel(
                      data: _data,
                      selectedIds: _selectedNodeIds,
                      onReorder: _reorderLayers,
                      onToggleVisible: (id) {
                        _update(
                          _data.copyWith(
                            nodes: _data.nodes
                                .map((e) => e.id == id ? e.copyWith(visible: !e.visible) : e)
                                .toList(),
                          ),
                          recordUndo: true,
                        );
                      },
                      onToggleLock: (id) {
                        _update(
                          _data.copyWith(
                            nodes: _data.nodes
                                .map((e) => e.id == id ? e.copyWith(locked: !e.locked) : e)
                                .toList(),
                          ),
                          recordUndo: true,
                        );
                      },
                      onSelect: (id) => setState(() {
                        _selectedNodeIds
                          ..clear()
                          ..add(id);
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 48, right: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(l10n.canvasEdgeInspector, style: Theme.of(context).textTheme.titleSmall),
                        ),
                        ..._data.edges.map(
                          (e) => ListTile(
                            dense: true,
                            title: Text(
                              e.label.isNotEmpty ? e.label : '${e.fromNodeId.substring(0, 4)}→${e.toNodeId.substring(0, 4)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: _selectedEdgeId == e.id,
                            onTap: () {
                              setState(() {
                                _selectedEdgeId = e.id;
                                _selectedNodeIds.clear();
                              });
                              _showEdgeEditor(context, e);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1,
                  maxScale: 5.0,
                  panEnabled: _mode == CanvasMode.select,
                  scaleEnabled: true,
                  onInteractionUpdate: (_) => _persist(),
                  child: Listener(
                    behavior: HitTestBehavior.deferToChild,
                    onPointerDown: (e) {
                      if (_mode == CanvasMode.draw &&
                          e.kind == PointerDeviceKind.stylus &&
                          e.pressure > 0) {
                        _currentPressures.add(e.pressure.clamp(0.0, 1.0));
                      }
                    },
                    onPointerMove: (e) {
                      if (_mode == CanvasMode.draw &&
                          e.down &&
                          e.kind == PointerDeviceKind.stylus &&
                          e.pressure > 0) {
                        _currentPressures.add(e.pressure.clamp(0.0, 1.0));
                      }
                    },
                    child: GestureDetector(
                    onPanStart: (d) {
                      if (_mode == CanvasMode.draw || _mode == CanvasMode.erase) {
                        _onDrawStart(d);
                      } else if (_mode == CanvasMode.marquee) {
                        setState(() {
                          _marqueeStart = d.localPosition;
                          _marqueeEnd = d.localPosition;
                        });
                      }
                    },
                    onPanUpdate: (d) {
                      if (_mode == CanvasMode.draw || _mode == CanvasMode.erase) {
                        _onDrawUpdate(d);
                      } else if (_mode == CanvasMode.marquee) {
                        setState(() => _marqueeEnd = d.localPosition);
                      }
                    },
                    onPanEnd: (d) {
                      if (_mode == CanvasMode.draw || _mode == CanvasMode.erase) {
                        _onDrawEnd(d);
                      } else if (_mode == CanvasMode.marquee) {
                        _finishMarquee();
                      }
                    },
                    onTapUp: (details) {
                      if (_suppressNextSelectionClear) {
                        _suppressNextSelectionClear = false;
                        return;
                      }
                      final p = details.localPosition;
                      if (_mode == CanvasMode.addNote) {
                        _addNote(p);
                      } else if (_mode == CanvasMode.addShape) {
                        _addShape(p);
                      } else if (_mode == CanvasMode.addFolioBlock) {
                        _addFolioBlockNode(context, p);
                      } else if (_mode == CanvasMode.addFrame) {
                        _addFrame(p, l10n);
                      } else if (_mode == CanvasMode.select || _mode == CanvasMode.marquee) {
                        _clearNodeSelection();
                      }
                    },
                    child: canvasStack,
                  ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _CanvasToolbar(
                      mode: _mode,
                      drawKind: _drawKind,
                      snapEnabled: _snapEnabled,
                      drawColor: _drawColor,
                      nodeColor: _nodeColor,
                      onModeChanged: (m) => setState(() {
                        _mode = m;
                        if (m != CanvasMode.connect) _connectFromNodeId = null;
                      }),
                      onDrawKindChanged: (k) => setState(() => _drawKind = k),
                      onSnapToggled: () => setState(() => _snapEnabled = !_snapEnabled),
                      onDrawColorChanged: (c) => setState(() => _drawColor = c),
                      onNodeColorChanged: (c) => setState(() => _nodeColor = c),
                      onOpenClassicEditor: widget.onOpenClassicEditor,
                      onClearStrokes: () => _update(_data.copyWith(strokes: []), recordUndo: true),
                      onOpenLayers: () => _scaffoldKey.currentState?.openDrawer(),
                      onGroup: _groupSelection,
                      onUngroup: _ungroupSelection,
                      onRotate: _rotateSelection15,
                      onDeleteSelection: _selectedNodeIds.isEmpty ? null : _deleteSelection,
                      onTemplate: () => _showTemplatePicker(context),
                      onExportPng: () => _export(context, l10n, format: 'png'),
                      onExportSvg: () => _export(context, l10n, format: 'svg'),
                      onExportPdf: () => _export(context, l10n, format: 'pdf'),
                      canGroup: _selectedNodeIds.length > 1,
                      canUngroup: _selectedNodeIds.isNotEmpty,
                      canRotate: _selectedNodeIds.length == 1,
                      l10n: l10n,
                      scheme: scheme,
                    ),
                  ),
                ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            l10n.canvasConnectTapTarget,
                            style: TextStyle(color: scheme.onInverseSurface),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_mode == CanvasMode.marquee)
                  Positioned(
                    bottom: 72,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(l10n.canvasMarqueeHint, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter({required this.a, required this.b, required this.color});
  final Offset a;
  final Offset b;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(a, b);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _MarqueePainter old) =>
      old.a != a || old.b != b || old.color != color;
}

class _ResizeCorner extends StatelessWidget {
  const _ResizeCorner({
    required this.node,
    required this.viewportScale,
    required this.onResizeStart,
    required this.onResize,
  });

  final FolioCanvasNode node;
  final double viewportScale;
  final VoidCallback onResizeStart;
  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    const s = 14.0;
    return Positioned(
      left: node.x + node.width - s / 2,
      top: node.y + node.height - s / 2,
      child: GestureDetector(
        onPanStart: (_) => onResizeStart(),
        onPanUpdate: (d) => onResize(d.delta / viewportScale),
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            border: Border.all(color: Colors.white, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _CanvasToolbar extends StatelessWidget {
  const _CanvasToolbar({
    required this.mode,
    required this.drawKind,
    required this.snapEnabled,
    required this.drawColor,
    required this.nodeColor,
    required this.onModeChanged,
    required this.onDrawKindChanged,
    required this.onSnapToggled,
    required this.onDrawColorChanged,
    required this.onNodeColorChanged,
    required this.onOpenClassicEditor,
    required this.onClearStrokes,
    required this.onOpenLayers,
    required this.onGroup,
    required this.onUngroup,
    required this.onRotate,
    required this.onDeleteSelection,
    required this.onTemplate,
    required this.onExportPng,
    required this.onExportSvg,
    required this.onExportPdf,
    required this.canGroup,
    required this.canUngroup,
    required this.canRotate,
    required this.l10n,
    required this.scheme,
  });

  final CanvasMode mode;
  final FolioCanvasStrokeKind drawKind;
  final bool snapEnabled;
  final Color drawColor;
  final Color nodeColor;
  final ValueChanged<CanvasMode> onModeChanged;
  final ValueChanged<FolioCanvasStrokeKind> onDrawKindChanged;
  final VoidCallback onSnapToggled;
  final ValueChanged<Color> onDrawColorChanged;
  final ValueChanged<Color> onNodeColorChanged;
  final VoidCallback onOpenClassicEditor;
  final VoidCallback onClearStrokes;
  final VoidCallback onOpenLayers;
  final VoidCallback onGroup;
  final VoidCallback onUngroup;
  final VoidCallback onRotate;
  final VoidCallback? onDeleteSelection;
  final VoidCallback onTemplate;
  final VoidCallback onExportPng;
  final VoidCallback onExportSvg;
  final VoidCallback onExportPdf;
  final bool canGroup;
  final bool canUngroup;
  final bool canRotate;
  final AppLocalizations l10n;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Card(
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
                icon: Icons.crop_free_rounded,
                label: l10n.canvasToolbarMarquee,
                active: mode == CanvasMode.marquee,
                onTap: () => onModeChanged(CanvasMode.marquee),
              ),
              _ToolBtn(
                icon: Icons.sticky_note_2_outlined,
                label: l10n.canvasToolbarAddNode,
                active: mode == CanvasMode.addNote,
                onTap: () => onModeChanged(CanvasMode.addNote),
              ),
              _ToolBtn(
                icon: Icons.hexagon_outlined,
                label: l10n.canvasToolbarAddShape,
                active: mode == CanvasMode.addShape,
                onTap: () => onModeChanged(CanvasMode.addShape),
              ),
              _ToolBtn(
                icon: Icons.aspect_ratio_rounded,
                label: l10n.canvasToolbarAddFrame,
                active: mode == CanvasMode.addFrame,
                onTap: () => onModeChanged(CanvasMode.addFrame),
              ),
              _ToolBtn(
                icon: Icons.gesture_rounded,
                label: l10n.canvasToolbarDraw,
                active: mode == CanvasMode.draw,
                onTap: () => onModeChanged(CanvasMode.draw),
              ),
              _ToolBtn(
                icon: Icons.auto_fix_high_rounded,
                label: l10n.canvasDrawEraser,
                active: mode == CanvasMode.erase,
                onTap: () => onModeChanged(CanvasMode.erase),
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
              if (mode == CanvasMode.draw) ...[
                _ToolBtn(
                  icon: Icons.edit_rounded,
                  label: l10n.canvasDrawInk,
                  active: drawKind == FolioCanvasStrokeKind.ink,
                  onTap: () => onDrawKindChanged(FolioCanvasStrokeKind.ink),
                ),
                _ToolBtn(
                  icon: Icons.highlight_rounded,
                  label: l10n.canvasDrawHighlighter,
                  active: drawKind == FolioCanvasStrokeKind.highlighter,
                  onTap: () => onDrawKindChanged(FolioCanvasStrokeKind.highlighter),
                ),
              ],
              const VerticalDivider(width: 16, indent: 4, endIndent: 4),
              _ToolBtn(
                icon: snapEnabled ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                label: l10n.canvasToolbarSnap,
                active: snapEnabled,
                onTap: onSnapToggled,
              ),
              _ToolBtn(
                icon: Icons.layers_outlined,
                label: l10n.canvasToolbarLayers,
                active: false,
                onTap: onOpenLayers,
              ),
              _ToolBtn(
                icon: Icons.group_work_outlined,
                label: l10n.canvasToolbarGroup,
                active: false,
                onTap: canGroup ? onGroup : () {},
              ),
              _ToolBtn(
                icon: Icons.call_split_rounded,
                label: l10n.canvasToolbarUngroup,
                active: false,
                onTap: canUngroup ? onUngroup : () {},
              ),
              _ToolBtn(
                icon: Icons.rotate_right_rounded,
                label: l10n.canvasToolbarRotate,
                active: false,
                onTap: canRotate ? onRotate : () {},
              ),
              IconButton(
                tooltip: l10n.canvasToolbarTemplate,
                icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
                onPressed: onTemplate,
                visualDensity: VisualDensity.compact,
              ),
              PopupMenuButton<String>(
                tooltip: l10n.canvasToolbarExport,
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                onSelected: (v) {
                  switch (v) {
                    case 'png':
                      onExportPng();
                    case 'svg':
                      onExportSvg();
                    case 'pdf':
                      onExportPdf();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'png', child: Text(l10n.canvasExportPng)),
                  PopupMenuItem(value: 'svg', child: Text(l10n.canvasExportSvg)),
                  PopupMenuItem(value: 'pdf', child: Text(l10n.canvasExportPdf)),
                ],
              ),
              if (onDeleteSelection != null)
                IconButton(
                  tooltip: l10n.canvasDeleteNodeConfirm,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: scheme.error),
                  onPressed: onDeleteSelection,
                  visualDensity: VisualDensity.compact,
                ),
              const VerticalDivider(width: 16, indent: 4, endIndent: 4),
              _ColorDot(
                color: mode == CanvasMode.draw || mode == CanvasMode.erase ? drawColor : nodeColor,
                onChanged: mode == CanvasMode.draw || mode == CanvasMode.erase
                    ? onDrawColorChanged
                    : onNodeColorChanged,
                tooltip: l10n.canvasColorPickerTooltip,
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
              Tooltip(
                message: l10n.canvasToolbarDraw,
                child: IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  iconSize: 20,
                  onPressed: onClearStrokes,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
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
  const _ColorDot({
    required this.color,
    required this.onChanged,
    required this.tooltip,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final String tooltip;

  static const _palette = [
    Color(0xFFFFF9C4),
    Color(0xFFC8E6C9),
    Color(0xFFBBDEFB),
    Color(0xFFFFCCBC),
    Color(0xFFE1BEE7),
    Color(0xFFF8BBD9),
    Color(0xFFFFFFFF),
    Color(0xFF212121),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      tooltip: tooltip,
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
                          color: c == color ? Colors.blue : Colors.grey.shade300,
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
      var color = v != null
          ? Color(hex.length == 6 ? (0xFF000000 | v) : v)
          : Colors.black;
      if (stroke.kind == FolioCanvasStrokeKind.highlighter) {
        color = color.withValues(alpha: 0.35);
      }
      final paint = Paint()
        ..color = color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      final json = stroke.toJson();
      final rawPts = json['points'] as List;
      if (rawPts.isEmpty) continue;
      final first = rawPts.first as Map<String, dynamic>;
      path.moveTo((first['x'] as num).toDouble(), (first['y'] as num).toDouble());
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

Rect _normalizeMarqueeRect(Rect r) {
  return Rect.fromLTRB(
    math.min(r.left, r.right),
    math.min(r.top, r.bottom),
    math.max(r.left, r.right),
    math.max(r.top, r.bottom),
  );
}
