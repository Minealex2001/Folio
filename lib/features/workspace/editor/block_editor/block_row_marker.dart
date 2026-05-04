part of 'package:folio/features/workspace/editor/block_editor.dart';

Widget _buildBlockRowMarker({
  required BlockEditorState st,
  required FolioPage page,
  required FolioBlock block,
  required int index,
  required TextStyle style,
  required ColorScheme scheme,
  required bool androidPhoneLayout,
  required bool compactReadOnlyMobile,
  required bool readOnlyMode,
}) {
  switch (block.type) {
    case 'todo':
      final todoCol = compactReadOnlyMobile
          ? 26.0
          : (androidPhoneLayout
                ? BlockEditorState._markerColumnWidthPhone + 6.0
                : BlockEditorState._markerColumnWidth + 8.0);
      return SizedBox(
        width: todoCol,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: AppLocalizations.of(st.context).blockEditorMarkTaskComplete,
            toggled: block.checked ?? false,
            child: Transform.translate(
              offset: const Offset(-4, 0),
              child: MetaData(
                metaData: folioInteractiveMetaDataTag,
                behavior: HitTestBehavior.translucent,
                child: Transform.scale(
                  scale: compactReadOnlyMobile ? 1.05 : 1.28,
                  alignment: Alignment.centerLeft,
                  child: Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.standard,
                    value: block.checked ?? false,
                    onChanged: readOnlyMode
                        ? null
                        : (v) {
                            if (v != null) {
                              st._s.setBlockChecked(page.id, block.id, v);
                            }
                          },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    case 'bullet':
      final markerStyle = st._applyBlockAppearanceToTextStyle(
        style,
        scheme,
        block,
      );
      return SizedBox(
        width: compactReadOnlyMobile
            ? 16
            : (androidPhoneLayout
                  ? BlockEditorState._markerColumnWidthPhone
                  : BlockEditorState._markerColumnWidth),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text('•', style: markerStyle.copyWith(height: 1.0)),
          ),
        ),
      );
    case 'numbered':
      final n = st._orderedListNumber(page.blocks, index);
      final markerStyle = st._applyBlockAppearanceToTextStyle(
        style,
        scheme,
        block,
      );
      return SizedBox(
        width: compactReadOnlyMobile
            ? 20
            : (androidPhoneLayout
                  ? BlockEditorState._markerColumnWidthPhone
                  : BlockEditorState._markerColumnWidth),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 2, top: 2),
            child: Text('$n.', style: markerStyle.copyWith(height: 1.0)),
          ),
        ),
      );
    default:
      return SizedBox(
        width: compactReadOnlyMobile
            ? 0
            : (androidPhoneLayout
                  ? BlockEditorState._markerEmptyColumnWidthPhone
                  : BlockEditorState._markerColumnWidth),
      );
  }
}
