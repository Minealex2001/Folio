import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Clima — requiere una integración con un proveedor de clima externo
/// (API key, permisos de ubicación) que Folio no trae de fábrica.
/// Declarado honestamente en vez de simular datos.
class WeatherWidgetPlugin extends FolioWidgetPlugin {
  const WeatherWidgetPlugin();

  @override
  String get id => 'weather';

  @override
  String displayName(BuildContext context) => 'Clima';

  @override
  IconData get icon => Icons.wb_sunny_outlined;

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
        message: 'El clima necesita una integración externa que todavía '
            'no está configurada.',
      ),
    );
  }
}
