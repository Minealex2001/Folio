import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.miniStats` — conteos reales
/// derivados de `VaultSession` (páginas, tareas pendientes/completadas).
class MiniStatsWidgetPlugin extends FolioWidgetPlugin {
  const MiniStatsWidgetPlugin();

  @override
  String get id => 'mini_stats';

  @override
  String displayName(BuildContext context) => 'Estadísticas';

  @override
  IconData get icon => Icons.bar_chart_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final pageCount = ctx.session.pages.where((p) => !p.isTrashed).length;
    final tasks = ctx.session.collectTaskBlocks();
    final doneCount = tasks
        .where(
          (t) => t.blockType == 'todo'
              ? t.todoChecked == true
              : t.task?.status == 'done',
        )
        .length;
    final pendingCount = tasks.length - doneCount;

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Páginas', value: pageCount),
          _Stat(label: 'Pendientes', value: pendingCount),
          _Stat(label: 'Completadas', value: doneCount),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
