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

/// Migración 1:1 de `WorkspaceHomeSectionIds.recents` — lee
/// `RecentPageVisitsStore` (persistido en SharedPreferences, misma fuente
/// que el sidebar) y las resuelve contra `VaultSession.pages`.
class RecentsWidgetPlugin extends FolioWidgetPlugin {
  const RecentsWidgetPlugin();

  @override
  String get id => 'recents';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetRecents;

  @override
  IconData get icon => Icons.history_rounded;

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
      child: _RecentsList(ctx: ctx, limit: limit),
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

class _RecentsList extends StatefulWidget {
  const _RecentsList({required this.ctx, required this.limit});

  final WidgetPluginContext ctx;
  final int limit;

  @override
  State<_RecentsList> createState() => _RecentsListState();
}

class _RecentsListState extends State<_RecentsList> {
  late Future<List<RecentPageVisit>> _future;

  @override
  void initState() {
    super.initState();
    _reloadFuture();
  }

  @override
  void didUpdateWidget(covariant _RecentsList oldWidget) {
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
        final l10n = AppLocalizations.of(context);
        if (visits.isEmpty) {
          return BuiltinWidgetEmpty(
            message: l10n.widgetRecentsEmpty,
          );
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
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: page.emoji != null && page.emoji!.isNotEmpty
                  ? Text(page.emoji!, style: const TextStyle(fontSize: 16))
                  : const Icon(Icons.description_outlined, size: 18),
              title: Text(
                page.title.isEmpty ? l10n.untitled : page.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _relativeVisitTime(l10n, visited, now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => widget.ctx.onSelectPage?.call(page.id),
            );
          },
        );
      },
    );
  }
}
