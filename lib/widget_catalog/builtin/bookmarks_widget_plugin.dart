import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Lista bloques `bookmark` del vault (url + texto).
class BookmarksWidgetPlugin extends FolioWidgetPlugin {
  const BookmarksWidgetPlugin();

  @override
  String get id => 'bookmarks';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetBookmarks;

  @override
  IconData get icon => Icons.bookmark_outline_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final l10n = AppLocalizations.of(context);
    final items =
        <({String pageId, String pageTitle, String label, String? url})>[];
    for (final page in ctx.session.pages) {
      if (page.isTrashed) continue;
      final pageTitle = page.title.trim().isEmpty ? l10n.untitled : page.title;
      for (final block in page.blocks) {
        if (block.type != 'bookmark') continue;
        final url = (block.url ?? '').trim();
        final label = block.text.trim().isEmpty
            ? (url.isEmpty ? l10n.widgetBookmarksFallbackLabel : url)
            : block.text.trim();
        items.add((
          pageId: page.id,
          pageTitle: pageTitle,
          label: label,
          url: url.isEmpty ? null : url,
        ));
        if (items.length >= 12) break;
      }
      if (items.length >= 12) break;
    }

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: items.isEmpty
          ? BuiltinWidgetEmpty(
              message: l10n.widgetBookmarksEmpty,
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmark_rounded, size: 18),
                  title: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.pageTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    if (item.url != null) {
                      final uri = Uri.tryParse(item.url!);
                      if (uri != null) {
                        unawaited(
                          launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          ),
                        );
                      }
                    }
                    ctx.onSelectPage?.call(item.pageId);
                  },
                );
              },
            ),
    );
  }
}
