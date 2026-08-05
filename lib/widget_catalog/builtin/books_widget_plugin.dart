import 'package:flutter/material.dart';

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
  String displayName(BuildContext context) => 'Libros';

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
      child: const BuiltinWidgetComingSoon(
        message:
            'El seguimiento de lectura no está disponible. '
            'No hay un modelo de libros en Folio todavía.',
      ),
    );
  }
}
