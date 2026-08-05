import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.tasks` — usa
/// `VaultSession.collectTaskBlocks()` (dato real, no relleno).
class TasksWidgetPlugin extends FolioWidgetPlugin {
  const TasksWidgetPlugin();

  @override
  String get id => 'tasks';

  @override
  String displayName(BuildContext context) => 'Tareas';

  @override
  IconData get icon => Icons.checklist_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: ListenableBuilder(
        listenable: ctx.session,
        builder: (context, _) {
          final pending = ctx.session
              .collectTaskBlocks()
              .where(
                (t) => t.blockType == 'todo'
                    ? t.todoChecked != true
                    : t.task?.status != 'done',
              )
              .take(8)
              .toList();

          if (pending.isEmpty) {
            return const BuiltinWidgetEmpty(
              message: 'Sin tareas pendientes.',
            );
          }

          return ListView.builder(
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final t = pending[index];
              final title = t.blockType == 'todo'
                  ? t.todoText
                  : (t.task?.title ?? '');
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: IconButton(
                  icon: const Icon(
                    Icons.radio_button_unchecked_rounded,
                    size: 18,
                  ),
                  tooltip: 'Marcar hecha',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    ctx.session.setTaskBlockDone(
                      t.pageId,
                      t.blockId,
                      done: true,
                    );
                  },
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  t.pageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => ctx.onSelectPage?.call(t.pageId),
              );
            },
          );
        },
      ),
    );
  }
}
