import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../../config/models/widget_instance_config.dart';
import '../../models/block.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Nota diaria por título ISO `YYYY-MM-DD`.
class DailyNotesWidgetPlugin extends FolioWidgetPlugin {
  const DailyNotesWidgetPlugin();

  @override
  String get id => 'daily_notes';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetDailyNotes;

  @override
  IconData get icon => Icons.today_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final now = DateTime.now();
    final today = isoDate(now);
    final yesterday = isoDate(now.subtract(const Duration(days: 1)));
    final tomorrow = isoDate(now.add(const Duration(days: 1)));

    _PageRef? find(String title) {
      final p = ctx.session.pages
          .where((p) => !p.isTrashed && p.title.trim() == title)
          .firstOrNull;
      return p == null ? null : _PageRef(p.id, title);
    }

    final todayPage = find(today);
    final yesterdayPage = find(yesterday);
    final tomorrowPage = find(tomorrow);
    final l10n = AppLocalizations.of(context);

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.widgetDailyNotesConvention,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (todayPage != null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today_rounded, size: 18),
              title: Text(l10n.widgetDailyNotesToday(today)),
              onTap: () => ctx.onSelectPage?.call(todayPage.id),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () {
                final id = const Uuid().v4();
                ctx.session.createPageWithId(
                  id: id,
                  title: today,
                  blocks: [
                    FolioBlock(id: '${id}_b0', type: 'paragraph', text: ''),
                  ],
                );
                ctx.onSelectPage?.call(id);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.widgetDailyNotesCreateToday(today)),
            ),
          if (yesterdayPage != null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, size: 18),
              title: Text(l10n.widgetDailyNotesYesterday(yesterday)),
              onTap: () => ctx.onSelectPage?.call(yesterdayPage.id),
            ),
          if (tomorrowPage != null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded, size: 18),
              title: Text(l10n.widgetDailyNotesTomorrow(tomorrow)),
              onTap: () => ctx.onSelectPage?.call(tomorrowPage.id),
            ),
        ],
      ),
    );
  }
}

class _PageRef {
  const _PageRef(this.id, this.title);
  final String id;
  final String title;
}
