import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// RSS — sin un módulo de suscripción/parseo de feeds en el repo hoy.
/// Declarado honestamente en vez de simular titulares.
class RssWidgetPlugin extends FolioWidgetPlugin {
  const RssWidgetPlugin();

  @override
  String get id => 'rss';

  @override
  String displayName(BuildContext context) => 'RSS';

  @override
  IconData get icon => Icons.rss_feed_rounded;

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
        message: AppLocalizations.of(context).widgetRssComingSoon,
      ),
    );
  }
}
