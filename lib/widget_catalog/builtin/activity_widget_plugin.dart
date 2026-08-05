import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../data/vault_paths.dart';
import '../../features/workspace/recent_page_visits.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

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
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: _ActivityList(ctx: ctx),
    );
  }
}

class _ActivityList extends StatefulWidget {
  const _ActivityList({required this.ctx});

  final WidgetPluginContext ctx;

  @override
  State<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<_ActivityList> {
  // Bug real reportado: construir el Future dentro de `build()` (como
  // argumento inline de FutureBuilder) crea uno NUEVO cada vez que el
  // padre reconstruye — y DashboardGridRegion reconstruye a menudo (todo
  // el AnimatedBuilder de controller). FutureBuilder entonces vuelve al
  // estado "cargando" en cada rebuild, así que el widget parpadeaba sin
  // parar en vez de cargar una sola vez. Cachear el Future en initState lo
  // arregla.
  late final Future<List<RecentPageVisit>> _future = RecentPageVisitsStore.load(
    vaultId: VaultPaths.activeVaultId,
    validPageIds: widget.ctx.session.pages.map((p) => p.id).toSet(),
  );

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
          return const BuiltinWidgetComingSoon(message: 'Sin actividad todavía.');
        }
        final byId = {for (final p in widget.ctx.session.pages) p.id: p};
        final now = DateTime.now();
        return ListView.builder(
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            final page = byId[visit.pageId];
            if (page == null) return const SizedBox.shrink();
            final visited = DateTime.fromMillisecondsSinceEpoch(
              visit.visitedAtMs,
            );
            final ago = now.difference(visited);
            final agoText = ago.inMinutes < 1
                ? 'ahora mismo'
                : ago.inHours < 1
                ? 'hace ${ago.inMinutes} min'
                : ago.inDays < 1
                ? 'hace ${ago.inHours} h'
                : 'hace ${ago.inDays} d';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle, size: 8),
              title: Text(
                page.title.isEmpty ? 'Sin título' : page.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                agoText,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => widget.ctx.onSelectPage?.call(page.id),
            );
          },
        );
      },
    );
  }
}
