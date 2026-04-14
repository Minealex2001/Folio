part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowBookmark(_BlockRowScope s) {
  if (s.block.type != 'bookmark') return null;
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
  final url = (block.url ?? '').trim();
  final host = Uri.tryParse(url)?.host ?? '';
  final wf = st._imageWidthFor(block);
  return Padding(
    padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final targetW = (maxW * wf).clamp(120.0, maxW);
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: targetW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showActions)
                        st._blockMediaWidthToolbar(page, block, theme),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (host.isNotEmpty)
                              Text(
                                host,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (host.isNotEmpty) const SizedBox(height: 6),
                            TextField(
                              controller: ctrl,
                              focusNode: focus,
                              readOnly: readOnlyMode,
                              showCursor: !readOnlyMode,
                              maxLines: null,
                              minLines: 1,
                              style: theme.textTheme.titleSmall,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: AppLocalizations.of(
                                  context,
                                ).bookmarkTitleHint,
                              ),
                            ),
                            if (url.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).bookmarkBlockHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              SelectableText(
                                url,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  MetaData(
                                    metaData: folioInteractiveMetaDataTag,
                                    behavior: HitTestBehavior.translucent,
                                    child: FilledButton.tonalIcon(
                                      onPressed: () => unawaited(
                                        st._openBlockUrlExternal(block.url),
                                      ),
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).bookmarkOpenLink,
                                      ),
                                    ),
                                  ),
                                  MetaData(
                                    metaData: folioInteractiveMetaDataTag,
                                    behavior: HitTestBehavior.translucent,
                                    child: OutlinedButton(
                                      onPressed: () => unawaited(
                                        st._editBookmarkUrlDialog(
                                          page.id,
                                          block.id,
                                          index,
                                        ),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).bookmarkSetUrl,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
