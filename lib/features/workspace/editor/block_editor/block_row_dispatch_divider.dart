part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowDivider(_BlockRowScope s) {
  if (s.block.type != 'divider') return null;
  final st = s.st;
  final block = s.block;
  final page = s.page;
  final scheme = s.scheme;
  final theme = s.theme;
  final context = s.context;
  final ctrl = s.ctrl;
  final focus = s.focus;
  final marker = s.marker;
  final dragHandle = s.dragHandle;
  final menu = s.menu;
  final showActions = s.showActions;
  final showInlineEditControls = s.showInlineEditControls;
  final index = s.index;
  final readOnlyMode = s.readOnlyMode;
  return Padding(
    padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 12, 4, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        const Expanded(child: Divider()),
      ],
    ),
  );
}
