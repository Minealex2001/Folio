import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Proxy de hábitos: tareas con `recurrence` (o rrule) vía collectTaskBlocks.
class HabitsWidgetPlugin extends FolioWidgetPlugin {
  const HabitsWidgetPlugin();

  @override
  String get id => 'habits';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetHabits;

  @override
  IconData get icon => Icons.repeat_rounded;

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
          final habits = ctx.session
              .collectTaskBlocks(includeSimpleTodos: false)
              .where((t) {
                final task = t.task;
                if (task == null) return false;
                final rec = (task.recurrence ?? '').trim();
                final rule = (task.recurringRule ?? '').trim();
                return rec.isNotEmpty || rule.isNotEmpty;
              })
              .take(10)
              .toList();

          if (habits.isEmpty) {
            return BuiltinWidgetEmpty(
              message: AppLocalizations.of(context).widgetHabitsEmpty,
            );
          }

          return ListView.builder(
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final t = habits[index];
              final task = t.task!;
              final done = task.status == 'done';
              final recLabel = [
                if ((task.recurrence ?? '').trim().isNotEmpty)
                  task.recurrence!.trim(),
                if ((task.recurringRule ?? '').trim().isNotEmpty)
                  task.recurringRule!.trim(),
              ].join(' · ');
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.repeat_rounded,
                  size: 18,
                ),
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  recLabel,
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
