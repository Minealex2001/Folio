part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable

Widget? _specialRowCanvas(_BlockRowScope s) {
  if (s.block.type != 'canvas') return null;
  final st = s.st;
  final block = s.block;
  final menu = s.menu;
  final dragHandle = s.dragHandle;
  final marker = s.marker;
  final showActions = s.showActions;
  final context = s.context;
  final l10n = AppLocalizations.of(context);
  final data = FolioCanvasData.tryParse(block.text) ?? FolioCanvasData.defaults();
  return _specialRowChrome(
    st: st,
    block: block,
    menu: menu,
    dragHandle: dragHandle,
    marker: marker,
    showActions: showActions,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: s.scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.gesture_rounded, color: s.scheme.primary),
        title: Text(l10n.canvasBlockRowTitle),
        subtitle: Text(
          l10n.canvasBlockRowSubtitle(data.nodes.length, data.strokes.length),
          style: s.theme.textTheme.bodySmall?.copyWith(
            color: s.scheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}
