import 'package:flutter/material.dart';

import '../../../../app/app_settings.dart';
import '../../../../app/ui_tokens.dart';
import '../../../../app/widgets/folio_icon_token_view.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/folio_page.dart';
import '../../../../session/vault_session.dart';
import '../../recent_page_visits.dart';

class SidebarRecentsSection extends StatelessWidget {
  const SidebarRecentsSection({
    super.key,
    required this.appSettings,
    required this.session,
    required this.recentVisits,
    required this.onSelectPage,
    required this.onToggleCollapsed,
  });

  final AppSettings appSettings;
  final VaultSession session;
  final List<RecentPageVisit> recentVisits;
  final ValueChanged<String> onSelectPage;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    if (!appSettings.workspaceSidebarShowRecentPages) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pagesById = <String, FolioPage>{
      for (final p in session.activePages) p.id: p,
    };
    final recentPages = recentVisits
        .take(kRecentPageVisitsSidebarDisplayLimit)
        .map((v) => pagesById[v.pageId])
        .whereType<FolioPage>()
        .toList(growable: false);
    if (recentPages.isEmpty) return const SizedBox.shrink();

    final isCollapsed = appSettings.workspaceSidebarRecentPagesCollapsed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FolioSpace.sm,
        0,
        FolioSpace.sm,
        FolioSpace.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(FolioSpace.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).workspaceRecentPagesSectionTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 16,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onToggleCollapsed,
                ),
              ],
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: FolioSpace.xs),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentPages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: FolioSpace.xs),
                  itemBuilder: (context, index) {
                    final page = recentPages[index];
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onSelectPage(page.id),
                      avatar: FolioIconTokenView(
                        appSettings: appSettings,
                        token: page.emoji,
                        fallbackText: '📄',
                        size: 14,
                      ),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          page.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
