part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Chrome común para filas especiales: padding por depth + slots menú/drag/marker + cuerpo.
Widget _specialRowChrome({
  required BlockEditorState st,
  required FolioBlock block,
  required PopupMenuButton<String> menu,
  required Widget dragHandle,
  required Widget marker,
  required bool showActions,
  EdgeInsetsGeometry? padding,
  required Widget child,
}) {
  return Padding(
    padding:
        padding ?? EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(child: child),
      ],
    ),
  );
}

