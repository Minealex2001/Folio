import 'package:flutter/material.dart';

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
  String displayName(BuildContext context) => 'Base de datos';

  @override
  IconData get icon => Icons.table_chart_outlined;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final items = <({String pageId, String pageTitle, int rows})>[];
    for (final page in ctx.session.pages) {
      if (page.isTrashed) continue;
      for (final block in page.blocks) {
        if (block.type != 'database') continue;
        final db = FolioDatabaseData.tryParse(block.text);
        final pageTitle =
            page.title.trim().isEmpty ? 'Sin título' : page.title;
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
          ? const BuiltinWidgetEmpty(
              message: 'No hay páginas con base de datos en el vault.',
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
                  subtitle: Text('${item.rows} filas'),
                  onTap: () => ctx.onSelectPage?.call(item.pageId),
                );
              },
            ),
    );
  }
}
