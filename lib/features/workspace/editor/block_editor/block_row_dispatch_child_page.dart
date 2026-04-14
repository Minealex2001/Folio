part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowChildPage(_BlockRowScope s) {
  if (s.block.type != 'child_page') return null;
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
  final l10n = AppLocalizations.of(context);
  final cid = block.text.trim();
  FolioPage? child;
  try {
    child = st._s.pages.firstWhere((p) => p.id == cid);
  } catch (_) {
    child = null;
  }
  return Padding(
    padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.blockChildPageTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (child != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(child.title),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => st._s.selectPage(child!.id),
                  )
                else
                  Text(
                    l10n.blockChildPageNoLink,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (!readOnlyMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          st._s.createChildPageLinkedToBlock(
                            pageId: page.id,
                            blockId: block.id,
                          );
                          st._blockRowSetState(() {});
                        },
                        child: Text(l10n.blockActionCreateSubpage),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await st._pickPageForChildBlock(
                            context,
                            excludeId: page.id,
                          );
                          if (picked != null && s.st.mounted) {
                            st._s.updateBlockText(page.id, block.id, picked);
                            st._blockRowSetState(() {});
                          }
                        },
                        child: Text(l10n.blockActionLinkPage),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
