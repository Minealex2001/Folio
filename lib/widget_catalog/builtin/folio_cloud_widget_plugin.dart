import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración de `WorkspaceHomeSectionIds.folioCloud` — la versión legacy
/// depende de `CloudAccountController`/`FolioCloudEntitlementsController`,
/// que no forman parte de [WidgetPluginContext] (superficie deliberadamente
/// angosta). Hasta que se decida exponer ese estado al catálogo, se declara
/// honestamente en vez de fingir estado de cuenta.
class FolioCloudWidgetPlugin extends FolioWidgetPlugin {
  const FolioCloudWidgetPlugin();

  @override
  String get id => 'folio_cloud';

  @override
  String displayName(BuildContext context) => 'Folio Cloud';

  @override
  IconData get icon => Icons.cloud_outlined;

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
        message:
            'El estado de la cuenta de Folio Cloud todavía no está '
            'conectado al catálogo de widgets.',
      ),
    );
  }
}
