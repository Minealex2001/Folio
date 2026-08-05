import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Conteo de páginas, carpetas y tareas del vault.
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
    final pages = ctx.session.pages.where((p) => !p.isTrashed);
    final pageCount = pages.where((p) => !p.isFolder).length;
    final folderCount = pages.where((p) => p.isFolder).length;
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
          _Stat(label: 'Carpetas', value: folderCount),
          _Stat(label: 'Pendientes', value: pendingCount),
          _Stat(label: 'Hechas', value: doneCount),
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
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
