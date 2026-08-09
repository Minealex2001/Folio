import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../../data/vault_paths.dart';
import '../../features/workspace/recent_page_visits.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

int _intSetting(Map<String, dynamic> settings, String key, int defaultValue) {
  final raw = settings[key];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return defaultValue;
}

String _relativeVisitTime(AppLocalizations l10n, DateTime visited, DateTime now) {
  final ago = now.difference(visited);
  if (ago.inMinutes < 1) return l10n.widgetRelativeJustNow;
  if (ago.inHours < 1) return l10n.widgetRelativeMinutesAgo(ago.inMinutes);
  if (ago.inDays < 1) return l10n.widgetRelativeHoursAgo(ago.inHours);
  return l10n.widgetRelativeDaysAgo(ago.inDays);
}

enum _TimelineEntryKind { visit, aiEdit }

class _TimelineEntry {
  const _TimelineEntry({
    required this.kind,
    required this.timestampMs,
    required this.pageId,
  });

  final _TimelineEntryKind kind;
  final int timestampMs;
  final String pageId;
}

/// Fase 4 del roadmap de producto — "Cambios recientes". Antes esto solo
/// reutilizaba `RecentPageVisitsStore` (visitas de navegación) porque Folio
/// no tenía ninguna otra señal de actividad real que mostrar. Ahora también
/// fusiona `VaultSession.recentActivityEvents` (turnos de Quill que
/// modificaron contenido — Fase 4, alimentado por el mismo gancho de la
/// Fase 0/`recordAiTurnActivity`), ordenado por tiempo — una sola línea de
/// tiempo, no dos widgets paralelos. Ediciones manuales y eventos de sync
/// quedan fuera de este merge: no hay hoy una fuente de verdad equivalente
/// para "edición manual puntual" (solo revisiones completas de página) ni
/// para "evento de sync" en un formato compatible con esta lista — añadirlos
/// es una extensión directa de este mismo esquema, no una reescritura.
class ActivityWidgetPlugin extends FolioWidgetPlugin {
  const ActivityWidgetPlugin();

  @override
  String get id => 'activity';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetActivity;

  @override
  IconData get icon => Icons.timeline_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final limit = _intSetting(instance.settings, 'limit', 8);
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: _ActivityList(ctx: ctx, limit: limit),
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
      text: _intSetting(instance.settings, 'limit', 8).toString(),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).widgetMaxEntriesLabel,
        hintText: '8',
      ),
      onChanged: (v) {
        final n = int.tryParse(v.trim());
        if (n == null || n < 1) return;
        settings['limit'] = n;
        onSettingsChanged({...settings});
      },
    );
  }
}

class _ActivityList extends StatefulWidget {
  const _ActivityList({required this.ctx, required this.limit});

  final WidgetPluginContext ctx;
  final int limit;

  @override
  State<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<_ActivityList> {
  late Future<List<RecentPageVisit>> _future;

  @override
  void initState() {
    super.initState();
    _reloadFuture();
  }

  @override
  void didUpdateWidget(covariant _ActivityList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.limit != widget.limit) {
      _reloadFuture();
    }
  }

  void _reloadFuture() {
    _future = RecentPageVisitsStore.load(
      vaultId: VaultPaths.activeVaultId,
      validPageIds: widget.ctx.session.pages.map((p) => p.id).toSet(),
      limit: widget.limit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecentPageVisit>>(
      future: _future,
      builder: (context, snapshot) {
        final visits = snapshot.data ?? const <RecentPageVisit>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        // Fase 4 — se envuelve en ListenableBuilder solo aquí (no en todo
        // el FutureBuilder) para que los turnos de Quill nuevos aparezcan
        // en vivo sin tener que releer `RecentPageVisitsStore` del disco.
        return ListenableBuilder(
          listenable: widget.ctx.session,
          builder: (context, _) => _buildTimeline(context, visits),
        );
      },
    );
  }

  Widget _buildTimeline(BuildContext context, List<RecentPageVisit> visits) {
    final l10n = AppLocalizations.of(context);
    final byId = {for (final p in widget.ctx.session.pages) p.id: p};

    final entries = <_TimelineEntry>[
      for (final v in visits)
        if (byId.containsKey(v.pageId))
          _TimelineEntry(
            kind: _TimelineEntryKind.visit,
            timestampMs: v.visitedAtMs,
            pageId: v.pageId,
          ),
      for (final e in widget.ctx.session.recentActivityEvents)
        if (byId.containsKey(e.pageId))
          _TimelineEntry(
            kind: _TimelineEntryKind.aiEdit,
            timestampMs: e.timestampMs,
            pageId: e.pageId,
          ),
    ]..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    final shown = entries.take(widget.limit).toList();

    if (shown.isEmpty) {
      return BuiltinWidgetEmpty(message: l10n.widgetActivityEmpty);
    }

    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final entry = shown[index];
        final page = byId[entry.pageId]!;
        final at = DateTime.fromMillisecondsSinceEpoch(entry.timestampMs);
        final agoText = _relativeVisitTime(l10n, at, now);
        final isAiEdit = entry.kind == _TimelineEntryKind.aiEdit;
        final title = isAiEdit
            ? l10n.widgetActivityQuillEdited(
                page.title.isEmpty ? l10n.untitled : page.title,
              )
            : (page.title.isEmpty ? l10n.untitled : page.title);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isAiEdit
                        ? scheme.primaryContainer.withValues(alpha: 0.5)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isAiEdit
                      ? Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: scheme.primary,
                        )
                      : (page.emoji != null && page.emoji!.isNotEmpty
                          ? Text(
                              page.emoji!,
                              style: const TextStyle(fontSize: 14),
                            )
                          : Icon(
                              page.isFolder
                                  ? Icons.folder_outlined
                                  : Icons.description_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            )),
                ),
                if (index < shown.length - 1)
                  Container(
                    width: 2,
                    height: 20,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => widget.ctx.onSelectPage?.call(page.id),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        agoText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
