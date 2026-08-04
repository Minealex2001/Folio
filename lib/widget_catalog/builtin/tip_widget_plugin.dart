import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

const List<String> _kTips = [
  'Usa "/" en el editor para insertar bloques rápidamente.',
  'Arrastra una página al panel lateral para anclarla.',
  'Ctrl+K abre la búsqueda global desde cualquier pantalla.',
  'Activa el editor visual desde la barra superior para reordenar el layout.',
  'Puedes marcar una tarea como hecha directamente desde este panel.',
];

/// Migración 1:1 de `WorkspaceHomeSectionIds.tip` — rota entre consejos
/// reales de uso de Folio, determinístico por día del año (no aleatorio,
/// para no cambiar en cada rebuild).
class TipWidgetPlugin extends FolioWidgetPlugin {
  const TipWidgetPlugin();

  @override
  String get id => 'tip';

  @override
  String displayName(BuildContext context) => 'Consejo';

  @override
  IconData get icon => Icons.lightbulb_outline_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final dayOfYear = int.parse(
      DateTime.now().difference(DateTime(DateTime.now().year)).inDays
          .toString(),
    );
    final tip = _kTips[dayOfYear % _kTips.length];
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Text(tip, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
