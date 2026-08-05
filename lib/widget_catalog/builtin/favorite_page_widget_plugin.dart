import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Página pineada vía `settings.pageId` (sin flag isFavorite en el modelo).
class FavoritePageWidgetPlugin extends FolioWidgetPlugin {
  const FavoritePageWidgetPlugin();

  @override
  String get id => 'favorite_page';

  @override
  String displayName(BuildContext context) => 'Página favorita';

  @override
  IconData get icon => Icons.star_outline_rounded;

  @override
  bool get allowMultipleInstances => true;

  static String? _pageIdOf(WidgetInstanceConfig instance) {
    final raw = instance.settings['pageId'];
    return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  }

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final pageId = _pageIdOf(instance);
    final page = pageId == null
        ? null
        : ctx.session.pages
            .where((p) => !p.isTrashed && p.id == pageId)
            .firstOrNull;

    final pages = ctx.session.pages
        .where((p) => !p.isTrashed && !p.isFolder)
        .toList()
      ..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: page != null
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_rounded),
              title: Text(
                page.title.trim().isEmpty ? 'Sin título' : page.title,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Quitar',
                onPressed: () {
                  ctx.onUpdateInstanceSettings?.call(instance.instanceId, {
                    ...instance.settings,
                    'pageId': '',
                  });
                },
              ),
              onTap: () => ctx.onSelectPage?.call(page.id),
            )
          : pages.isEmpty
          ? const BuiltinWidgetEmpty(message: 'No hay páginas en el vault.')
          : DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Elegir página',
                isDense: true,
              ),
              items: [
                for (final p in pages.take(40))
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.title.trim().isEmpty ? 'Sin título' : p.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                ctx.onUpdateInstanceSettings?.call(instance.instanceId, {
                  ...instance.settings,
                  'pageId': id,
                });
              },
            ),
    );
  }

  @override
  Widget? buildSettings(
    BuildContext context,
    WidgetInstanceConfig instance,
    ValueChanged<Map<String, dynamic>> onSettingsChanged,
  ) {
    final settings = Map<String, dynamic>.from(instance.settings);
    final controller = TextEditingController(text: _pageIdOf(instance) ?? '');
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'ID de página',
        hintText: 'Id de la página a pinear',
      ),
      onChanged: (v) {
        settings['pageId'] = v.trim();
        onSettingsChanged({...settings});
      },
    );
  }
}
