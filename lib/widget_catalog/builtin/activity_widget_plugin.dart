import 'package:flutter/material.dart';

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

String _relativeVisitTime(DateTime visited, DateTime now) {
  final ago = now.difference(visited);
  if (ago.inMinutes < 1) return 'ahora mismo';
  if (ago.inHours < 1) return 'hace ${ago.inMinutes} min';
  if (ago.inDays < 1) return 'hace ${ago.inHours} h';
  return 'hace ${ago.inDays} d';
}

/// Actividad reciente — Folio no lleva un log de eventos dedicado, así que
/// esto reutiliza la misma fuente de verdad que "Recientes"
/// (`RecentPageVisitsStore`) presentada como una línea de tiempo relativa,
/// en vez de inventar un feed de actividad separado.
class ActivityWidgetPlugin extends FolioWidgetPlugin {
  const ActivityWidgetPlugin();

  @override
  String get id => 'activity';

  @override
  String displayName(BuildContext context) => 'Actividad';

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
      decoration: const InputDecoration(
        labelText: 'Máximo de entradas',
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
        if (visits.isEmpty) {
          return const BuiltinWidgetEmpty(message: 'Sin actividad todavía.');
        }
        final byId = {for (final p in widget.ctx.session.pages) p.id: p};
        final now = DateTime.now();
        final scheme = Theme.of(context).colorScheme;
        return ListView.builder(
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            final page = byId[visit.pageId];
            if (page == null) return const SizedBox.shrink();
            final visited = DateTime.fromMillisecondsSinceEpoch(
              visit.visitedAtMs,
            );
            final agoText = _relativeVisitTime(visited, now);
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
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: page.emoji != null && page.emoji!.isNotEmpty
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
                            ),
                    ),
                    if (index < visits.length - 1)
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
                            page.title.isEmpty ? 'Sin título' : page.title,
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
      },
    );
  }
}
