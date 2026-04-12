import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/collab/collab_session_controller.dart';

String _formatCollabTime(BuildContext context, int createdAtMs) {
  if (createdAtMs <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final t = TimeOfDay.fromDateTime(d);
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class CollaborationSheetBody extends StatefulWidget {
  const CollaborationSheetBody({
    super.key,
    required this.collab,
    required this.pageId,
    this.scrollController,
    required this.canHostCollab,
    this.embedded = false,
    this.onRequestMinimize,
  });

  final CollabSessionController collab;
  final String pageId;

  /// En modal: el [DraggableScrollableSheet] provee el controller.
  /// En panel flotante: null y el estado crea uno propio.
  final ScrollController? scrollController;
  final bool canHostCollab;

  /// true = panel en el workspace (no cerrar con [Navigator.pop] al salir de sala).
  final bool embedded;
  final VoidCallback? onRequestMinimize;

  @override
  State<CollaborationSheetBody> createState() => _CollaborationSheetBodyState();
}

class _CollaborationSheetBodyState extends State<CollaborationSheetBody> {
  final _chatCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();
  final _unlockCodeCtrl = TextEditingController();
  ScrollController? _ownedChatScroll;
  bool _busy = false;

  ScrollController get _chatScroll =>
      widget.scrollController ?? _ownedChatScroll!;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _ownedChatScroll = ScrollController();
    }
  }

  @override
  void dispose() {
    _ownedChatScroll?.dispose();
    _chatCtrl.dispose();
    _joinCodeCtrl.dispose();
    _unlockCodeCtrl.dispose();
    super.dispose();
  }

  String _collabErrorText(AppLocalizations l10n, String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw == 'collab_needs_join_code') {
      return l10n.collabNeedsJoinCode;
    }
    return raw;
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildCollabMessageBubble({
    required BuildContext context,
    required CollabChatMessageView msg,
    required bool isMe,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bubbleColor = isMe
        ? scheme.primaryContainer.withValues(alpha: 0.92)
        : scheme.surface;
    final textColor = isMe ? scheme.onPrimaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 4),
              child: Text(
                _formatCollabTime(context, msg.createdAtMs),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.secondaryContainer,
                        scheme.tertiaryContainer,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMe ? 16 : 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    border: Border.all(
                      color: isMe
                          ? scheme.primary.withValues(alpha: 0.12)
                          : scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(22).copyWith(
                      bottomRight: isMe ? const Radius.circular(8) : null,
                      topLeft: !isMe ? const Radius.circular(8) : null,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isMe)
                        Text(
                          msg.authorName.isNotEmpty
                              ? msg.authorName
                              : msg.authorUid,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: textColor.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (!isMe) const SizedBox(height: 6),
                      Text(
                        msg.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                _formatCollabTime(context, msg.createdAtMs),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHighest,
            scheme.surfaceContainerHigh,
          ],
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: BorderRadius.circular(FolioRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  scheme.tertiaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.groups_2_rounded,
              size: 22,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.collabSheetTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.collabHeaderSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.95),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (widget.embedded && widget.onRequestMinimize != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: l10n.collabHidePanel,
              onPressed: widget.onRequestMinimize,
              icon: const Icon(Icons.unfold_less_rounded),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return ListenableBuilder(
      listenable: widget.collab,
      builder: (context, _) {
        final roomId = widget.collab.activeRoomId;
        final msgs = widget.collab.messages;
        final shareCode =
            widget.collab.roomJoinCode?.trim().isNotEmpty == true
                ? widget.collab.roomJoinCode!.trim()
                : '';

        return Material(
          color: scheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, l10n),
              if (widget.collab.lastError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    _collabErrorText(l10n, widget.collab.lastError),
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                ),
              if (roomId == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.collabNoRoomHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: !widget.canHostCollab || _busy
                            ? null
                            : () => _run(() async {
                                  await widget.collab.createRoomForPage(
                                    pageId: widget.pageId,
                                  );
                                }),
                        icon: const Icon(Icons.add_home_work_outlined),
                        label: Text(l10n.collabCreateRoom),
                      ),
                      if (!widget.canHostCollab) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.collabHostRequiresPlan,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _joinCodeCtrl,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.collabJoinCodeLabel,
                      hintText: l10n.collabJoinCodeHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final ok = await widget.collab.joinRoomByCode(
                                pageId: widget.pageId,
                                joinCodeInput: _joinCodeCtrl.text,
                              );
                              if (context.mounted && !ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.collabJoinFailed)),
                                );
                              }
                            }),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(l10n.collabJoinRoom),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(FolioRadius.lg),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.collabShareCodeLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                shareCode.isNotEmpty ? shareCode : '—',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.collabCopyJoinCode,
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: shareCode.isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: shareCode),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.collabCopied),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                if (shareCode.isEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.collabMissingJoinCodeHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: TextField(
                      controller: _unlockCodeCtrl,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.collabJoinCodeLabel,
                        hintText: l10n.collabJoinCodeHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                widget.collab.clearError();
                                await widget.collab.applyJoinCodeAndResync(
                                  _unlockCodeCtrl.text,
                                );
                                if (context.mounted &&
                                    widget.collab.lastError != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _collabErrorText(
                                          l10n,
                                          widget.collab.lastError,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }),
                      icon: const Icon(Icons.lock_open_rounded),
                      label: Text(l10n.collabUnlockWithCode),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(FolioRadius.xl),
                    ),
                    child: msgs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.forum_outlined,
                                      color: scheme.primary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.collabChatEmptyHint,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.55,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _chatScroll,
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                            itemCount: msgs.length,
                            itemBuilder: (context, i) {
                              final m = msgs[i];
                              final isMe =
                                  myUid != null && m.authorUid == myUid;
                              return _buildCollabMessageBubble(
                                context: context,
                                msg: m,
                                isMe: isMe,
                              );
                            },
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.surfaceContainerHighest,
                          scheme.surface,
                        ],
                      ),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.40),
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: l10n.collabMessageHint,
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendChat(),
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                          ),
                          onPressed: _busy ? null : _sendChat,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await widget.collab.archiveChatToVault(
                                    widget.pageId,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.collabArchivedOk),
                                      ),
                                    );
                                  }
                                }),
                        child: Text(l10n.collabArchiveToPage),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await widget.collab.leaveRoom(
                                    pageId: widget.pageId,
                                  );
                                  if (context.mounted && !widget.embedded) {
                                    Navigator.of(context).pop();
                                  }
                                }),
                        child: Text(l10n.collabLeaveRoom),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendChat() async {
    final t = _chatCtrl.text;
    if (t.trim().isEmpty) return;
    await _run(() async {
      await widget.collab.sendChatMessage(t);
      _chatCtrl.clear();
    });
  }
}

Future<void> showCollaborationSheet(
  BuildContext context, {
  required CollabSessionController collab,
  required String pageId,
  required bool canHostCollab,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.22,
          maxChildSize: 0.94,
          builder: (c, scroll) => CollaborationSheetBody(
            collab: collab,
            pageId: pageId,
            scrollController: scroll,
            canHostCollab: canHostCollab,
          ),
        ),
      );
    },
  );
}
