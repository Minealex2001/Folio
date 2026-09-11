import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// CTA para crear página — chrome alineado con el resto del catálogo.
class CreatePageWidgetPlugin extends FolioWidgetPlugin {
  const CreatePageWidgetPlugin();

  @override
  String get id => 'create_page';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetCreatePage;

  @override
  IconData get icon => Icons.add_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Center(
        child: FilledButton.tonalIcon(
          onPressed: ctx.onCreatePage,
          icon: const Icon(Icons.add_rounded),
          label: Text(AppLocalizations.of(context).widgetNewPageAction),
        ),
      ),
    );
  }
}
