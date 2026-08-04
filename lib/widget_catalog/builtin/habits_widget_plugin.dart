import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Hábitos — sin un modelo de tracking de hábitos (rachas, frecuencia) en
/// el repo hoy. Declarado honestamente en vez de simular una racha falsa.
class HabitsWidgetPlugin extends FolioWidgetPlugin {
  const HabitsWidgetPlugin();

  @override
  String get id => 'habits';

  @override
  String displayName(BuildContext context) => 'Hábitos';

  @override
  IconData get icon => Icons.repeat_rounded;

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
        message: 'El seguimiento de hábitos todavía no existe en Folio.',
      ),
    );
  }
}
