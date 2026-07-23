import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
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
        final onMeetingPage = session.selectedPageId == controller.pageId;

        final subtitle = isCloud
            ? l10n.meetingNoteCloudProcessing
            : isSetup
                ? l10n.meetingNotePreparing
                : l10n.meetingNoteRecordingTime(mm, ss);

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
                    ],
                  ),
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
                if (!isCloud)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.meetingNoteStop,
                    icon: Icon(
                      Icons.stop_rounded,
                      size: 20,
                      color: scheme.error,
                    ),
                    onPressed: () => unawaited(controller.stop()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
