import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/local_collab.dart';
import '../../../session/vault_session.dart';

/// Panel lateral que muestra los comentarios de la página actualmente abierta.
class CommentsPanel extends StatefulWidget {
  const CommentsPanel({
    super.key,
    required this.pageId,
    required this.session,
    required this.scheme,
  });

  final String pageId;
  final VaultSession session;
  final ColorScheme scheme;

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final _controller = TextEditingController();
  bool _showResolved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.session.addComment(pageId: widget.pageId, text: text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = widget.scheme;
    final all = widget.session.commentsForPage(widget.pageId);
    final unresolved = all.where((c) => !c.resolved).toList();
    final resolved = all.where((c) => c.resolved).toList();

    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.sm,
                FolioSpace.md,
                FolioSpace.sm,
                FolioSpace.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: FolioSpace.xs),
                  Expanded(
                    child: Text(
                      l10n.commentsTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (unresolved.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(FolioRadius.xl),
                      ),
                      child: Text(
                        '${unresolved.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Campo para añadir comentario
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.sm,
                0,
                FolioSpace.sm,
                FolioSpace.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        hintText: l10n.commentsAddHint,
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FolioRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _submit,
                    icon: Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    tooltip: l10n.commentsTitle,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Lista de comentarios
            Expanded(
              child: all.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(FolioSpace.md),
                      child: Text(
                        l10n.commentsEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        FolioSpace.sm,
                        FolioSpace.xs,
                        FolioSpace.sm,
                        FolioSpace.md,
                      ),
                      children: [
                        ...unresolved.map(
                          (c) => _CommentTile(
                            key: ValueKey(c.id),
                            comment: c,
                            session: widget.session,
                            scheme: scheme,
                            theme: theme,
                            l10n: l10n,
                          ),
                        ),
                        if (resolved.isNotEmpty) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(FolioRadius.sm),
                            onTap: () =>
                                setState(() => _showResolved = !_showResolved),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    _showResolved
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${l10n.commentsResolved} (${resolved.length})',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showResolved)
                            ...resolved.map(
                              (c) => _CommentTile(
                                key: ValueKey(c.id),
                                comment: c,
                                session: widget.session,
                                scheme: scheme,
                                theme: theme,
                                l10n: l10n,
                                dimmed: true,
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.session,
    required this.scheme,
    required this.theme,
    required this.l10n,
    this.dimmed = false,
  });

  final LocalPageComment comment;
  final VaultSession session;
  final ColorScheme scheme;
  final ThemeData theme;
  final AppLocalizations l10n;
  final bool dimmed;

  bool get _isOwn => comment.authorProfileId == session.activeProfileId;

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authorName = comment.authorDisplayName?.trim().isNotEmpty == true
        ? comment.authorDisplayName!
        : (_isOwn ? 'Yo' : 'Desconocido');
    final alpha = dimmed ? 0.5 : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Opacity(
        opacity: alpha,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Autor + tiempo + acciones
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    (authorName.isEmpty ? '?' : authorName[0]).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatTime(comment.createdAtMs),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Texto
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text(
                comment.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
            // Acciones
            Padding(
              padding: const EdgeInsets.only(left: 21, top: 2),
              child: Row(
                children: [
                  _ActionChip(
                    label: comment.resolved
                        ? l10n.commentsReopen
                        : l10n.commentsResolve,
                    icon: comment.resolved
                        ? Icons.refresh_rounded
                        : Icons.check_rounded,
                    scheme: scheme,
                    theme: theme,
                    onTap: () => session.resolveComment(
                      comment.id,
                      resolved: !comment.resolved,
                    ),
                  ),
                  if (_isOwn) ...[
                    const SizedBox(width: 4),
                    _ActionChip(
                      label: l10n.commentsDelete,
                      icon: Icons.delete_outline_rounded,
                      scheme: scheme,
                      theme: theme,
                      destructive: true,
                      onTap: () => session.deleteComment(comment.id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.scheme,
    required this.theme,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final ColorScheme scheme;
  final ThemeData theme;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? scheme.error : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FolioRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
