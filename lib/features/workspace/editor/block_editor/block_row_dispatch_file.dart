part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowFile(_BlockRowScope s) {
  if (s.block.type != 'file') return null;
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
  final wf = st._imageWidthFor(block);
  final boxH = (260 * (0.4 + 0.6 * wf)).clamp(140.0, 420.0);
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
                        height: boxH,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
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
                                      ).fileResolveError,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: scheme.error),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: () => st._pickFileForBlock(
                                        page.id,
                                        block.id,
                                      ),
                                      icon: const Icon(
                                        Icons.attach_file_rounded,
                                      ),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).replaceFile,
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
                                        ).fileMissing,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: scheme.error),
                                      ),
                                    const SizedBox(height: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: () => st._pickFileForBlock(
                                        page.id,
                                        block.id,
                                      ),
                                      icon: const Icon(
                                        Icons.attach_file_rounded,
                                      ),
                                      label: Text(
                                        (block.url ?? '').trim().isEmpty
                                            ? AppLocalizations.of(
                                                context,
                                              ).chooseFile
                                            : AppLocalizations.of(
                                                context,
                                              ).replaceFile,
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
                                          ).removeFile,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                              return FolioFilePreviewCard(
                                file: file,
                                theme: theme,
                                scheme: scheme,
                                onOpenExternal: () =>
                                    st._openBlockUrlExternal(block.url),
                                onReplace: () =>
                                    st._pickFileForBlock(page.id, block.id),
                                onClear: () =>
                                    st._clearBlockUrl(page.id, block.id),
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
