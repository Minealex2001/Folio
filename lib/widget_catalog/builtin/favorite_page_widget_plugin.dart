import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Página favorita — `FolioPage` no tiene todavía un flag `isFavorite`
/// (confirmado por grep en `lib/models/`); marcarlo requeriría una migración
/// de esquema fuera de alcance de este catálogo. Declarado honestamente en
/// vez de elegir una página al azar y llamarla "favorita".
class FavoritePageWidgetPlugin extends FolioWidgetPlugin {
  const FavoritePageWidgetPlugin();

  @override
  String get id => 'favorite_page';

  @override
  String displayName(BuildContext context) => 'Página favorita';

  @override
  IconData get icon => Icons.star_outline_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: const BuiltinWidgetComingSoon(
        message: 'Marcar páginas como favoritas todavía no existe en Folio.',
      ),
    );
  }
}
