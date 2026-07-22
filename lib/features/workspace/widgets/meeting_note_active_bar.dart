import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/meeting_note_session_controller.dart';
import '../../../session/vault_session.dart';

/// Barra flotante cuando hay una reunión activa y el usuario no está en su página.
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
        if (session.selectedPageId == controller.pageId) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final theme = Theme.of(context);
        final elapsed = controller.elapsed;
        final mm = elapsed.inMinutes.toString().padLeft(2, '0');
        final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        final isCloud =
            controller.state == MeetingNoteSessionState.cloudProcessing;
        final isSetup = controller.state == MeetingNoteSessionState.setup;

        return Material(
          elevation: 4,
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCloud
                      ? Icons.cloud_sync_rounded
                      : Icons.fiber_manual_record,
                  size: 14,
                  color: isCloud ? scheme.primary : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.meetingNoteActiveBarTitle,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isCloud
                            ? l10n.meetingNoteCloudProcessing
                            : isSetup
                                ? l10n.meetingNotePreparing
                                : l10n.meetingNoteRecordingTime(mm, ss),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: controller.goToMeetingPage,
                  child: Text(l10n.meetingNoteActiveBarGoTo),
                ),
                if (!isCloud)
                  IconButton(
                    tooltip: l10n.meetingNoteStop,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => unawaited(controller.stop()),
                    icon: Icon(
                      Icons.stop_rounded,
                      color: scheme.error,
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
