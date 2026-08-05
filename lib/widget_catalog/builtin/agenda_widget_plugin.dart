import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../models/vault_task_list_entry.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

int _intSetting(Map<String, dynamic> settings, String key, int defaultValue) {
  final raw = settings[key];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return defaultValue;
}

bool _isOverdue(DateTime due) {
  final now = DateTime.now();
  final dueDate = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  return dueDate.isBefore(today);
}

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
    final limit = _intSetting(instance.settings, 'agendaLimit', 8);

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: ListenableBuilder(
        listenable: ctx.session,
        builder: (context, _) {
          final dated = <({VaultTaskListEntry entry, DateTime due})>[];
          for (final t in ctx.session.collectTaskBlocks()) {
            if (t.task?.status == 'done') continue;
            final due = DateTime.tryParse(t.task?.dueDate ?? '');
            if (due != null) dated.add((entry: t, due: due));
          }
          dated.sort((a, b) => a.due.compareTo(b.due));
          final shown = dated.take(limit).toList();

          if (shown.isEmpty) {
            return const BuiltinWidgetEmpty(
              message: 'No hay tareas con fecha próxima.',
            );
          }

          return ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final t = shown[index].entry;
              final due = shown[index].due;
              final overdue = _isOverdue(due);
              final scheme = Theme.of(context).colorScheme;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.event_rounded,
                  size: 18,
                  color: overdue ? scheme.error : null,
                ),
                title: Text(
                  t.task!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: overdue
                      ? TextStyle(color: scheme.error)
                      : null,
                ),
                subtitle: Text(
                  '${due.day.toString().padLeft(2, '0')}/'
                  '${due.month.toString().padLeft(2, '0')}/'
                  '${due.year} · ${t.pageTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: overdue
                      ? TextStyle(color: scheme.error.withValues(alpha: 0.85))
                      : null,
                ),
                onTap: () => ctx.onSelectPage?.call(t.pageId),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget? buildSettings(
    BuildContext context,
    WidgetInstanceConfig instance,
    ValueChanged<Map<String, dynamic>> onSettingsChanged,
  ) {
    final settings = Map<String, dynamic>.from(instance.settings);
    final controller = TextEditingController(
      text: _intSetting(instance.settings, 'agendaLimit', 8).toString(),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Máximo de tareas',
        hintText: '8',
      ),
      onChanged: (v) {
        final n = int.tryParse(v.trim());
        if (n == null || n < 1) return;
        settings['agendaLimit'] = n;
        onSettingsChanged({...settings});
      },
    );
  }
}
