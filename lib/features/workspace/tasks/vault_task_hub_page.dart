import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/vault_task_list_entry.dart';
import '../../../session/vault_session.dart';
import 'vault_task_entry_filters.dart';

/// Vista de tareas de toda la libreta (no requiere página con bloque Kanban).
class VaultTaskHubPage extends StatefulWidget {
  const VaultTaskHubPage({
    super.key,
    required this.session,
    required this.onOpenTaskInPage,
  });

  final VaultSession session;
  final void Function(String pageId, String blockId) onOpenTaskInPage;

  @override
  State<VaultTaskHubPage> createState() => _VaultTaskHubPageState();
}

class _VaultTaskHubPageState extends State<VaultTaskHubPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  VaultTaskListPreset _preset = VaultTaskListPreset.active;
  var _includeTodos = true;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  void _onSearch() {
    if (mounted) setState(() {});
  }

  List<VaultTaskListEntry> _visibleEntries() {
    final now = DateTime.now();
    final q = _searchCtrl.text.trim().toLowerCase();
    final all = widget.session.collectTaskBlocks(
      includeSimpleTodos: _includeTodos,
    );
    final filtered = all
        .where((e) => vaultTaskEntryMatchesPreset(_preset, e, now))
        .where((e) => vaultTaskEntryMatchesSearch(e, q))
        .where(
          (e) => e.blockType != 'task' || (e.task?.parentTaskId ?? '').isEmpty,
        )
        .toList();
    filtered.sort(vaultTaskSortByDueThenTitle);
    return filtered;
  }

  String? _subtitleDue(VaultTaskListEntry e) {
    final d = e.dueDate;
    if (d == null || d.trim().isEmpty) return null;
    return d.replaceFirst('T', ' ');
  }

  Future<void> _openMoveTaskDialog(VaultTaskListEntry e) async {
    final l10n = AppLocalizations.of(context);
    final pages = widget.session.pages.toList();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.taskVaultMovePickTitle),
        content: SizedBox(
          width: 440,
          height: 380,
          child: ListView.separated(
            itemCount: pages.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final p = pages[i];
              final title = p.title.trim().isEmpty ? l10n.untitled : p.title;
              return ListTile(
                title: Text(title),
                enabled: p.id != e.pageId,
                onTap: () => Navigator.of(ctx).pop<String>(p.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop<String>(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (!mounted || picked == null || picked.isEmpty || picked == e.pageId) {
      return;
    }
    widget.session.moveBlockToPage(
      fromPageId: e.pageId,
      toPageId: picked,
      blockId: e.blockId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = _visibleEntries();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskHubTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(FolioSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.vaultTaskHubSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: FolioSpace.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.taskHubFilterAll),
                  selected: _preset == VaultTaskListPreset.all,
                  onSelected: (_) =>
                      setState(() => _preset = VaultTaskListPreset.all),
                ),
                ChoiceChip(
                  label: Text(l10n.taskHubFilterActive),
                  selected: _preset == VaultTaskListPreset.active,
                  onSelected: (_) =>
                      setState(() => _preset = VaultTaskListPreset.active),
                ),
                ChoiceChip(
                  label: Text(l10n.taskHubFilterDone),
                  selected: _preset == VaultTaskListPreset.done,
                  onSelected: (_) =>
                      setState(() => _preset = VaultTaskListPreset.done),
                ),
                ChoiceChip(
                  label: Text(l10n.taskHubFilterDueToday),
                  selected: _preset == VaultTaskListPreset.dueToday,
                  onSelected: (_) =>
                      setState(() => _preset = VaultTaskListPreset.dueToday),
                ),
                ChoiceChip(
                  label: Text(l10n.vaultTaskPresetNext7Days),
                  selected: _preset == VaultTaskListPreset.next7Days,
                  onSelected: (_) =>
                      setState(() => _preset = VaultTaskListPreset.next7Days),
                ),
                ChoiceChip(
                  label: Text(l10n.taskHubFilterOverdue),
                  selected: _preset == VaultTaskListPreset.overdue,
                  onSelected: (_) =>
                      setState(() => _preset = VaultTaskListPreset.overdue),
                ),
                ChoiceChip(
                  label: Text(l10n.vaultTaskPresetNoDueDate),
                  selected: _preset == VaultTaskListPreset.noDueDate,
                  onSelected: (_) =>
                      setState(() => _preset = VaultTaskListPreset.noDueDate),
                ),
                FilterChip(
                  label: Text(l10n.taskHubIncludeTodos),
                  selected: _includeTodos,
                  onSelected: (v) => setState(() => _includeTodos = v),
                ),
              ],
            ),
            const SizedBox(height: FolioSpace.md),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.taskHubEmpty,
                        style: textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final dueLine = _subtitleDue(e);
                        final tags = e.task?.tags ?? const [];
                        final tagStr = tags.isEmpty
                            ? ''
                            : tags.take(4).join(', ');
                        return ListTile(
                          title: Text(e.displayTitle),
                          subtitle: Text(
                            [
                              e.pageTitle,
                              ?dueLine,
                              if (tagStr.isNotEmpty) tagStr,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Icon(
                            e.isDone
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: e.isDone
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (v) {
                                  if (v == 'move') {
                                    unawaited(_openMoveTaskDialog(e));
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem<String>(
                                    value: 'move',
                                    child: Text(l10n.taskVaultMoveToPage),
                                  ),
                                ],
                              ),
                              if (!e.isDone)
                                IconButton(
                                  tooltip: l10n.taskHubMarkDone,
                                  icon: const Icon(Icons.done_rounded),
                                  onPressed: () {
                                    widget.session.setTaskBlockDone(
                                      e.pageId,
                                      e.blockId,
                                      done: true,
                                    );
                                  },
                                ),
                              IconButton(
                                tooltip: l10n.taskHubOpen,
                                icon: const Icon(Icons.open_in_new_rounded),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onOpenTaskInPage(e.pageId, e.blockId);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onOpenTaskInPage(e.pageId, e.blockId);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
