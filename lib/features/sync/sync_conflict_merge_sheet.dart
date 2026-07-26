import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';
import '../../services/sync/sync_block_text_merge.dart';

/// Abre el sheet reutilizable de resolución de conflictos de sync (estilo merge).
Future<void> showSyncConflictMergeSheet({
  required BuildContext context,
  required VaultSession session,
  String? filterPageId,
  void Function(String pageId)? onOpenPage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return SyncConflictMergeSheet(
        session: session,
        filterPageId: filterPageId,
        onOpenPage: onOpenPage,
      );
    },
  );
}

class SyncConflictMergeSheet extends StatefulWidget {
  const SyncConflictMergeSheet({
    super.key,
    required this.session,
    this.filterPageId,
    this.onOpenPage,
  });

  final VaultSession session;
  final String? filterPageId;
  final void Function(String pageId)? onOpenPage;

  @override
  State<SyncConflictMergeSheet> createState() => _SyncConflictMergeSheetState();
}

class _SyncConflictMergeSheetState extends State<SyncConflictMergeSheet> {
  String? _selectedConflictId;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    final list = _visibleConflicts();
    if (list.isNotEmpty) {
      _selectedConflictId = list.first.id;
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    final list = _visibleConflicts();
    setState(() {
      if (_selectedConflictId == null ||
          !list.any((c) => c.id == _selectedConflictId)) {
        _selectedConflictId = list.isEmpty ? null : list.first.id;
      }
    });
  }

  List<SyncConflictEntry> _visibleConflicts() {
    final all = widget.session.syncConflicts;
    final pageFilter = widget.filterPageId?.trim();
    if (pageFilter == null || pageFilter.isEmpty) return all;
    return all.where((c) => c.pageId == pageFilter).toList();
  }

  SyncConflictEntry? _selected() {
    final id = _selectedConflictId;
    if (id == null) return null;
    for (final c in _visibleConflicts()) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _pageTitle(AppLocalizations l10n, SyncConflictEntry c) {
    final pid = c.pageId;
    if (pid == null || pid.isEmpty) {
      return l10n.syncConflictMergeLegacyTitle;
    }
    for (final p in widget.session.pages) {
      if (p.id == pid) {
        final t = p.title.trim();
        return t.isEmpty ? l10n.untitled : t;
      }
    }
    return l10n.syncConflictMergeMissingPage;
  }

  String _blockTypeLabel(AppLocalizations l10n, SyncConflictEntry c) {
    final type = '${c.localBlockJson?['type'] ?? c.remoteBlockJson?['type'] ?? ''}'
        .trim();
    if (type.isEmpty) return l10n.syncConflictMergeUnknownBlock;
    return l10n.syncConflictMergeBlockType(type);
  }

  String _formatTime(int ms) {
    final at = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
  }

  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conflicts = _visibleConflicts();
    final selected = _selected();
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              l10n.syncConflictMergeSheetTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (conflicts.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.settingsNoPendingConflicts),
                ),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 720;
                  final list = Material(
                    color: scheme.surfaceContainerLow,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: conflicts.length,
                      itemBuilder: (context, index) {
                        final c = conflicts[index];
                        final selectedRow = c.id == _selectedConflictId;
                        return ListTile(
                          selected: selectedRow,
                          title: Text(
                            _pageTitle(l10n, c),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            c.isBlockConflict
                                ? '${_blockTypeLabel(l10n, c)} · ${_formatTime(c.createdAtMs)}'
                                : '${l10n.syncConflictMergeLegacyTitle} · ${_formatTime(c.createdAtMs)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () =>
                              setState(() => _selectedConflictId = c.id),
                        );
                      },
                    ),
                  );
                  final detail = selected == null
                      ? const SizedBox.shrink()
                      : _ConflictDetailPane(
                          session: widget.session,
                          conflict: selected,
                          pageTitle: _pageTitle(l10n, selected),
                          blockTypeLabel: _blockTypeLabel(l10n, selected),
                          detectedAt: _formatTime(selected.createdAtMs),
                          onOpenPage: widget.onOpenPage,
                          onSnack: _snack,
                        );
                  if (narrow) {
                    return Column(
                      children: [
                        SizedBox(height: 160, child: list),
                        Divider(
                          height: 1,
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        Expanded(child: detail),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 280, child: list),
                      VerticalDivider(
                        width: 1,
                        color:
                            scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      Expanded(child: detail),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ConflictDetailPane extends StatefulWidget {
  const _ConflictDetailPane({
    required this.session,
    required this.conflict,
    required this.pageTitle,
    required this.blockTypeLabel,
    required this.detectedAt,
    required this.onOpenPage,
    required this.onSnack,
  });

  final VaultSession session;
  final SyncConflictEntry conflict;
  final String pageTitle;
  final String blockTypeLabel;
  final String detectedAt;
  final void Function(String pageId)? onOpenPage;
  final Future<void> Function(String message) onSnack;

  @override
  State<_ConflictDetailPane> createState() => _ConflictDetailPaneState();
}

class _ConflictDetailPaneState extends State<_ConflictDetailPane> {
  late List<SyncMergeHunk> _hunks;
  late List<SyncMergeHunkChoice> _choices;
  bool _showIds = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rebuildHunks();
  }

  @override
  void didUpdateWidget(covariant _ConflictDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conflict.id != widget.conflict.id) {
      _rebuildHunks();
      _showIds = false;
    }
  }

  void _rebuildHunks() {
    final local =
        '${widget.conflict.localBlockJson?['text'] ?? ''}';
    final remote =
        '${widget.conflict.remoteBlockJson?['text'] ?? ''}';
    _hunks = SyncBlockTextMerge.buildHunks(local, remote);
    _choices = SyncBlockTextMerge.defaultChoices(_hunks);
  }

  String get _mergedPreview =>
      SyncBlockTextMerge.buildMergedPlainText(_hunks, _choices);

  Future<void> _keepLocal() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await widget.session.resolveSyncConflictKeepLocal(widget.conflict.id);
      await widget.onSnack(l10n.settingsLocalVersionKeptSnack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptRemote() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await widget.session
          .resolveSyncConflictAcceptRemote(widget.conflict.id);
      await widget.onSnack(
        ok
            ? l10n.settingsRemoteVersionAppliedSnack
            : l10n.settingsCouldNotApplyRemoteSnack,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyMerge() async {
    if (_busy) return;
    if (!widget.conflict.isBlockConflict) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await widget.session.resolveSyncConflictWithMergedText(
        widget.conflict.id,
        _mergedPreview,
      );
      await widget.onSnack(
        ok
            ? l10n.syncConflictMergeAppliedSnack
            : l10n.settingsCouldNotApplyRemoteSnack,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPage() {
    final pid = widget.conflict.pageId;
    if (pid == null || pid.isEmpty) return;
    final nav = Navigator.of(context);
    nav.pop();
    widget.onOpenPage?.call(pid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.35,
    );
    final c = widget.conflict;
    final peer = c.fromPeerId.trim().isEmpty
        ? l10n.syncConflictMergeUnknownDevice
        : c.fromPeerId;
    final baseText = '${c.baseBlockJson?['text'] ?? ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.pageTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                c.isBlockConflict
                    ? l10n.syncConflictMergeMetaLine(
                        widget.blockTypeLabel,
                        peer,
                        widget.detectedAt,
                      )
                    : l10n.syncConflictMergeLegacyMeta(
                        peer,
                        widget.detectedAt,
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showIds = !_showIds),
                child: Text(
                  _showIds
                      ? l10n.syncConflictMergeHideIds
                      : l10n.syncConflictMergeShowIds,
                ),
              ),
              if (_showIds)
                SelectableText(
                  [
                    if (c.pageId != null) 'pageId: ${c.pageId}',
                    if (c.blockId != null) 'blockId: ${c.blockId}',
                    'id: ${c.id}',
                    'fp: ${c.remoteFingerprint}',
                  ].join('\n'),
                  style: mono,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: !c.isBlockConflict
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.syncConflictMergeLegacyHint),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    if (c.baseBlockJson != null) ...[
                      Text(
                        l10n.syncConflictMergeOriginalTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          baseText.isEmpty ? l10n.emptyValue : baseText,
                          style: mono?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      l10n.syncConflictMergeHunksTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _hunks.length; i++)
                      _HunkCard(
                        index: i,
                        hunk: _hunks[i],
                        choice: _choices[i],
                        onChanged: (choice) {
                          setState(() => _choices[i] = choice);
                        },
                        mono: mono,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.syncConflictMergePreviewTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _mergedPreview.isEmpty
                            ? l10n.emptyValue
                            : _mergedPreview,
                        style: mono,
                      ),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (c.pageId != null &&
                  c.pageId!.isNotEmpty &&
                  widget.onOpenPage != null)
                TextButton.icon(
                  onPressed: _busy ? null : _openPage,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.syncConflictMergeOpenPage),
                ),
              TextButton(
                onPressed: _busy ? null : _keepLocal,
                child: Text(l10n.settingsKeepLocal),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : _acceptRemote,
                child: Text(l10n.settingsAcceptRemote),
              ),
              if (c.isBlockConflict)
                FilledButton(
                  onPressed: _busy ? null : _applyMerge,
                  child: Text(l10n.syncConflictMergeApply),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HunkCard extends StatelessWidget {
  const _HunkCard({
    required this.index,
    required this.hunk,
    required this.choice,
    required this.onChanged,
    required this.mono,
  });

  final int index;
  final SyncMergeHunk hunk;
  final SyncMergeHunkChoice choice;
  final ValueChanged<SyncMergeHunkChoice> onChanged;
  final TextStyle? mono;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (hunk.kind == SyncMergeHunkKind.equal) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hunk.localText.isEmpty ? l10n.emptyValue : hunk.localText,
            style: mono?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<SyncMergeHunkChoice>(
              segments: [
                ButtonSegment(
                  value: SyncMergeHunkChoice.local,
                  label: Text(l10n.syncConflictMergeYourVersion),
                ),
                ButtonSegment(
                  value: SyncMergeHunkChoice.remote,
                  label: Text(l10n.syncConflictMergeOtherVersion),
                ),
                ButtonSegment(
                  value: SyncMergeHunkChoice.both,
                  label: Text(l10n.syncConflictMergeBoth),
                ),
              ],
              selected: {choice},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                onChanged(set.first);
              },
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hunk.localText.isEmpty
                          ? l10n.emptyValue
                          : hunk.localText,
                      style: mono?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          scheme.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hunk.remoteText.isEmpty
                          ? l10n.emptyValue
                          : hunk.remoteText,
                      style:
                          mono?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
