import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

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
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetFavoritePage;

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

    final l10n = AppLocalizations.of(context);
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: page != null
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_rounded),
              title: Text(
                page.title.trim().isEmpty ? l10n.untitled : page.title,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: l10n.remove,
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
          ? BuiltinWidgetEmpty(message: l10n.widgetFavoritePageEmpty)
          : DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.widgetFavoritePageChooseLabel,
                isDense: true,
              ),
              items: [
                for (final p in pages.take(40))
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.title.trim().isEmpty ? l10n.untitled : p.title,
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
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: l10n.widgetFavoritePageIdLabel,
        hintText: l10n.widgetFavoritePageIdHint,
      ),
      onChanged: (v) {
        settings['pageId'] = v.trim();
        onSettingsChanged({...settings});
      },
    );
  }
}
