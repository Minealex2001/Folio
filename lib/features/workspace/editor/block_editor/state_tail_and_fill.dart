part of 'package:folio/features/workspace/editor/block_editor.dart';

extension _BlockEditorTailAndFill on BlockEditorState {
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

