part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowEmbed(_BlockRowScope s) {
  if (s.block.type != 'embed') return null;
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
  final wf = st._imageWidthFor(block);
  final embedH = (360 * (0.45 + 0.55 * wf)).clamp(200.0, 560.0);
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: embedH,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: url.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      ).embedEmptyHint,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                )
                              : MetaData(
                                  metaData: folioInteractiveMetaDataTag,
                                  behavior: HitTestBehavior.translucent,
                                  child: FolioEmbedWebView(
                                    url: url,
                                    scheme: scheme,
                                  ),
                                ),
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
