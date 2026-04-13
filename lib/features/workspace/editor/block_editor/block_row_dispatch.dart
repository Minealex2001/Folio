part of 'package:folio/features/workspace/editor/block_editor.dart';

Widget? _buildSpecialBlockRowOrNull(_BlockRowScope s) {
  return _specialRowImage(s) ??
      _specialRowTable(s) ??
      _specialRowDatabase(s) ??
      _specialRowEquation(s) ??
      _specialRowMermaid(s) ??
      _specialRowCode(s) ??
      _specialRowDivider(s) ??
      _specialRowFile(s) ??
      _specialRowBookmark(s) ??
      _specialRowEmbed(s) ??
      _specialRowAudio(s) ??
      _specialRowMeetingNote(s) ??
      _specialRowVideo(s) ??
      _specialRowToggle(s) ??
      _specialRowToc(s) ??
      _specialRowBreadcrumb(s) ??
      _specialRowChildPage(s) ??
      _specialRowTemplateButton(s) ??
      _specialRowTask(s) ??
      _specialRowColumnList(s);
}
