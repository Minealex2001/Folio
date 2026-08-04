import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../data/vault_paths.dart';
import '../../features/workspace/recent_page_visits.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.recents` — lee
/// `RecentPageVisitsStore` (persistido en SharedPreferences, misma fuente
/// que el sidebar) y las resuelve contra `VaultSession.pages`.
class RecentsWidgetPlugin extends FolioWidgetPlugin {
  const RecentsWidgetPlugin();

  @override
  String get id => 'recents';

  @override
  String displayName(BuildContext context) => 'Recientes';

  @override
  IconData get icon => Icons.history_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final validIds = ctx.session.pages.map((p) => p.id).toSet();
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: FutureBuilder<List<RecentPageVisit>>(
        future: RecentPageVisitsStore.load(
          vaultId: VaultPaths.activeVaultId,
          validPageIds: validIds,
          limit: kRecentPageVisitsHomeLoadLimit,
        ),
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
            return const BuiltinWidgetComingSoon(
              message: 'Todavía no has visitado ninguna página.',
            );
          }
          final byId = {for (final p in ctx.session.pages) p.id: p};
          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final page = byId[visits[index].pageId];
              if (page == null) return const SizedBox.shrink();
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: page.emoji != null && page.emoji!.isNotEmpty
                    ? Text(page.emoji!, style: const TextStyle(fontSize: 16))
                    : const Icon(Icons.description_outlined, size: 18),
                title: Text(
                  page.title.isEmpty ? 'Sin título' : page.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => ctx.onSelectPage?.call(page.id),
              );
            },
          );
        },
      ),
    );
  }
}
