part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowVideo(_BlockRowScope s) {
  if (s.block.type != 'video') return null;
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
  final rawU = (block.url ?? '').trim();
  final wf = st._imageWidthFor(block);
  final ytId = rawU.startsWith('http://') || rawU.startsWith('https://')
      ? folioYoutubeVideoIdFromUrl(rawU)
      : null;
  if (ytId != null) {
    final vidH = (220 * (0.45 + 0.55 * wf)).clamp(120.0, 320.0);
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
                        st._buildCollabUploadProgressBadge(
                          block.id,
                          theme,
                          scheme,
                        ),
                        Container(
                          height: vidH,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
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
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: MetaData(
                                    metaData: folioInteractiveMetaDataTag,
                                    behavior: HitTestBehavior.translucent,
                                    child: FolioYoutubePreviewCard(
                                      pageUrl: rawU,
                                      videoId: ytId,
                                      scheme: scheme,
                                      compact: true,
                                    ),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    st._clearBlockUrl(page.id, block.id),
                                child: Text(
                                  AppLocalizations.of(context).removeVideo,
                                ),
                              ),
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
  final localH = (200 * (0.45 + 0.55 * wf)).clamp(120.0, 300.0);
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
                      st._buildCollabUploadProgressBadge(
                        block.id,
                        theme,
                        scheme,
                      ),
                      SizedBox(
                        height: localH,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FutureBuilder<File?>(
                            future: st._resolveBlockUrlFileCached(block.url),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snap.hasError) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      ).videoResolveError,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: scheme.error),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.tonal(
                                      onPressed: () => st._pickVideoForBlock(
                                        page.id,
                                        block.id,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).replaceVideo,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              final file = snap.data;
                              if (file == null) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if ((block.url ?? '').trim().isNotEmpty)
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        ).videoMissing,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: scheme.error),
                                      ),
                                    const SizedBox(height: 8),
                                    FilledButton.tonal(
                                      onPressed: () => st._pickVideoForBlock(
                                        page.id,
                                        block.id,
                                      ),
                                      child: Text(
                                        (block.url ?? '').trim().isEmpty
                                            ? AppLocalizations.of(
                                                context,
                                              ).chooseVideo
                                            : AppLocalizations.of(
                                                context,
                                              ).replaceVideo,
                                      ),
                                    ),
                                    if ((block.url ?? '')
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      TextButton(
                                        onPressed: () => st._clearBlockUrl(
                                          page.id,
                                          block.id,
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).removeVideo,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                              return FolioEmbeddedVideoPlayer(
                                key: ValueKey(file.path),
                                file: file,
                                scheme: scheme,
                                onOpenExternal: () =>
                                    st._openBlockUrlExternal(block.url),
                              );
                            },
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
