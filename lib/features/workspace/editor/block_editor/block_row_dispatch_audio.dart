part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowAudio(_BlockRowScope s) {
  if (s.block.type != 'audio') return null;
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
  return Padding(
    padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
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
            child: FutureBuilder<File?>(
              future: st._resolveBlockUrlFileCached(block.url),
              builder: (context, snap) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    st._buildCollabUploadProgressBadge(
                      block.id,
                      theme,
                      scheme,
                    ),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (snap.data == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.blockAudioEmptyHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => unawaited(
                              st._pickAudioForBlock(page.id, block.id),
                            ),
                            icon: const Icon(Icons.audio_file_rounded),
                            label: Text(l10n.blockActionChooseAudio),
                          ),
                        ],
                      )
                    else
                      MetaData(
                        metaData: folioInteractiveMetaDataTag,
                        behavior: HitTestBehavior.translucent,
                        child: FolioAudioBlockPlayer(
                          file: snap.data!,
                          scheme: scheme,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
