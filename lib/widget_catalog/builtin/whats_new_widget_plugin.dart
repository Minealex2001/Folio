import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración de `WorkspaceHomeSectionIds.whatsNew` — la versión legacy
/// (`_buildWhatsNewSection`) lee notas de versión desde un callback de
/// `WorkspacePage` (`onOpenReleaseNotes`) no expuesto en
/// [WidgetPluginContext]; hasta que ese callback se añada a la superficie
/// de capacidad del catálogo, se muestra honestamente que no está
/// disponible en vez de simular contenido.
class WhatsNewWidgetPlugin extends FolioWidgetPlugin {
  const WhatsNewWidgetPlugin();

  @override
  String get id => 'whats_new';

  @override
  String displayName(BuildContext context) => 'Novedades';

  @override
  IconData get icon => Icons.campaign_outlined;

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
            'Las notas de versión todavía no están conectadas al catálogo '
            'de widgets.',
      ),
    );
  }
}
