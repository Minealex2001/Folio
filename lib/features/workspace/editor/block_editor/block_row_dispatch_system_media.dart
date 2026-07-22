part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable

Widget? _specialRowSystemMedia(_BlockRowScope s) {
  if (s.block.type != 'systemMedia') return null;
  final st = s.st;
  final block = s.block;
  final page = s.page;
  final scheme = s.scheme;
  final theme = s.theme;
  final context = s.context;
  final focus = s.focus;
  final marker = s.marker;
  final dragHandle = s.dragHandle;
  final menu = s.menu;
  final showActions = s.showActions;
  final showInlineEditControls = s.showInlineEditControls;

  final rawText = block.text.trim();
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
          child: Focus(
            focusNode: focus,
            child: GestureDetector(
              onTap: () => focus.requestFocus(),
              behavior: HitTestBehavior.opaque,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final targetW = (maxW * wf).clamp(120.0, maxW);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: targetW,
                      child: st._wrapResizableBlockMedia(
                        page: page,
                        block: block,
                        enabled: showActions || showInlineEditControls,
                        maxAvailableWidth: maxW,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
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
                            child: rawText.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      ).systemMediaBlockEmptyHint,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : MetaData(
                                    metaData: folioInteractiveMetaDataTag,
                                    behavior: HitTestBehavior.translucent,
                                    child: FolioSystemMediaBlockCard(
                                      key: ValueKey(
                                        'system_media_card_${block.id}',
                                      ),
                                      text: rawText,
                                      scheme: scheme,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
