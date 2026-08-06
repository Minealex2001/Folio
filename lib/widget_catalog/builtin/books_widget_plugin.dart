import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Libros — sin un modelo de seguimiento de lectura en el repo hoy.
/// Declarado honestamente en vez de simular una lista de libros.
class BooksWidgetPlugin extends FolioWidgetPlugin {
  const BooksWidgetPlugin();

  @override
  String get id => 'books';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetBooks;

  @override
  IconData get icon => Icons.menu_book_outlined;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: BuiltinWidgetComingSoon(
        message: AppLocalizations.of(context).widgetBooksComingSoon,
      ),
    );
  }
}
