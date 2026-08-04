import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// IA — el panel de IA flotante ya existe como región del motor de layout
/// (`PanelRegionIds.floatingAi`), fuera de la superficie de
/// [WidgetPluginContext]. Este widget no reimplementa el chat; solo se
/// declara honestamente hasta que exista un callback dedicado para
/// abrir/anclar el panel de IA desde el catálogo.
class AiWidgetPlugin extends FolioWidgetPlugin {
  const AiWidgetPlugin();

  @override
  String get id => 'ai';

  @override
  String displayName(BuildContext context) => 'IA';

  @override
  IconData get icon => Icons.auto_awesome_rounded;

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
        message: 'Usa el panel de IA flotante del workspace para chatear.',
      ),
    );
  }
}
