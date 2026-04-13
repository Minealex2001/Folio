part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowMeetingNote(_BlockRowScope s) {
  if (s.block.type != 'meeting_note') return null;
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
  final transcriptPreview = block.text.trim();
  final hasMeetingContent = rawU.isNotEmpty || transcriptPreview.isNotEmpty;
  final compactView =
      hasMeetingContent &&
      !showInlineEditControls &&
      !showActions &&
      !focus.hasFocus;
  final previewText = transcriptPreview.isEmpty
      ? 'Sin transcripcion'
      : transcriptPreview;
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
            child: compactView
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.meetingNoteTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (rawU.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.audio_file_rounded,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        previewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  )
                : (rawU.isEmpty
                      ? MeetingNoteBlockWidget(
                          block: block,
                          page: page,
                          session: st._s,
                          appSettings: st.widget.appSettings,
                          scheme: scheme,
                          resolvedFile: null,
                          folioCloudEntitlements: s.folioCloudEntitlements,
                        )
                      : FutureBuilder<File?>(
                          future: st._resolveBlockUrlFileCached(rawU),
                          builder: (ctx, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 48,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return MeetingNoteBlockWidget(
                              block: block,
                              page: page,
                              session: st._s,
                              appSettings: st.widget.appSettings,
                              scheme: scheme,
                              resolvedFile: snap.data,
                              folioCloudEntitlements:
                                  s.folioCloudEntitlements,
                            );
                          },
                        )),
          ),
        ),
      ],
    ),
  );
}
