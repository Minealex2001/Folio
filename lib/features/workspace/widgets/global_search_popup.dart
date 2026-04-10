import 'dart:async';

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
  });

  final VaultSession session;
  final AppSettings appSettings;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
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
    final includeTitle = tasksOnly ||
        _scope == _GlobalSearchScope.all ||
        _scope == _GlobalSearchScope.title;
    final includeContent = tasksOnly ||
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

  void _showShortcutsHelp(AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.searchShortcutsHelpTitle),
        content: Text(l10n.searchShortcutsHelpBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
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
    final lowerSnippet = snippet.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final idx = lowerSnippet.indexOf(lowerQuery);
    if (idx < 0) {
      return TextSpan(text: snippet);
    }
    final end = idx + query.length;
    final scheme = Theme.of(context).colorScheme;
    return TextSpan(
      children: [
        if (idx > 0) TextSpan(text: snippet.substring(0, idx)),
        TextSpan(
          text: snippet.substring(idx, end),
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            backgroundColor: scheme.secondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (end < snippet.length) TextSpan(text: snippet.substring(end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final recent = widget.appSettings.recentSearchQueries;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
            () => _nudgeSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
            () => _nudgeSelection(-1),
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Semantics(
              label: l10n.search,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          focusNode: _focus,
                          autofocus: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: l10n.searchAllVaultHint,
                          ),
                          onChanged: (_) => _refresh(),
                          onSubmitted: (_) {
                            if (_results.isNotEmpty) {
                              unawaited(_pick(_results[_selectedIndex]));
                            }
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.searchShortcutsHelpTooltip,
                        onPressed: () => _showShortcutsHelp(l10n),
                        icon: const Icon(Icons.help_outline_rounded),
                      ),
                    ],
                  ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.searchRecentQueries,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final q in recent)
                          ActionChip(
                            label: Text(
                              q,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () {
                              _query.text = q;
                              _refresh();
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
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
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final r = _results[i];
                              final selected = i == _selectedIndex;
                              return ListTile(
                                dense: true,
                                selected: selected,
                                tileColor: selected
                                    ? scheme.secondaryContainer.withValues(
                                        alpha: 0.5,
                                      )
                                    : null,
                                leading: Icon(
                                  r.matchKind == VaultSearchMatchKind.title
                                      ? Icons.title_rounded
                                      : Icons.notes_rounded,
                                ),
                                title: Text(
                                  r.pageTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text.rich(
                                  TextSpan(
                                    style: DefaultTextStyle.of(context).style,
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
                                onTap: () => unawaited(_pick(r)),
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
