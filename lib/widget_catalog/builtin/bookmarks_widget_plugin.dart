import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Marcadores — Folio no tiene una colección de bookmarks de enlaces
/// externos hoy. Declarado honestamente en vez de simular una lista.
class BookmarksWidgetPlugin extends FolioWidgetPlugin {
  const BookmarksWidgetPlugin();

  @override
  String get id => 'bookmarks';

  @override
  String displayName(BuildContext context) => 'Marcadores';

  @override
  IconData get icon => Icons.bookmark_outline_rounded;

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
        message: 'Los marcadores todavía no existen en Folio.',
      ),
    );
  }
}
