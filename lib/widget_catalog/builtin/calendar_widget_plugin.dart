import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Vista de mes real (mes/año del sistema, día actual resaltado) con los
/// días que tienen una tarea vencida marcados — no hay un modelo de
/// "eventos" propio en Folio todavía, así que se usan `FolioTaskData.dueDate`
/// como la única fuente de datos con fecha disponible.
class CalendarWidgetPlugin extends FolioWidgetPlugin {
  const CalendarWidgetPlugin();

  @override
  String get id => 'calendar';

  @override
  String displayName(BuildContext context) => 'Calendario';

  @override
  IconData get icon => Icons.calendar_month_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7;

    final markedDays = <int>{
      for (final t in ctx.session.collectTaskBlocks())
        if (DateTime.tryParse(t.task?.dueDate ?? '') case final due?)
          if (due.year == now.year && due.month == now.month) due.day,
    };

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
        ),
        itemCount: leadingBlanks + daysInMonth,
        itemBuilder: (context, index) {
          if (index < leadingBlanks) return const SizedBox.shrink();
          final day = index - leadingBlanks + 1;
          final isToday = day == now.day;
          final scheme = Theme.of(context).colorScheme;
          return Container(
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? scheme.primary : null,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isToday
                    ? scheme.onPrimary
                    : markedDays.contains(day)
                    ? scheme.primary
                    : null,
                fontWeight: markedDays.contains(day)
                    ? FontWeight.bold
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
