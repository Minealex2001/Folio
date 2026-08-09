import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../../models/vault_task_list_entry.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Fase 2 del roadmap de producto — "Daily Brief". Idea #11 del brief
/// original pedía un resumen narrativo generado por Quill; se acota
/// deliberadamente a datos reales ya disponibles en la sesión (tareas
/// vencidas/de hoy vía `collectTaskBlocks()`, páginas editadas hoy vía
/// `pageLastEditedMs`) en vez de inventar una llamada a IA para un texto de
/// bienvenida — mismo principio que el resto del catálogo ("dato real, no
/// relleno"). No hay "reuniones" reales que contar: Folio no tiene un
/// modelo de reuniones programadas (solo `meeting_note`, que registra
/// reuniones ya ocurridas), así que ese conteo del mockup original queda
/// fuera hasta que exista esa fuente de verdad. Opt-in explícito: es un
/// widget más del catálogo, el usuario decide si lo añade a su Home.
class DailyBriefWidgetPlugin extends FolioWidgetPlugin {
  const DailyBriefWidgetPlugin();

  @override
  String get id => 'daily_brief';

  @override
  String displayName(BuildContext context) =>
      AppLocalizations.of(context).widgetDailyBrief;

  @override
  IconData get icon => Icons.wb_sunny_outlined;

  @override
  double get defaultHeight => 220;

  @override
  bool get allowMultipleInstances => false;

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
          final l10n = AppLocalizations.of(context);
          final now = DateTime.now();

          final tasks = ctx.session.collectTaskBlocks();
          final overdue = <VaultTaskListEntry>[];
          final dueToday = <VaultTaskListEntry>[];
          for (final t in tasks) {
            if (t.task?.status == 'done') continue;
            final due = DateTime.tryParse(t.task?.dueDate ?? '');
            if (due == null) continue;
            final dueDay = DateTime(due.year, due.month, due.day);
            final today = DateTime(now.year, now.month, now.day);
            if (dueDay.isBefore(today)) {
              overdue.add(t);
            } else if (_isSameDay(dueDay, today)) {
              dueToday.add(t);
            }
          }

          final editedTodayCount = ctx.session.pages
              .where((p) => !p.isTrashed && !p.isFolder)
              .where((p) {
                final ms = ctx.session.pageLastEditedMs(p.id);
                if (ms <= 0) return false;
                return _isSameDay(
                  DateTime.fromMillisecondsSinceEpoch(ms),
                  now,
                );
              })
              .length;

          final highlighted = [...overdue, ...dueToday].take(5).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _BriefStat(
                    value: dueToday.length,
                    label: l10n.widgetDailyBriefDueToday,
                  ),
                  _BriefStat(
                    value: overdue.length,
                    label: l10n.widgetDailyBriefOverdue,
                    emphasize: overdue.isNotEmpty,
                  ),
                  _BriefStat(
                    value: editedTodayCount,
                    label: l10n.widgetDailyBriefEditedToday,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: highlighted.isEmpty
                    ? BuiltinWidgetEmpty(
                        message: l10n.widgetDailyBriefAllClear,
                      )
                    : ListView.builder(
                        itemCount: highlighted.length,
                        itemBuilder: (context, index) {
                          final t = highlighted[index];
                          final isOverdue = overdue.contains(t);
                          final scheme = Theme.of(context).colorScheme;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.event_rounded,
                              size: 18,
                              color: isOverdue ? scheme.error : null,
                            ),
                            title: Text(
                              t.task?.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: isOverdue
                                  ? TextStyle(color: scheme.error)
                                  : null,
                            ),
                            subtitle: Text(
                              t.pageTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => ctx.onSelectPage?.call(t.pageId),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BriefStat extends StatelessWidget {
  const _BriefStat({
    required this.value,
    required this.label,
    this.emphasize = false,
  });

  final int value;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: emphasize ? scheme.error : scheme.onSurface,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
