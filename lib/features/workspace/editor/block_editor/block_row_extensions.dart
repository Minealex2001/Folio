part of 'package:folio/features/workspace/editor/block_editor.dart';

mixin _BlockRowBuild on State<BlockEditor> {
  Widget _buildBlockRowDelegated({
    required BuildContext context,
    required ColorScheme scheme,
    required FolioPage page,
    required FolioBlock block,
    required int index,
    required TextEditingController ctrl,
    required FocusNode focus,
    required TextStyle style,
    required bool showActions,
    required bool showInlineEditControls,
  }) {
    final st = this as BlockEditorState;
    final androidPhoneLayout = FolioAdaptive.isAndroidPhoneWidth(
      MediaQuery.sizeOf(context).width,
    );
    final compactReadOnlyMobile = widget.readOnlyMode && androidPhoneLayout;
    final menu = st._blockMenuButton(
      menuContext: context,
      page: page,
      b: block,
      index: index,
    );
    final iconColor = scheme.onSurfaceVariant.withValues(alpha: 0.85);

    final dragHandle = !androidPhoneLayout && showActions
        ? Tooltip(
            message: AppLocalizations.of(context).dragToReorder,
            waitDuration: const Duration(milliseconds: 400),
            child: ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: AppLocalizations.of(context).dragToReorder,
                button: true,
                child: BlockEditorDragHandle(iconColor: iconColor),
              ),
            ),
          )
        : SizedBox(
            width: androidPhoneLayout ? 0 : BlockEditorState._dragGutterWidth,
            height: 32,
          );

    final theme = Theme.of(context);
    final marker = _buildBlockRowMarker(
      st: st,
      page: page,
      block: block,
      index: index,
      style: style,
      scheme: scheme,
      androidPhoneLayout: androidPhoneLayout,
      compactReadOnlyMobile: compactReadOnlyMobile,
      readOnlyMode: widget.readOnlyMode,
    );

    final scope = _BlockRowScope(
      st: st,
      context: context,
      scheme: scheme,
      theme: theme,
      page: page,
      block: block,
      index: index,
      ctrl: ctrl,
      focus: focus,
      style: style,
      showActions: showActions,
      showInlineEditControls: showInlineEditControls,
      menu: menu,
      dragHandle: dragHandle,
      marker: marker,
      androidPhoneLayout: androidPhoneLayout,
      compactReadOnlyMobile: compactReadOnlyMobile,
    );

    final special = _buildSpecialBlockRowOrNull(scope);
    if (special != null) return special;
    return _buildEditableMarkdownBlockRow(scope);
  }
}
