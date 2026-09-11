import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../../config/models/widget_instance_config.dart';
import '../../models/block.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';
import 'daily_notes_widget_plugin.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.quickActions`.
class QuickActionsWidgetPlugin extends FolioWidgetPlugin {
  const QuickActionsWidgetPlugin();

  @override
  String get id => 'quick_actions';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetQuickActions;

  @override
  IconData get icon => Icons.bolt_rounded;

  void _openOrCreateDailyNote(WidgetPluginContext ctx) {
    final today = isoDate(DateTime.now());
    final existing = ctx.session.pages
        .where((p) => !p.isTrashed && p.title.trim() == today)
        .firstOrNull;
    if (existing != null) {
      ctx.onSelectPage?.call(existing.id);
      return;
    }
    final id = const Uuid().v4();
    ctx.session.createPageWithId(
      id: id,
      title: today,
      blocks: [
        FolioBlock(id: '${id}_b0', type: 'paragraph', text: ''),
      ],
    );
    ctx.onSelectPage?.call(id);
  }

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final l10n = AppLocalizations.of(context);
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.widgetNewPageAction),
            onPressed: ctx.onCreatePage,
          ),
          ActionChip(
            avatar: const Icon(Icons.today_rounded, size: 18),
            label: Text(l10n.widgetQuickActionsTodayNote),
            onPressed: () => _openOrCreateDailyNote(ctx),
          ),
          ActionChip(
            avatar: const Icon(Icons.search_rounded, size: 18),
            label: Text(l10n.search),
            onPressed: ctx.onOpenSearch == null
                ? null
                : () => ctx.onOpenSearch!(),
          ),
        ],
      ),
    );
  }
}
