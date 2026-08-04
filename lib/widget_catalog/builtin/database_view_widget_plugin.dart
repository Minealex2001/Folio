import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Vista de base de datos — Folio tiene `FolioDatabaseData`/`FolioTableData`
/// a nivel de bloque dentro de una página, pero no una vista de dashboard
/// agregada entre páginas todavía. Declarado honestamente en vez de
/// simular filas de una base de datos.
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
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: const BuiltinWidgetComingSoon(
        message: 'Abre una página con una base de datos para verla aquí.',
      ),
    );
  }
}
