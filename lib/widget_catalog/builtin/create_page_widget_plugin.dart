import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.createPage` — un único botón,
/// sin necesidad de la chrome de [BuiltinWidgetCard].
class CreatePageWidgetPlugin extends FolioWidgetPlugin {
  const CreatePageWidgetPlugin();

  @override
  String get id => 'create_page';

  @override
  String displayName(BuildContext context) => 'Crear página';

  @override
  IconData get icon => Icons.add_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return Center(
      child: FilledButton.tonalIcon(
        onPressed: ctx.onCreatePage,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva página'),
      ),
    );
  }
}
