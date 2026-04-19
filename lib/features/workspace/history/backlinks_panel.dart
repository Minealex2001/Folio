import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

/// Panel lateral que muestra las páginas que enlazan a la página actualmente abierta.
class BacklinksPanel extends StatelessWidget {
  const BacklinksPanel({
    super.key,
    required this.pageId,
    required this.session,
    required this.scheme,
  });

  final String pageId;
  final VaultSession session;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final backlinks = session.backlinkPagesFor(pageId);

    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 248,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.sm,
                FolioSpace.md,
                FolioSpace.sm,
                FolioSpace.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: FolioSpace.xs),
                  Expanded(
                    child: Text(
                      l10n.backlinksTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (backlinks.isNotEmpty)
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
                        '${backlinks.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: backlinks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(FolioSpace.md),
                      child: Text(
                        l10n.backlinksEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        FolioSpace.sm,
                        0,
                        FolioSpace.sm,
                        FolioSpace.md,
                      ),
                      itemCount: backlinks.length,
                      itemBuilder: (context, i) {
                        final page = backlinks[i];
                        return _BacklinkTile(
                          page: page,
                          session: session,
                          scheme: scheme,
                          theme: theme,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklinkTile extends StatelessWidget {
  const _BacklinkTile({
    required this.page,
    required this.session,
    required this.scheme,
    required this.theme,
  });

  final FolioPage page;
  final VaultSession session;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final emoji = (page.emoji?.trim().isNotEmpty ?? false) ? page.emoji! : null;
    final title = page.title.trim().isEmpty ? '—' : page.title.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(FolioRadius.sm),
      onTap: () => session.selectPage(page.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ] else ...[
              Icon(
                Icons.description_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  height: 1.25,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
