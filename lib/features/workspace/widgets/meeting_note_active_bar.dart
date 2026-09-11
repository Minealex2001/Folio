import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/meeting_note_bookmark.dart';
import '../../../services/meeting_note_session_controller.dart';
import '../../../session/vault_session.dart';

/// Barra de reunión activa en el footer del sidebar (mismo estilo que media).
/// Se oculta cuando no hay grabación/procesado en curso.
class MeetingNoteActiveBar extends StatelessWidget {
  const MeetingNoteActiveBar({
    super.key,
    required this.session,
  });

  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    final controller = MeetingNoteSessionController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, session]),
      builder: (context, _) {
        if (!controller.isActive) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final elapsed = controller.elapsed;
        final mm = elapsed.inMinutes.toString().padLeft(2, '0');
        final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        final isCloud =
            controller.state == MeetingNoteSessionState.cloudProcessing;
        final isSetup = controller.state == MeetingNoteSessionState.setup;
        final isStopping = controller.isStopping;
        final onMeetingPage = session.selectedPageId == controller.pageId;

        final subtitle = isStopping
            ? l10n.meetingNoteStopping
            : isCloud
                ? l10n.meetingNoteCloudProcessing
                : isSetup
                    ? l10n.meetingNotePreparing
                    : l10n.meetingNoteRecordingTime(mm, ss);

        // Fase 8: lectura compacta de talk ratio, solo cuando hay datos
        // suficientes — un conteo/ratio puro, nada de puntuación ni
        // inferencia de comportamiento.
        String? talkRatioLine;
        if (!isCloud && !isSetup && !isStopping) {
          final snapshot = controller.metricsSnapshot;
          final ratios = snapshot.talkRatioBySpeaker;
          if (ratios.isNotEmpty) {
            final top = ratios.entries.reduce(
              (a, b) => a.value >= b.value ? a : b,
            );
            talkRatioLine = l10n.meetingNoteTalkRatioCompact(
              top.key,
              (top.value * 100).round(),
            );
          }
        }

        final bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        final fg = scheme.onSurface;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isCloud
                      ? Icons.cloud_sync_rounded
                      : Icons.fiber_manual_record,
                  size: 16,
                  color: isCloud ? scheme.primary : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.meetingNoteActiveBarTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: fg,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                      if (talkRatioLine != null)
                        Text(
                          talkRatioLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: fg.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isCloud && !isSetup && !isStopping)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.meetingNoteAddBookmark,
                    icon: Icon(
                      Icons.bookmark_add_outlined,
                      size: 20,
                      color: fg,
                    ),
                    onPressed: () {
                      final pageId = controller.pageId;
                      final blockId = controller.blockId;
                      if (pageId == null || blockId == null) return;
                      session.addBlockMeetingNoteBookmark(
                        pageId,
                        blockId,
                        MeetingNoteBookmark(
                          id: const Uuid().v4(),
                          timestampMs: elapsed.inMilliseconds,
                          type: MeetingNoteBookmarkType.important,
                          createdAtMs: DateTime.now().millisecondsSinceEpoch,
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.meetingNoteBookmarkAdded),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                if (!onMeetingPage)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.meetingNoteActiveBarGoTo,
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 20,
                      color: fg,
                    ),
                    onPressed: controller.goToMeetingPage,
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: isCloud
                      ? l10n.meetingNoteCancelUpload
                      : l10n.meetingNoteStop,
                  icon: isStopping
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.error,
                          ),
                        )
                      : Icon(
                          Icons.stop_rounded,
                          size: 20,
                          color: scheme.error,
                        ),
                  onPressed: isStopping
                      ? null
                      : () => unawaited(
                            isCloud
                                ? controller.cancelCloudProcessingAndAwait()
                                : controller.stop(),
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
