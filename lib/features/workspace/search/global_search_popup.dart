import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';

enum _GlobalSearchScope { all, title, content, tasks }

enum _GlobalSearchOrder { relevance, recency }

class GlobalSearchPopup extends StatefulWidget {
  const GlobalSearchPopup({
    super.key,
    required this.session,
    required this.appSettings,
    this.initialQuery,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final String? initialQuery;

  @override
  State<GlobalSearchPopup> createState() => _GlobalSearchPopupState();
}

class _GlobalSearchPopupState extends State<GlobalSearchPopup> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<VaultSearchResult> _results = const [];
  _GlobalSearchScope _scope = _GlobalSearchScope.all;
  _GlobalSearchOrder _order = _GlobalSearchOrder.relevance;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _query.text = q;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      if (q != null && q.isNotEmpty) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    final tasksOnly = _scope == _GlobalSearchScope.tasks;
    final includeTitle =
        tasksOnly ||
        _scope == _GlobalSearchScope.all ||
        _scope == _GlobalSearchScope.title;
    final includeContent =
        tasksOnly ||
        _scope == _GlobalSearchScope.all ||
        _scope == _GlobalSearchScope.content;
    setState(() {
      _results = widget.session.searchGlobal(
        _query.text,
        includeTitleMatches: includeTitle,
        includeContentMatches: includeContent,
        sortByRecency: _order == _GlobalSearchOrder.recency,
        tasksOnly: tasksOnly,
      );
      _selectedIndex = 0;
    });
  }

  void _nudgeSelection(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + delta + _results.length) % _results.length;
    });
  }

  Future<void> _pick(VaultSearchResult result) async {
    final q = _query.text.trim();
    if (q.isNotEmpty) {
      await widget.appSettings.addRecentSearchQuery(q);
    }
    widget.session.selectPage(result.pageId);
    final blockId = result.blockId;
    if (blockId != null && blockId.trim().isNotEmpty) {
      widget.session.requestScrollToBlock(blockId);
    }
    if (mounted) Navigator.of(context).pop(true);
  }



  IconData _getIconForBlockType(String? blockType) {
    if (blockType == null) return Icons.notes_rounded;
    switch (blockType) {
      case 'h1':
      case 'h2':
      case 'h3':
        return Icons.title_rounded;
      case 'todo':
      case 'task':
        return Icons.check_box_outlined;
      case 'code':
        return Icons.code_rounded;
      case 'mermaid':
        return Icons.schema_rounded;
      case 'equation':
        return Icons.functions_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'table':
        return Icons.table_chart_rounded;
      case 'quote':
        return Icons.format_quote_rounded;
      case 'callout':
        return Icons.info_outline_rounded;
      case 'file':
        return Icons.insert_drive_file_rounded;
      case 'video':
        return Icons.video_library_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'bookmark':
        return Icons.bookmark_border_rounded;
      case 'database':
        return Icons.storage_rounded;
      case 'toggle':
        return Icons.play_arrow_rounded;
      default:
        return Icons.notes_rounded;
    }
  }

  InlineSpan _buildSnippetSpan(
    BuildContext context,
    String snippet,
    String rawQuery,
  ) {
    final query = rawQuery.trim();
    if (query.isEmpty || snippet.isEmpty) {
      return TextSpan(text: snippet);
    }
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) {
      return TextSpan(text: snippet);
    }

    final lowerSnippet = snippet.toLowerCase();
    final ranges = <(int, int)>[];
    for (final term in terms) {
      var startIdx = 0;
      while (true) {
        final idx = lowerSnippet.indexOf(term, startIdx);
        if (idx < 0) break;
        ranges.add((idx, idx + term.length));
        startIdx = idx + term.length;
        if (term.isEmpty) break;
      }
    }

    if (ranges.isEmpty) {
      return TextSpan(text: snippet);
    }

    ranges.sort((a, b) {
      final cmp = a.$1.compareTo(b.$1);
      if (cmp != 0) return cmp;
      return a.$2.compareTo(b.$2);
    });

    final mergedRanges = <(int, int)>[];
    var currentRange = ranges.first;
    for (var i = 1; i < ranges.length; i++) {
      final nextRange = ranges[i];
      if (nextRange.$1 <= currentRange.$2) {
        final newEnd = currentRange.$2 > nextRange.$2 ? currentRange.$2 : nextRange.$2;
        currentRange = (currentRange.$1, newEnd);
      } else {
        mergedRanges.add(currentRange);
        currentRange = nextRange;
      }
    }
    mergedRanges.add(currentRange);

    final scheme = Theme.of(context).colorScheme;
    final highlightStyle = TextStyle(
      color: scheme.onSecondaryContainer,
      backgroundColor: scheme.secondaryContainer,
      fontWeight: FontWeight.w600,
    );

    final children = <InlineSpan>[];
    var currentPos = 0;
    for (final range in mergedRanges) {
      if (range.$1 > currentPos) {
        children.add(TextSpan(text: snippet.substring(currentPos, range.$1)));
      }
      children.add(TextSpan(
        text: snippet.substring(range.$1, range.$2),
        style: highlightStyle,
      ));
      currentPos = range.$2;
    }
    if (currentPos < snippet.length) {
      children.add(TextSpan(text: snippet.substring(currentPos)));
    }

    return TextSpan(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final recent = widget.appSettings.recentSearchQueries;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () => _nudgeSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () => _nudgeSelection(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _nudgeSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _nudgeSelection(-1),
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: scheme.surface.withValues(alpha: 0.85),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                label: l10n.search,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _query,
                      focusNode: _focus,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
                        hintText: l10n.searchAllVaultHint,
                        suffixIcon: _query.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _query.clear();
                                  _refresh();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: scheme.primary, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (_) => _refresh(),
                      onSubmitted: (_) {
                        if (_results.isNotEmpty) {
                          unawaited(_pick(_results[_selectedIndex]));
                        }
                      },
                    ),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.searchRecentQueries,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await widget.appSettings.clearRecentSearchQueries();
                              setState(() {});
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(Icons.delete_sweep_outlined, size: 14, color: scheme.error),
                            label: Text(
                              l10n.searchClearRecent,
                              style: TextStyle(fontSize: 11, color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final q in recent)
                            InputChip(
                              label: Text(
                                q,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                              onPressed: () {
                                _query.text = q;
                                _refresh();
                              },
                              onDeleted: () async {
                                await widget.appSettings.removeRecentSearchQuery(q);
                                setState(() {});
                              },
                              deleteIcon: Icon(Icons.close_rounded, size: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                              ),
                              backgroundColor: scheme.surfaceContainerLow,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.searchFilterAll),
                          selected: _scope == _GlobalSearchScope.all,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _scope = _GlobalSearchScope.all);
                            _refresh();
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.searchFilterTitles),
                          selected: _scope == _GlobalSearchScope.title,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _scope = _GlobalSearchScope.title);
                            _refresh();
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.searchFilterContent),
                          selected: _scope == _GlobalSearchScope.content,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _scope = _GlobalSearchScope.content);
                            _refresh();
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.searchFilterTasks),
                          selected: _scope == _GlobalSearchScope.tasks,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _scope = _GlobalSearchScope.tasks);
                            _refresh();
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(l10n.searchSortRelevance),
                          selected: _order == _GlobalSearchOrder.relevance,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _order = _GlobalSearchOrder.relevance);
                            _refresh();
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.searchSortRecent),
                          selected: _order == _GlobalSearchOrder.recency,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _order = _GlobalSearchOrder.recency);
                            _refresh();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _query.text.trim().isEmpty
                          ? Center(
                              child: Text(
                                l10n.typeToSearch,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            )
                          : _results.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noSearchResults,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final r = _results[i];
                                final selected = i == _selectedIndex;
                                final icon = r.matchKind == VaultSearchMatchKind.title
                                    ? Icons.article_rounded
                                    : _getIconForBlockType(r.blockType);
                                final iconColor = r.matchKind == VaultSearchMatchKind.title
                                    ? scheme.primary
                                    : scheme.secondary;
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    dense: true,
                                    selected: selected,
                                    hoverColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: selected
                                            ? scheme.primary.withValues(alpha: 0.5)
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    tileColor: selected
                                        ? scheme.primaryContainer.withValues(alpha: 0.25)
                                        : scheme.surfaceContainerLow.withValues(alpha: 0.4),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: selected
                                          ? scheme.primary.withValues(alpha: 0.15)
                                          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      child: Icon(
                                        icon,
                                        size: 16,
                                        color: selected ? scheme.primary : iconColor,
                                      ),
                                    ),
                                    title: Text(
                                      r.pageTitle,
                                      style: TextStyle(
                                        fontWeight: r.matchKind == VaultSearchMatchKind.title
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: selected ? scheme.primary : scheme.onSurface,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text.rich(
                                        TextSpan(
                                          style: DefaultTextStyle.of(context).style.copyWith(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          children: [
                                            _buildSnippetSpan(
                                              context,
                                              r.snippet,
                                              _query.text,
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    onTap: () => unawaited(_pick(r)),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.searchDialogFooterHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MiniUnlockDialog extends StatefulWidget {
  const MiniUnlockDialog({super.key, required this.session});

  final VaultSession session;

  @override
  State<MiniUnlockDialog> createState() => _MiniUnlockDialogState();
}

class _MiniUnlockDialogState extends State<MiniUnlockDialog> {
  final _password = TextEditingController();
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.unlockWithPassword(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).miniUnlockFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.unlockVaultTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: TextField(
          controller: _password,
          obscureText: _obscure,
          enabled: !_busy,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.masterPassword,
            suffixIcon: IconButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
          onSubmitted: (_) => _unlock(),
        ),
      ),
      actions: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          child: Text(l10n.unlock),
        ),
      ],
    );
  }
}
