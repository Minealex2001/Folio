part of 'package:folio/features/workspace/editor/block_editor.dart';

extension _BlockEditorTailAndFill on BlockEditorState {
  bool _hitTestInsideAnyBlockRow(Offset globalPosition, FolioPage page) {
    for (final b in page.blocks) {
      final ctx = _blockScrollKeys[b.id]?.currentContext;
      if (ctx == null) continue;
      final render = ctx.findRenderObject();
      if (render is! RenderBox || !render.hasSize) continue;
      final topLeft = render.localToGlobal(Offset.zero);
      final rect = topLeft & render.size;
      if (rect.contains(globalPosition)) return true;
    }
    return false;
  }

  /// `true` si el punto cae en el hueco por debajo del último bloque (padding final).
  bool _tailBlankHitTest(TapDownDetails details, FolioPage page) {
    if (page.blocks.isEmpty) return false;
    final lastId = page.blocks.last.id;
    final ctx = _blockScrollKeys[lastId]?.currentContext;
    if (ctx == null) return false;
    final render = ctx.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return false;
    final topLeft = render.localToGlobal(Offset.zero);
    final bottomY = topLeft.dy + render.size.height;
    final tapY = details.globalPosition.dy;
    return tapY > bottomY + 2;
  }

  void _handleTailBlankDoubleTap(TapDownDetails details, FolioPage page) {
    if (!_tailBlankHitTest(details, page)) return;
    _addBlock(page.id, transientFromTailTap: true);
  }

  Color _blockRowFill(
    ColorScheme scheme,
    FocusNode focus,
    bool selected,
    bool hovered,
  ) {
    final focused = focus.hasFocus;
    if (selected) {
      return scheme.primaryContainer.withValues(alpha: focused ? 0.42 : 0.3);
    }
    if (focused) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    }
    if (hovered) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.22);
    }
    return Colors.transparent;
  }
}

