import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';

/// Resultado del menú al pegar una URL en el editor.
enum FolioPasteUrlMode {
  markdownUrl,
  embed,
  bookmark,
  vaultMention,
}

Widget _pasteOptionTile({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<FolioPasteUrlMode?> showPasteUrlOptionsSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<FolioPasteUrlMode>(
    context: context,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  l10n.pasteUrlTitle,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.alternate_email_rounded,
                title: l10n.pasteAsMention,
                subtitle: l10n.pasteAsMentionSubtitleRich,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.vaultMention),
              ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.link_rounded,
                title: l10n.pasteAsUrl,
                subtitle: l10n.pasteAsUrlSubtitle,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.markdownUrl),
              ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.web_rounded,
                title: l10n.pasteAsEmbed,
                subtitle: l10n.pasteAsEmbedSubtitleWeb,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.embed),
              ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.bookmark_outline_rounded,
                title: l10n.pasteAsBookmark,
                subtitle: l10n.pasteAsBookmarkSubtitle,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.bookmark),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Selector de página para insertar mención interna `[título](folio://open/id)`.
Future<String?> showFolioPagePickerForMention(
  BuildContext context,
  VaultSession session, {
  String? excludePageId,
}) {
  final l10n = AppLocalizations.of(context);
  final pages = session.pages;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                l10n.pickPageForMention,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: Builder(
                builder: (c) {
                  var list = pages.toList();
                  if (excludePageId != null) {
                    final filtered = list
                        .where((p) => p.id != excludePageId)
                        .toList();
                    if (filtered.isNotEmpty) list = filtered;
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final p = list[i];
                      return ListTile(
                        title: Text(
                          p.title.trim().isEmpty
                              ? l10n.untitledFallback
                              : p.title,
                        ),
                        onTap: () => Navigator.pop(ctx, p.id),
                      );
                    },
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
