import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.search` — campo que abre la
/// búsqueda global real de la app (`ctx.onOpenSearch`), no una búsqueda
/// propia del widget.
class SearchWidgetPlugin extends FolioWidgetPlugin {
  const SearchWidgetPlugin();

  @override
  String get id => 'search';

  @override
  String displayName(BuildContext context) => 'Buscar';

  @override
  IconData get icon => Icons.search_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: ctx.onOpenSearch == null ? null : () => ctx.onOpenSearch!(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Buscar en Folio…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Ctrl+K',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
