import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/models/widget_instance_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Vista de mes real con cabecera mes/año y días marcados por dueDate.
class CalendarWidgetPlugin extends FolioWidgetPlugin {
  const CalendarWidgetPlugin();

  @override
  String get id => 'calendar';

  @override
  String displayName(BuildContext context) =>
      AppLocalizations.of(context).widgetCalendar;

  @override
  IconData get icon => Icons.calendar_month_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  double get defaultHeight => 220;

  static bool _weekStartsMonday(WidgetInstanceConfig instance) {
    final raw = instance.settings['calendarWeekStartsMonday'];
    return raw is bool ? raw : true;
  }

  /// Ejemplo real de Widget Theme Tokens (Fase 23) — el fin de semana usa
  /// un color con significado semántico ("es fin de semana"), no una
  /// preferencia por-instancia como las de `settings`. `null` = sin
  /// distinguir fin de semana (comportamiento de hoy).
  @override
  Map<String, dynamic> get defaultTheme => const {};

  Color? _weekendColor(WidgetPluginContext ctx) {
    final theme = ctx.widgetThemeFor(id, defaultTheme);
    final raw = theme['weekendColor'];
    return raw is int ? Color(raw) : null;
  }

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final weekStartsMonday = _weekStartsMonday(instance);
    // weekday: Mon=1 … Sun=7
    final leadingBlanks = weekStartsMonday
        ? (firstOfMonth.weekday - 1) % 7
        : firstOfMonth.weekday % 7;

    final markedDays = <int>{
      for (final t in ctx.session.collectTaskBlocks())
        if (DateTime.tryParse(t.task?.dueDate ?? '') case final due?)
          if (due.year == now.year && due.month == now.month) due.day,
    };

    final monthLabel = DateFormat.yMMMM(
      Localizations.localeOf(context).toString(),
    ).format(now);
    const weekdaysMon = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const weekdaysSun = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
    final weekdays = weekStartsMonday ? weekdaysMon : weekdaysSun;
    final weekendColor = _weekendColor(ctx);

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            monthLabel,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final d in weekdays)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = index - leadingBlanks + 1;
                final isToday = day == now.day;
                final scheme = Theme.of(context).colorScheme;
                final isWeekend =
                    DateTime(now.year, now.month, day).weekday >= DateTime.saturday;
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
                          : (isWeekend ? weekendColor : null),
                      fontWeight: markedDays.contains(day)
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
    var monday = _weekStartsMonday(instance);
    return StatefulBuilder(
      builder: (context, setState) {
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(AppLocalizations.of(context).widgetCalendarWeekStartsMonday),
          value: monday,
          onChanged: (v) {
            setState(() => monday = v);
            settings['calendarWeekStartsMonday'] = v;
            onSettingsChanged({...settings});
          },
        );
      },
    );
  }
}
