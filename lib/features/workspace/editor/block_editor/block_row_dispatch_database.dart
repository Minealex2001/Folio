part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowDatabase(_BlockRowScope s) {
  if (s.block.type != 'database') return null;
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
      child: IgnorePointer(
        ignoring: readOnlyMode,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: readOnlyMode ? null : () {},
          child: DatabaseBlockEditor(
            json: block.text,
            scheme: scheme,
            textTheme: theme.textTheme,
            controlsVisible: showInlineEditControls,
            onChanged: (enc) => st._onTableEncoded(page.id, block.id, index, enc),
          ),
        ),
      ),
    ),
  );
}
