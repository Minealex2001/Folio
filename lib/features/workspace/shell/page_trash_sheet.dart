import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

Future<void> showPageTrashSheet({
  required BuildContext context,
  required VaultSession session,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return _PageTrashSheetBody(
            session: session,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _PageTrashSheetBody extends StatelessWidget {
  const _PageTrashSheetBody({
    required this.session,
    required this.scrollController,
  });

  final VaultSession session;
  final ScrollController scrollController;

  int _daysLeft(FolioPage page) {
    final trashedAt = page.trashedAt;
    if (trashedAt == null) return 0;
    final expires = trashedAt.toUtc().add(VaultSession.trashRetention);
    final left = expires.difference(DateTime.now().toUtc()).inDays;
    return left < 0 ? 0 : left;
  }

  Future<void> _confirmEmpty(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.sidebarTrashEmptyAction),
        content: Text(l10n.sidebarTrashEmptyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sidebarTrashEmptyAction),
          ),
        ],
      ),
    );
    if (ok == true) session.emptyTrash();
  }

  Future<void> _confirmDeleteForever(
    BuildContext context,
    FolioPage page,
  ) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = page.title.trim().isEmpty
        ? l10n.untitledFallback
        : page.title.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.sidebarTrashDeleteForever),
        content: Text(l10n.sidebarTrashDeleteForeverConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sidebarTrashDeleteForever),
          ),
        ],
      ),
    );
    if (ok == true) session.permanentlyDeleteFromTrash(page.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final roots = session.trashRootPages;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.lg,
                  FolioSpace.sm,
                  FolioSpace.sm,
                  FolioSpace.xs,
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: scheme.onSurface),
                    const SizedBox(width: FolioSpace.sm),
                    Expanded(
                      child: Text(
                        l10n.sidebarTrashTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (roots.isNotEmpty)
                      TextButton(
                        onPressed: () => _confirmEmpty(context),
                        child: Text(l10n.sidebarTrashEmptyAction),
                      ),
                    IconButton(
                      tooltip: l10n.sidebarTrashClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.lg,
                  0,
                  FolioSpace.lg,
                  FolioSpace.sm,
                ),
                child: Text(
                  l10n.sidebarTrashRetentionHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: roots.isEmpty
                    ? Center(
                        child: Text(
                          l10n.sidebarTrashEmpty,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          FolioSpace.sm,
                          0,
                          FolioSpace.sm,
                          FolioSpace.lg,
                        ),
                        itemCount: roots.length,
                        itemBuilder: (context, index) {
                          final page = roots[index];
                          final title = page.title.trim().isEmpty
                              ? l10n.untitledFallback
                              : page.title.trim();
                          final days = _daysLeft(page);
                          return ListTile(
                            leading: Icon(
                              page.isFolder
                                  ? Icons.folder_outlined
                                  : Icons.description_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                            title: Text(title),
                            subtitle: Text(l10n.sidebarTrashDaysLeft(days)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      session.restoreFromTrash(page.id),
                                  child: Text(l10n.sidebarTrashRestore),
                                ),
                                IconButton(
                                  tooltip: l10n.sidebarTrashDeleteForever,
                                  onPressed: () =>
                                      _confirmDeleteForever(context, page),
                                  icon: Icon(
                                    Icons.delete_forever_outlined,
                                    color: scheme.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
