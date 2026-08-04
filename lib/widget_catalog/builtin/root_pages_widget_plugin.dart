import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.rootPages` — páginas de nivel
/// raíz (`parentId == null`) de la libreta activa, vía `VaultSession.pages`.
class RootPagesWidgetPlugin extends FolioWidgetPlugin {
  const RootPagesWidgetPlugin();

  @override
  String get id => 'root_pages';

  @override
  String displayName(BuildContext context) => 'Páginas';

  @override
  IconData get icon => Icons.description_outlined;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final roots = ctx.session.pages
        .where((p) => p.parentId == null && !p.isTrashed)
        .take(10)
        .toList();

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: roots.isEmpty
          ? const BuiltinWidgetComingSoon(message: 'No hay páginas todavía.')
          : ListView.builder(
              itemCount: roots.length,
              itemBuilder: (context, index) {
                final page = roots[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: page.emoji != null && page.emoji!.isNotEmpty
                      ? Text(page.emoji!, style: const TextStyle(fontSize: 16))
                      : Icon(
                          page.isFolder
                              ? Icons.folder_outlined
                              : Icons.description_outlined,
                          size: 18,
                        ),
                  title: Text(
                    page.title.isEmpty ? 'Sin título' : page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => ctx.onSelectPage?.call(page.id),
                );
              },
            ),
    );
  }
}
