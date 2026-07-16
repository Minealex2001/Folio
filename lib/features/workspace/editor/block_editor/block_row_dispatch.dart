part of 'package:folio/features/workspace/editor/block_editor.dart';

typedef _SpecialRowBuilder = Widget? Function(_BlockRowScope s);

final Map<String, _SpecialRowBuilder> _specialRowBuildersByType = {
  'image': _specialRowImage,
  'table': _specialRowTable,
  'database': _specialRowDatabase,
  'kanban': _specialRowKanban,
  'drive': _specialRowDrive,
  'canvas': _specialRowCanvas,
  'equation': _specialRowEquation,
  'mermaid': _specialRowMermaid,
  'code': _specialRowCode,
  'divider': _specialRowDivider,
  'file': _specialRowFile,
  'bookmark': _specialRowBookmark,
  'embed': _specialRowEmbed,
  'audio': _specialRowAudio,
  'meeting_note': _specialRowMeetingNote,
  'video': _specialRowVideo,
  'toggle': _specialRowToggle,
  'toc': _specialRowToc,
  'breadcrumb': _specialRowBreadcrumb,
  'child_page': _specialRowChildPage,
  'template_button': _specialRowTemplateButton,
  'task': _specialRowTask,
  'column_list': _specialRowColumnList,
};

Widget? _buildSpecialBlockRowOrNull(_BlockRowScope s) {
  final builder = _specialRowBuildersByType[s.block.type];
  if (builder != null) return builder.call(s);

  // Bloques de apps instaladas: tipo namespaced (ej. com.acme.chart)
  if (s.block.type.contains('.')) {
    return CustomAppBlockWidget(
      block: s.block,
      scheme: s.scheme,
      appRegistry: AppExtensionRegistry.instance,
      onBlockUpdated: (data) {
        // Serializa los datos del bloque custom como JSON en el campo text
        final encoded = const JsonEncoder().convert(data);
        s.st.widget.session.updateBlockText(s.page.id, s.block.id, encoded);
      },
    );
  }

  return null;
}
