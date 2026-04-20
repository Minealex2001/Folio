import 'package:flutter/material.dart';

import '../../../models/folio_canvas_data.dart';
import '../editor/block_type_catalog.dart';

/// Modo de interacción del lienzo.
enum CanvasMode { select, draw, addNote, addShape, addFolioBlock, connect }

/// Widget que representa un nodo individual dentro del lienzo infinito.
class CanvasNodeWidget extends StatefulWidget {
  const CanvasNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    required this.mode,
    required this.viewportScale,
    required this.onTap,
    required this.onDragDelta,
    required this.onEditText,
    required this.onToggleChecked,
    required this.onDelete,
    required this.onConnectFrom,
  });

  final FolioCanvasNode node;
  final bool isSelected;
  final CanvasMode mode;
  final double viewportScale;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<String> onEditText;
  final VoidCallback onToggleChecked;
  final VoidCallback onDelete;
  final VoidCallback onConnectFrom;

  @override
  State<CanvasNodeWidget> createState() => _CanvasNodeWidgetState();
}

class _CanvasNodeWidgetState extends State<CanvasNodeWidget> {
  var _editing = false;
  late TextEditingController _textCtrl;

  /// Texto editable según el tipo de nodo.
  String get _sourceText {
    final n = widget.node;
    return n.type == CanvasNodeType.folioBlock
        ? (n.folioBlockText ?? '')
        : n.text;
  }

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: _sourceText);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CanvasNodeWidget old) {
    super.didUpdateWidget(old);
    final oldText = old.node.type == CanvasNodeType.folioBlock
        ? (old.node.folioBlockText ?? '')
        : old.node.text;
    if (oldText != _sourceText && !_editing) {
      _textCtrl.text = _sourceText;
    }
  }

  void _commitEdit() {
    if (_editing) {
      setState(() => _editing = false);
      widget.onEditText(_textCtrl.text);
    }
  }

  Color _nodeColor(BuildContext context) {
    final hex = widget.node.color;
    if (hex != null) {
      final clean = hex.replaceAll('#', '');
      final v = int.tryParse(clean, radix: 16);
      if (v != null) return Color(clean.length == 6 ? (0xFF000000 | v) : v);
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final node = widget.node;
    final selected = widget.isSelected;

    Widget content;
    switch (node.type) {
      case CanvasNodeType.text:
        content = _buildTextNode(context);
      case CanvasNodeType.shape:
        content = _buildShapeNode(context);
      case CanvasNodeType.image:
        content = _buildImageNode(context);
      case CanvasNodeType.folioBlock:
        content = _buildFolioBlockNode(context);
    }

    Widget wrapped = GestureDetector(
      onTap: () {
        if (_editing) {
          _commitEdit();
          return;
        }
        if (widget.mode == CanvasMode.connect) {
          widget.onConnectFrom();
        } else {
          widget.onTap();
        }
      },
      onDoubleTap: () {
        if (node.type == CanvasNodeType.text) {
          setState(() => _editing = true);
        } else if (node.type == CanvasNodeType.folioBlock) {
          const nonEditable = {
            'divider',
            'image',
            'video',
            'audio',
            'file',
            'table',
            'database',
            'kanban',
            'drive',
            'mermaid',
            'toc',
            'breadcrumb',
            'template_button',
            'column_list',
            'canvas',
            'embed',
          };
          final t = node.folioBlockType ?? '';
          if (!nonEditable.contains(t)) setState(() => _editing = true);
        }
      },
      onPanUpdate: (details) {
        if (widget.mode == CanvasMode.select ||
            widget.mode == CanvasMode.connect) {
          widget.onDragDelta(details.delta / widget.viewportScale);
        }
      },
      child: content,
    );

    if (selected && widget.mode == CanvasMode.select) {
      wrapped = Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: wrapped,
          ),
          Positioned(
            top: -12,
            right: -12,
            child: _DeleteButton(onDelete: widget.onDelete),
          ),
        ],
      );
    }

    return wrapped;
  }

  Widget _buildTextNode(BuildContext context) {
    final bgColor = _nodeColor(context);
    final textColor =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    if (_editing) {
      return Container(
        color: bgColor,
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _textCtrl,
          autofocus: true,
          maxLines: null,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: const InputDecoration.collapsed(hintText: ''),
          onSubmitted: (_) => _commitEdit(),
          onTapOutside: (_) => _commitEdit(),
        ),
      );
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(10),
      child: Text(
        widget.node.text.isEmpty ? '(nota vacía)' : widget.node.text,
        style: TextStyle(
          color: widget.node.text.isEmpty ? Colors.grey : textColor,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildShapeNode(BuildContext context) {
    final color = _nodeColor(context);
    return CustomPaint(
      painter: _ShapePainter(
        shapeType: widget.node.shapeType,
        color: color,
        borderColor: widget.isSelected
            ? Theme.of(context).colorScheme.primary
            : color.withValues(alpha: 0.6),
      ),
      child: Center(
        child: Text(
          widget.node.text,
          style: const TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildImageNode(BuildContext context) {
    final url = widget.node.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }
    return Image.network(url, fit: BoxFit.cover);
  }

  Widget _buildFolioBlockNode(BuildContext context) {
    return _FolioBlockRenderer(
      blockType: widget.node.folioBlockType ?? 'paragraph',
      text: widget.node.folioBlockText ?? '',
      checked: widget.node.folioBlockChecked ?? false,
      editing: _editing,
      textCtrl: _textCtrl,
      onToggleChecked: widget.onToggleChecked,
      onCommitEdit: _commitEdit,
    );
  }
}

// ─── Renderer de bloque Folio ─────────────────────────────────────────────────

class _FolioBlockRenderer extends StatelessWidget {
  const _FolioBlockRenderer({
    required this.blockType,
    required this.text,
    required this.checked,
    required this.editing,
    required this.textCtrl,
    required this.onToggleChecked,
    required this.onCommitEdit,
  });

  final String blockType;
  final String text;
  final bool checked;
  final bool editing;
  final TextEditingController textCtrl;
  final VoidCallback onToggleChecked;
  final VoidCallback onCommitEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Bloques que NO tienen texto editable
    if (blockType == 'divider') {
      return Container(
        color: scheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Divider(thickness: 1, color: scheme.outlineVariant),
      );
    }

    final textWidget = editing
        ? TextField(
            controller: textCtrl,
            autofocus: true,
            maxLines: null,
            expands: true,
            style: _textStyle(context),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Escribe aquí...',
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
            onTapOutside: (_) => onCommitEdit(),
          )
        : Text(
            text.isEmpty ? '(vacío)' : text,
            style: _textStyle(context).copyWith(
              color: text.isEmpty
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                  : null,
              decoration: (blockType == 'todo' && checked)
                  ? TextDecoration.lineThrough
                  : null,
            ),
          );

    switch (blockType) {
      // ── Encabezados ──────────────────────────────────────────────────────
      case 'h1':
      case 'h2':
      case 'h3':
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.topLeft,
          child: editing ? textWidget : textWidget,
        );

      // ── Todo ─────────────────────────────────────────────────────────────
      case 'todo':
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: checked,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (_) => onToggleChecked(),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: editing
                      ? textWidget
                      : Text(
                          text.isEmpty ? '(vacío)' : text,
                          style: _textStyle(context).copyWith(
                            color: checked
                                ? scheme.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  )
                                : null,
                            decoration: checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );

      // ── Bullet ───────────────────────────────────────────────────────────
      case 'bullet':
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Expanded(child: textWidget),
            ],
          ),
        );

      // ── Numbered ─────────────────────────────────────────────────────────
      case 'numbered':
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 8),
                child: Text(
                  '1.',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: textWidget),
            ],
          ),
        );

      // ── Quote ────────────────────────────────────────────────────────────
      case 'quote':
        return Container(
          color: scheme.surface,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: scheme.primary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(fontStyle: FontStyle.italic),
                      child: textWidget,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      // ── Callout ──────────────────────────────────────────────────────────
      case 'callout':
        return Container(
          color: scheme.primaryContainer.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              Expanded(child: textWidget),
            ],
          ),
        );

      // ── Toggle ───────────────────────────────────────────────────────────
      case 'toggle':
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  child: textWidget,
                ),
              ),
            ],
          ),
        );

      // ── Code ─────────────────────────────────────────────────────────────
      case 'code':
        return Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.all(12),
          child: editing
              ? textWidget
              : Text(
                  text.isEmpty ? '// código' : text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
        );

      // ── Child page ────────────────────────────────────────────────────────
      case 'child_page':
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: textWidget),
            ],
          ),
        );

      // ── Bookmark ──────────────────────────────────────────────────────────
      case 'bookmark':
        return Container(
          color: scheme.surfaceContainerLow,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 1),
                child: Icon(
                  Icons.bookmark_outline_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              Expanded(child: textWidget),
            ],
          ),
        );

      // ── Equation ──────────────────────────────────────────────────────────
      case 'equation':
        return Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          child: editing
              ? textWidget
              : Text(
                  text.isEmpty ? 'f(x) = ...' : text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    color: scheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
        );

      // ── Meeting note ───────────────────────────────────────────────────────
      case 'meeting_note':
        return Container(
          color: scheme.tertiaryContainer.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 1),
                child: Icon(
                  Icons.mic_rounded,
                  size: 18,
                  color: scheme.tertiary,
                ),
              ),
              Expanded(child: textWidget),
            ],
          ),
        );

      // ── Tipos visuales / placeholder ──────────────────────────────────────
      case 'image':
      case 'video':
      case 'audio':
      case 'file':
      case 'table':
      case 'database':
      case 'kanban':
      case 'drive':
      case 'mermaid':
      case 'toc':
      case 'breadcrumb':
      case 'template_button':
      case 'column_list':
      case 'canvas':
      case 'embed':
        return _buildPlaceholder(context);

      // ── Paragraph y resto de tipos con texto ──────────────────────────────
      default:
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.topLeft,
          child: textWidget,
        );
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = blockTypeIconForKey(blockType);
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              blockType,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _textStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (blockType) {
      case 'h1':
        return TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          height: 1.2,
        );
      case 'h2':
        return TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          height: 1.25,
        );
      case 'h3':
        return TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          height: 1.3,
        );
      case 'code':
        return TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: scheme.onSurface,
        );
      default:
        return TextStyle(fontSize: 14, color: scheme.onSurface, height: 1.5);
    }
  }
}

// ─── Botón eliminar ──────────────────────────────────────────────────────────

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDelete,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}

// ─── Pintor de formas ────────────────────────────────────────────────────────

class _ShapePainter extends CustomPainter {
  const _ShapePainter({
    required this.shapeType,
    required this.color,
    required this.borderColor,
  });

  final CanvasShapeType shapeType;
  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    switch (shapeType) {
      case CanvasShapeType.rectangle:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, borderPaint);
      case CanvasShapeType.ellipse:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, borderPaint);
      case CanvasShapeType.diamond:
        final path = Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(0, size.height / 2)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      case CanvasShapeType.triangle:
        final path = Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) =>
      old.shapeType != shapeType ||
      old.color != color ||
      old.borderColor != borderColor;
}
