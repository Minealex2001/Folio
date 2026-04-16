part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable

Widget? _specialRowKanban(_BlockRowScope s) {
  if (s.block.type != 'kanban') return null;
  final st = s.st;
  final block = s.block;
  final menu = s.menu;
  final dragHandle = s.dragHandle;
  final marker = s.marker;
  final showActions = s.showActions;
  final context = s.context;
  final l10n = AppLocalizations.of(context);
  final data = FolioKanbanData.tryParse(block.text) ?? FolioKanbanData.defaults();
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
        leading: Icon(Icons.view_kanban_rounded, color: s.scheme.primary),
        title: Text(l10n.kanbanBlockRowTitle),
        subtitle: Text(
          l10n.kanbanBlockRowSubtitle,
          style: s.theme.textTheme.bodySmall?.copyWith(
            color: s.scheme.onSurfaceVariant,
          ),
        ),
        trailing: data.includeSimpleTodos
            ? null
            : Chip(
                label: Text(
                  l10n.kanbanRowTodosExcluded,
                  style: s.theme.textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
      ),
    ),
  );
}
