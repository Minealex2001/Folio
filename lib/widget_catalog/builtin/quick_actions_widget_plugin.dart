import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.quickActions`.
class QuickActionsWidgetPlugin extends FolioWidgetPlugin {
  const QuickActionsWidgetPlugin();

  @override
  String get id => 'quick_actions';

  @override
  String displayName(BuildContext context) => 'Acciones rápidas';

  @override
  IconData get icon => Icons.bolt_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nueva página'),
            onPressed: ctx.onCreatePage,
          ),
          ActionChip(
            avatar: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Buscar'),
            onPressed: ctx.onOpenSearch == null
                ? null
                : () => ctx.onOpenSearch!(),
          ),
        ],
      ),
    );
  }
}
