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
  // Fase F1 del rediseño UX del editor: acento de identidad visual opcional
  // — solo los tipos con tono definido en `_blockAccentToneFor` lo reciben
  // (hoy `database`, único call site de esta chrome que lo pasa); el resto
  // de usuarios de `_specialRowChrome` (table, canvas, toggle, task, kanban,
  // column_list, drive) quedan exactamente igual que antes.
  final accentTone = _blockAccentToneFor(block.type);
  final content = accentTone == null
      ? child
      : _blockAccentStripe(
          Theme.of(st.context).colorScheme,
          st._calloutPreset,
          accentTone,
          child: child,
        );
  return Padding(
    padding:
        padding ??
        EdgeInsetsDirectional.fromSTEB(
          block.depth * 28.0,
          st._blockVerticalSpacing,
          4,
          st._blockVerticalSpacing,
        ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(child: content),
      ],
    ),
  );
}

