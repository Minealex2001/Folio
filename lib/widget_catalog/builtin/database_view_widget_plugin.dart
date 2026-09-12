import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../../models/folio_database_data.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Lista páginas que contienen un bloque `database`.
class DatabaseViewWidgetPlugin extends FolioWidgetPlugin {
  const DatabaseViewWidgetPlugin();

  @override
  String get id => 'database_view';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetDatabaseView;

  @override
  IconData get icon => Icons.table_chart_outlined;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final l10n = AppLocalizations.of(context);
    final items = <({String pageId, String pageTitle, int rows})>[];
    for (final page in ctx.session.pages) {
      if (page.isTrashed) continue;
      for (final block in page.blocks) {
        if (block.type != 'database') continue;
        final db = FolioDatabaseData.tryParse(block.text);
        final pageTitle =
            page.title.trim().isEmpty ? l10n.untitled : page.title;
        items.add((
          pageId: page.id,
          pageTitle: pageTitle,
          rows: db?.rows.length ?? 0,
        ));
        break;
      }
      if (items.length >= 12) break;
    }

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: items.isEmpty
          ? BuiltinWidgetEmpty(
              message: l10n.widgetDatabaseViewEmpty,
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.table_chart_outlined, size: 18),
                  title: Text(
                    item.pageTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(l10n.widgetDatabaseViewRowCount(item.rows)),
                  onTap: () => ctx.onSelectPage?.call(item.pageId),
                );
              },
            ),
    );
  }
}
