part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowColumnList(_BlockRowScope s) {
  if (s.block.type != 'column_list') return null;
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
  return _specialRowChrome(
    st: st,
    block: block,
    menu: menu,
    dragHandle: dragHandle,
    marker: marker,
    showActions: showActions,
    child: MetaData(
      metaData: folioInteractiveMetaDataTag,
      behavior: HitTestBehavior.translucent,
      child: FolioColumnListBlockBody(
        pageId: page.id,
        block: block,
        session: st._s,
        scheme: scheme,
        textTheme: theme.textTheme,
        showActions: showActions,
      ),
    ),
  );
}
