import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_feedback.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../data/vault_registry.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.session,
    this.onSearch,
    this.onOpenSettings,
    this.onLock,
  });

  final VaultSession session;
  final VoidCallback? onSearch;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLock;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  static const _collapsedPrefix = 'folio_sidebar_collapsed_pages_';
  static const _recentPrefix = 'folio_sidebar_recent_pages_';
  static const _recentLimit = 6;

  VaultSession get session => widget.session;

  List<VaultEntry> _vaults = [];
  var _vaultsLoading = true;
  String? _hoveredPageId;
  final Set<String> _collapsedPageIds = <String>{};
  final ScrollController _pagesScrollController = ScrollController();
  String? _loadedCollapsedVaultId;
  final List<String> _recentPageIds = <String>[];
  String? _loadedRecentVaultId;
  String? _lastSelectedPageId;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
    unawaited(_loadCollapsedState());
    unawaited(_loadRecentState());
    _reloadVaults();
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    _pagesScrollController.dispose();
    super.dispose();
  }

  void _onSession() {
    final currentVaultId = session.activeVaultId;
    if (_loadedCollapsedVaultId != currentVaultId) {
      unawaited(_loadCollapsedState());
    }
    if (_loadedRecentVaultId != currentVaultId) {
      unawaited(_loadRecentState());
    }
    final selectedId = session.selectedPageId;
    if (selectedId != null && selectedId != _lastSelectedPageId) {
      _lastSelectedPageId = selectedId;
      _registerRecentPage(selectedId);
    }
    _reloadVaults();
  }

  String _collapsedPrefsKey(String? vaultId) {
    final safeVault = (vaultId == null || vaultId.isEmpty)
        ? 'default'
        : vaultId;
    return '$_collapsedPrefix$safeVault';
  }

  String _recentPrefsKey(String? vaultId) {
    final safeVault = (vaultId == null || vaultId.isEmpty)
        ? 'default'
        : vaultId;
    return '$_recentPrefix$safeVault';
  }

  Future<void> _loadCollapsedState() async {
    final vaultId = session.activeVaultId;
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getStringList(_collapsedPrefsKey(vaultId)) ?? const <String>[];
    final validPageIds = session.pages.map((p) => p.id).toSet();
    final restored = saved.where(validPageIds.contains).toSet();
    if (!mounted) return;
    setState(() {
      _loadedCollapsedVaultId = vaultId;
      _collapsedPageIds
        ..clear()
        ..addAll(restored);
    });
  }

  Future<void> _persistCollapsedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _collapsedPrefsKey(session.activeVaultId),
      _collapsedPageIds.toList()..sort(),
    );
  }

  Future<void> _loadRecentState() async {
    final vaultId = session.activeVaultId;
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getStringList(_recentPrefsKey(vaultId)) ?? const <String>[];
    final validPageIds = session.pages.map((p) => p.id).toSet();
    final restored = saved
        .where(validPageIds.contains)
        .take(_recentLimit)
        .toList();
    if (!mounted) return;
    setState(() {
      _loadedRecentVaultId = vaultId;
      _recentPageIds
        ..clear()
        ..addAll(restored);
    });
  }

  Future<void> _persistRecentState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentPrefsKey(session.activeVaultId),
      _recentPageIds.take(_recentLimit).toList(growable: false),
    );
  }

  void _registerRecentPage(String pageId) {
    if (!session.pages.any((p) => p.id == pageId)) return;
    setState(() {
      _recentPageIds.remove(pageId);
      _recentPageIds.insert(0, pageId);
      if (_recentPageIds.length > _recentLimit) {
        _recentPageIds.removeRange(_recentLimit, _recentPageIds.length);
      }
    });
    unawaited(_persistRecentState());
  }

  Future<void> _reloadVaults() async {
    final list = await session.listVaultEntries();
    final validPageIds = session.pages.map((p) => p.id).toSet();
    var changedCollapsedState = false;
    _collapsedPageIds.removeWhere((id) {
      final remove = !validPageIds.contains(id);
      if (remove) changedCollapsedState = true;
      return remove;
    });
    if (changedCollapsedState) {
      unawaited(_persistCollapsedState());
    }
    var changedRecentState = false;
    _recentPageIds.removeWhere((id) {
      final remove = !validPageIds.contains(id);
      if (remove) changedRecentState = true;
      return remove;
    });
    if (changedRecentState) {
      unawaited(_persistRecentState());
    }
    if (mounted) {
      setState(() {
        _vaults = list;
        _vaultsLoading = false;
      });
    }
  }

  List<FolioPage> _childrenOf(List<FolioPage> all, String? parentId) {
    final out = <FolioPage>[];
    for (final p in all) {
      if (p.parentId == parentId) {
        out.add(p);
      }
    }
    return out;
  }

  bool _hasChildren(FolioPage p) =>
      session.pages.any((x) => x.parentId == p.id);

  bool _isCollapsed(String pageId) => _collapsedPageIds.contains(pageId);

  void _toggleCollapsed(String pageId) {
    setState(() {
      if (_collapsedPageIds.contains(pageId)) {
        _collapsedPageIds.remove(pageId);
      } else {
        _collapsedPageIds.add(pageId);
      }
    });
    unawaited(_persistCollapsedState());
  }

  Future<void> _setPageEmoji(BuildContext context, FolioPage page) async {
    final l10n = AppLocalizations.of(context);
    const quickEmojis = <String>[
      '📄',
      '📝',
      '✅',
      '📌',
      '📚',
      '💡',
      '🚀',
      '🧠',
      '🎯',
      '🔧',
      '📊',
      '💼',
      '🏠',
      '🧪',
      '🎨',
      '🔒',
    ];
    final initial = (page.emoji ?? '').trim();
    var selected = initial;
    final emoji = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return FolioDialog(
            title: Text(l10n.renamePageTitle),
            contentWidth: 420,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elige un emoji rápido o escribe uno personalizado.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: FolioSpace.sm),
                Wrap(
                  spacing: FolioSpace.xs,
                  runSpacing: FolioSpace.xs,
                  children: quickEmojis.map((item) {
                    final active = selected == item;
                    return ChoiceChip(
                      selected: active,
                      label: Text(item, style: const TextStyle(fontSize: 18)),
                      onSelected: (_) {
                        setDialogState(() {
                          selected = item;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: FolioSpace.sm),
                TextFormField(
                  initialValue: initial,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Emoji personalizado',
                    hintText: '😀',
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      selected = value.trim();
                    });
                  },
                  onFieldSubmitted: (_) {
                    Navigator.of(ctx).pop(selected.trim());
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(''),
                child: const Text('Quitar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(selected.trim()),
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || emoji == null) return;
    session.setPageEmoji(page.id, emoji);
  }

  Future<void> _confirmSwitchVault(String vaultId) async {
    final l10n = AppLocalizations.of(context);
    if (vaultId == session.activeVaultId) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.switchVaultTitle),
        content: Text(l10n.switchVaultBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.change),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await session.switchVault(vaultId);
    }
  }

  Future<void> _addVault() async {
    try {
      await session.prepareNewVault();
    } catch (e) {
      if (mounted) {
        showFolioSnack(context, '$e', error: true);
      }
    }
  }

  Future<void> _renameActiveVault() async {
    final l10n = AppLocalizations.of(context);
    final activeId = session.activeVaultId;
    if (activeId == null) return;
    VaultEntry? entry;
    for (final e in _vaults) {
      if (e.id == activeId) {
        entry = e;
        break;
      }
    }
    final controller = TextEditingController(text: entry?.displayName ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.renameVaultTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.nameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await session.renameActiveVault(controller.text);
    }
    controller.dispose();
  }

  Widget _vaultToolbar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_vaultsLoading || _vaults.isEmpty) {
      return const SizedBox.shrink();
    }
    final activeId = session.activeVaultId;
    VaultEntry? current;
    for (final e in _vaults) {
      if (e.id == activeId) {
        current = e;
        break;
      }
    }
    current ??= _vaults.first;

    return Padding(
      padding: const EdgeInsets.all(FolioSpace.sm),
      child: PopupMenuButton<String>(
        tooltip: l10n.switchVaultTooltip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.md),
        ),
        offset: const Offset(0, 64),
        onSelected: (value) {
          if (value == 'add') {
            _addVault();
          } else if (value == 'rename') {
            _renameActiveVault();
          } else {
            _confirmSwitchVault(value);
          }
        },
        itemBuilder: (ctx) => [
          for (final e in _vaults)
            PopupMenuItem(
              value: e.id,
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(e.displayName),
                trailing: e.id == activeId ? const Icon(Icons.check) : null,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'add',
            child: ListTile(
              leading: Icon(Icons.add_circle_outline),
              title: Text(l10n.addVault),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text(l10n.renameActiveVault),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(FolioSpace.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(FolioRadius.md),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: FolioSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.activeVaultLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      current.displayName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _rename(BuildContext context, FolioPage page) {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController(text: page.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.renamePageTitle),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.titleLabel),
          onSubmitted: (_) => Navigator.of(ctx).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              session.renamePage(page.id, titleController.text);
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    ).then((_) => titleController.dispose());
  }

  void _move(BuildContext context, FolioPage page) {
    final l10n = AppLocalizations.of(context);
    final options = <MapEntry<String?, String>>[
      MapEntry(null, l10n.rootPage),
      ...session.pages
          .where(
            (p) =>
                p.id != page.id &&
                !session.isUnderAncestor(ancestorId: page.id, nodeId: p.id),
          )
          .map((p) => MapEntry(p.id, p.title)),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return FolioDialog(
          title: Text(l10n.movePageTitle(page.title)),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map(
                    (e) => ListTile(
                      title: Text(e.value),
                      trailing: page.parentId == e.key
                          ? const Icon(Icons.check, size: 20)
                          : null,
                      onTap: () {
                        session.setPageParent(page.id, e.key);
                        Navigator.pop(ctx);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, FolioPage page, double indent) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = page.id == session.selectedPageId;
    final showRowActions = selected || _hoveredPageId == page.id;
    final hasChildren = _hasChildren(page);
    final collapsed = _isCollapsed(page.id);
    final canDelete = session.pages.length > 1 && !_hasChildren(page);

    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 0, 0, FolioSpace.xs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredPageId = page.id),
        onExit: (_) {
          if (_hoveredPageId == page.id) {
            setState(() => _hoveredPageId = null);
          }
        },
        child: Material(
          color: selected ? scheme.secondaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => session.selectPage(page.id),
            onDoubleTap: () => _rename(context, page),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FolioSpace.xs,
                vertical: FolioSpace.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (hasChildren)
                          InkWell(
                            borderRadius: BorderRadius.circular(FolioRadius.sm),
                            onTap: () => _toggleCollapsed(page.id),
                            child: Padding(
                              padding: const EdgeInsets.all(FolioSpace.xxs),
                              child: Icon(
                                collapsed
                                    ? Icons.chevron_right_rounded
                                    : Icons.expand_more_rounded,
                                size: 18,
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: FolioSpace.xxs),
                        Text(
                          page.emoji ?? '📄',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: FolioSpace.xs),
                        Expanded(
                          child: Text(
                            page.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: FolioMotion.short2,
                    opacity: showRowActions ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.onSecondaryContainer.withValues(
                                alpha: FolioAlpha.faint,
                              )
                            : scheme.surfaceContainerHighest.withValues(
                                alpha: FolioAlpha.panel,
                              ),
                        borderRadius: BorderRadius.circular(FolioRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.emoji_emotions_outlined,
                              size: 18,
                            ),
                            tooltip: 'Emoji',
                            visualDensity: VisualDensity.compact,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                            onPressed: () => _setPageEmoji(context, page),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            tooltip: l10n.subpage,
                            visualDensity: VisualDensity.compact,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                            onPressed: () {
                              session.addPage(parentId: page.id);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.drive_file_move_outline,
                              size: 18,
                            ),
                            tooltip: l10n.move,
                            visualDensity: VisualDensity.compact,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                            onPressed: () => _move(context, page),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: l10n.rename,
                            visualDensity: VisualDensity.compact,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                            onPressed: () => _rename(context, page),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: l10n.delete,
                            visualDensity: VisualDensity.compact,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                            onPressed: canDelete
                                ? () => session.deletePage(page.id)
                                : null,
                          ),
                        ],
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

  List<Widget> _buildLevel(
    BuildContext context,
    String? parentId,
    double indent,
  ) {
    final kids = _childrenOf(session.pages, parentId);
    final tiles = <Widget>[];
    for (final p in kids) {
      tiles.add(_tile(context, p, indent));
      if (_hasChildren(p) && !_isCollapsed(p.id)) {
        tiles.addAll(_buildLevel(context, p.id, indent + 14));
      }
    }
    return tiles;
  }

  Widget _recentPagesSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pagesById = <String, FolioPage>{
      for (final p in session.pages) p.id: p,
    };
    final recentPages = _recentPageIds
        .map((id) => pagesById[id])
        .whereType<FolioPage>()
        .toList(growable: false);
    if (recentPages.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FolioSpace.sm,
        0,
        FolioSpace.sm,
        FolioSpace.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(FolioSpace.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recientes',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FolioSpace.xs),
            Wrap(
              spacing: FolioSpace.xs,
              runSpacing: FolioSpace.xs,
              children: recentPages
                  .map((page) {
                    return ActionChip(
                      onPressed: () => session.selectPage(page.id),
                      avatar: Text(
                        page.emoji ?? '📄',
                        style: const TextStyle(fontSize: 14),
                      ),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          page.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showDeskTools =
        widget.onSearch != null &&
        widget.onOpenSettings != null &&
        widget.onLock != null;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _vaultToolbar(context),
        if (showDeskTools)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.sm,
              0,
              FolioSpace.sm,
              FolioSpace.sm,
            ),
            child: Container(
              padding: const EdgeInsets.all(FolioSpace.xs),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(FolioRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: widget.onSearch,
                      icon: const Icon(Icons.search_rounded),
                      label: Text(l10n.search),
                    ),
                  ),
                  const SizedBox(width: FolioSpace.xs),
                  IconButton(
                    tooltip: l10n.settings,
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: widget.onOpenSettings,
                  ),
                  IconButton(
                    tooltip: l10n.lockNow,
                    icon: const Icon(Icons.lock_outline_rounded),
                    onPressed: widget.onLock,
                  ),
                ],
              ),
            ),
          ),
        _recentPagesSection(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FolioSpace.md,
            FolioSpace.sm,
            FolioSpace.sm,
            FolioSpace.sm,
          ),
          child: Row(
            children: [
              Text(
                l10n.pages,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => session.addPage(parentId: null),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.createPage),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              FolioSpace.sm,
              0,
              FolioSpace.sm,
              FolioSpace.sm,
            ),
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.xs,
              FolioSpace.xs,
              FolioSpace.xs,
              FolioSpace.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(FolioRadius.xl),
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: FolioAlpha.track,
                ),
              ),
            ),
            child: Scrollbar(
              controller: _pagesScrollController,
              child: ListView(
                controller: _pagesScrollController,
                padding: EdgeInsets.zero,
                children: _buildLevel(context, null, 4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
