import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../models/vault_task_list_entry.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Agenda — tareas con fecha de vencimiento (`FolioTaskData.dueDate`),
/// ordenadas por proximidad. Dato real, vía `collectTaskBlocks()`.
class AgendaWidgetPlugin extends FolioWidgetPlugin {
  const AgendaWidgetPlugin();

  @override
  String get id => 'agenda';

  @override
  String displayName(BuildContext context) => 'Agenda';

  @override
  IconData get icon => Icons.event_note_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final dated = <({VaultTaskListEntry entry, DateTime due})>[];
    for (final t in ctx.session.collectTaskBlocks()) {
      if (t.task?.status == 'done') continue;
      final due = DateTime.tryParse(t.task?.dueDate ?? '');
      if (due != null) dated.add((entry: t, due: due));
    }
    dated.sort((a, b) => a.due.compareTo(b.due));

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: dated.isEmpty
          ? const BuiltinWidgetComingSoon(
              message: 'No hay tareas con fecha próxima.',
            )
          : ListView.builder(
              itemCount: dated.length.clamp(0, 8),
              itemBuilder: (context, index) {
                final t = dated[index].entry;
                final due = dated[index].due;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded, size: 18),
                  title: Text(
                    t.task!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${due.day.toString().padLeft(2, '0')}/'
                    '${due.month.toString().padLeft(2, '0')}/'
                    '${due.year} · ${t.pageTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => ctx.onSelectPage?.call(t.pageId),
                );
              },
            ),
    );
  }
}
