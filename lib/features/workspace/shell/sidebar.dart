import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_feedback.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_icon_picker.dart';
import '../../../app/widgets/folio_icon_token_view.dart';
import '../../../data/vault_registry.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../templates/template_gallery_page.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.session,
    required this.appSettings,
    required this.cloudAccountController,
    this.onSearch,
    this.onForceSync,
    this.onOpenSettings,
    this.onLock,
    this.onQuickAddTask,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final CloudAccountController cloudAccountController;
  final VoidCallback? onSearch;
  final VoidCallback? onForceSync;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLock;
  final VoidCallback? onQuickAddTask;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
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
  Map<String, bool> _hasChildrenById = const <String, bool>{};

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

  String _recentPrefsKey(String? vaultId) {
    final safeVault = (vaultId == null || vaultId.isEmpty)
        ? 'default'
        : vaultId;
    return '$_recentPrefix$safeVault';
  }

  Future<void> _loadCollapsedState() async {
    final vaultId = session.activeVaultId;
    final validPageIds = session.pages.map((p) => p.id).toSet();
    final restored = await widget.appSettings
        .loadWorkspaceSidebarCollapsedPageIds(
          vaultId: vaultId,
          validPageIds: validPageIds,
        );
    if (!mounted) return;
    setState(() {
      _loadedCollapsedVaultId = vaultId;
      _collapsedPageIds
        ..clear()
        ..addAll(restored);
    });
  }

  Future<void> _persistCollapsedState() async {
    await widget.appSettings.persistWorkspaceSidebarCollapsedPageIds(
      vaultId: session.activeVaultId,
      collapsedPageIds: _collapsedPageIds,
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

  ({List<_VisiblePageRow> rows, Map<String, bool> hasChildrenById})
  _buildVisiblePageRows(List<FolioPage> pages) {
    final byId = <String, FolioPage>{for (final p in pages) p.id: p};
    final childCounts = <String, int>{};
    for (final p in pages) {
      final pid = p.parentId;
      if (pid != null) {
        childCounts[pid] = (childCounts[pid] ?? 0) + 1;
      }
    }

    final hasChildrenById = <String, bool>{
      for (final p in pages) p.id: (childCounts[p.id] ?? 0) > 0,
    };

    final rows = <_VisiblePageRow>[];
    void walk(String? parentId, double indent) {
      final orderIds = session.pageOrderForParent(parentId);
      if (orderIds.isEmpty) return;
      for (final id in orderIds) {
        final p = byId[id];
        if (p == null) continue;
        rows.add(_VisiblePageRow(page: p, indent: indent));
        if (hasChildrenById[p.id] == true && !_isCollapsed(p.id)) {
          walk(p.id, indent + 14);
        }
      }
    }

    walk(null, 4);
    return (rows: rows, hasChildrenById: hasChildrenById);
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
    final emoji = await showFolioIconPicker(
      context: context,
      appSettings: widget.appSettings,
      title: l10n.sidebarPageIconTitle,
      helperText: l10n.sidebarPageIconPickerHelper,
      fallbackText: '📄',
      quickIcons: quickEmojis,
      customInputLabel: l10n.sidebarPageIconCustomEmoji,
      cancelLabel: l10n.cancel,
      saveLabel: l10n.save,
      removeLabel: l10n.sidebarPageIconRemove,
      quickTabLabel: l10n.sidebarPageIconTabQuick,
      importedTabLabel: l10n.sidebarPageIconTabImported,
      allEmojiTabLabel: l10n.sidebarPageIconTabAll,
      emptyImportedLabel: l10n.sidebarPageIconEmptyImported,
      initialToken: page.emoji,
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
    if (_vaultsLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.xs,
        ),
        child: Semantics(
          label: l10n.sidebarVaultsLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(FolioRadius.sm),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: scheme.surfaceContainerHighest.withValues(
                    alpha: FolioAlpha.track,
                  ),
                  color: scheme.primary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: FolioSpace.sm),
              Text(
                l10n.sidebarVaultsLoading,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_vaults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.xs,
        ),
        child: Semantics(
          label: l10n.sidebarVaultsEmpty,
          child: Container(
            padding: const EdgeInsets.all(FolioSpace.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_off_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: FolioSpace.sm),
                Expanded(
                  child: Text(
                    l10n.sidebarVaultsEmpty,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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

  Future<void> _openTemplateGallery(BuildContext context) async {
    final result = await openTemplateGalleryPage(
      context: context,
      session: session,
      cloud: widget.cloudAccountController,
    );
    if (result == null) return;
    if (result.template != null) {
      session.addPageFromTemplate(result.template!);
    } else {
      session.addPage(parentId: null);
    }
  }

  Future<void> _savePageAsTemplate(BuildContext context, FolioPage page) async {
    final l10n = AppLocalizations.of(context);
    String name = page.title.isNotEmpty ? page.title : l10n.untitledFallback;
    String description = '';
    String category = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FolioDialog(
          title: Text(l10n.saveAsTemplateTitle),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.templateNameHint),
                  controller: TextEditingController(text: name),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateDescriptionHint,
                  ),
                  onChanged: (v) => description = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateCategoryHint,
                  ),
                  onChanged: (v) => category = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result != true || !context.mounted) return;
    session.savePageAsTemplate(
      page.id,
      name: name.trim().isNotEmpty ? name.trim() : null,
      description: description.trim(),
      category: category.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.templateSaved)));
  }

  void _rename(BuildContext context, FolioPage page) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _RenamePageDialog(
        initialTitle: page.title,
        onSave: (newTitle) => session.renamePage(page.id, newTitle),
      ),
    );
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
    final showRowActions = _hoveredPageId == page.id;
    final hasChildren = _hasChildrenById[page.id] ?? false;
    final collapsed = _isCollapsed(page.id);
    final isFolder = page.isFolder;
    final canDelete = session.pages.length > 1 && (!hasChildren || isFolder);

    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 0, 0, FolioSpace.xs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredPageId = page.id),
        onExit: (_) {
          if (_hoveredPageId == page.id) {
            setState(() => _hoveredPageId = null);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected
                ? scheme.secondaryContainer
                : (_hoveredPageId == page.id
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : scheme.surface),
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            border: Border.all(
              color: selected
                  ? scheme.secondary.withValues(alpha: 0.2)
                  : scheme.outlineVariant.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: _hoveredPageId == page.id && !selected
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            onTap: () {
              if (isFolder) {
                _toggleCollapsed(page.id);
              } else {
                session.selectPage(page.id);
              }
            },
            onDoubleTap: () => _rename(context, page),
            child: Semantics(
              selected: selected,
              button: true,
              label: page.title,
              value: hasChildren
                  ? (collapsed ? 'Colapsado' : 'Expandido')
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioSpace.xs,
                  vertical: FolioSpace.xs,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Durante el resize del panel el ancho puede ser muy pequeño; la fila de
                    // acciones tiene ancho intrínseco alto y provoca overflow si no se omite.
                    final allowInlineActions =
                        showRowActions && constraints.maxWidth >= 200.0;
                    return Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (hasChildren)
                                InkWell(
                                  borderRadius: BorderRadius.circular(
                                    FolioRadius.sm,
                                  ),
                                  onTap: () => _toggleCollapsed(page.id),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      FolioSpace.xxs,
                                    ),
                                    child: AnimatedRotation(
                                      turns: collapsed ? 0 : 0.25,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 18),
                              const SizedBox(width: FolioSpace.xxs),
                              FolioIconTokenView(
                                appSettings: widget.appSettings,
                                token: page.emoji,
                                fallbackText: isFolder ? '📁' : '📄',
                                size: 18,
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
                        AnimatedSwitcher(
                          duration: FolioMotion.short2,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              ),
                          child: allowInlineActions
                              ? Container(
                                  key: ValueKey('page_actions_${page.id}'),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? scheme.onSecondaryContainer
                                              .withValues(
                                                alpha: FolioAlpha.faint,
                                              )
                                        : scheme.surfaceContainerHighest
                                              .withValues(
                                                alpha: FolioAlpha.panel,
                                              ),
                                    borderRadius: BorderRadius.circular(
                                      FolioRadius.md,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.emoji_emotions_outlined,
                                          size: 18,
                                        ),
                                        tooltip: l10n.sidebarPageIconTitle,
                                        visualDensity: VisualDensity.compact,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                        onPressed: () =>
                                            _setPageEmoji(context, page),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        tooltip: l10n.subpage,
                                        visualDensity: VisualDensity.compact,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                        onPressed: () {
                                          if (!page.isFolder) return;
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
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        tooltip: l10n.rename,
                                        visualDensity: VisualDensity.compact,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                        onPressed: () => _rename(context, page),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.bookmark_add_outlined,
                                          size: 18,
                                        ),
                                        tooltip: l10n.saveAsTemplate,
                                        visualDensity: VisualDensity.compact,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                        onPressed: () =>
                                            _savePageAsTemplate(context, page),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        tooltip: l10n.delete,
                                        visualDensity: VisualDensity.compact,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                        onPressed: canDelete
                                            ? () {
                                                if (page.isFolder &&
                                                    hasChildren) {
                                                  session
                                                      .deleteFolderMoveChildrenToRoot(
                                                        page.id,
                                                      );
                                                } else {
                                                  session.deletePage(page.id);
                                                }
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('page_actions_hidden'),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _draggablePageTile(
    BuildContext context,
    FolioPage page,
    double indent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    Widget buildDragChild() {
      return DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final draggedId = details.data;
          if (draggedId == page.id) return false;
          // Permitir anidar sobre cualquier página: si se suelta encima de otra
          // página, la movida se convierte en subpágina (newParentId = page.id).
          // Evitar ciclos: no permitir arrastrar un ancestro dentro de su descendiente.
          if (session.isUnderAncestor(ancestorId: draggedId, nodeId: page.id)) {
            return false;
          }
          return true;
        },
        onAcceptWithDetails: (details) {
          final draggedId = details.data;
          // Drop en el centro => anidar dentro de esta carpeta.
          final order = session.pageOrderForParent(page.id);
          session.movePage(
            pageId: draggedId,
            newParentId: page.id,
            newIndex: order.length,
          );
          if (_isCollapsed(page.id)) {
            _toggleCollapsed(page.id);
          }
        },
        builder: (context, candidates, rejected) {
          final hovering = candidates.isNotEmpty;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FolioRadius.lg),
              border: hovering
                  ? Border.all(
                      color: scheme.primary.withValues(alpha: 0.35),
                      width: 1.5,
                    )
                  : null,
            ),
            child: _tile(context, page, indent),
          );
        },
      );
    }

    final feedback = Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Opacity(opacity: 0.92, child: _tile(context, page, indent)),
      ),
    );

    if (isDesktop) {
      return Draggable<String>(
        data: page.id,
        feedback: feedback,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _tile(context, page, indent),
        ),
        child: buildDragChild(),
      );
    }

    return LongPressDraggable<String>(
      data: page.id,
      feedback: feedback,
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _tile(context, page, indent),
      ),
      child: buildDragChild(),
    );
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
                      avatar: FolioIconTokenView(
                        appSettings: widget.appSettings,
                        token: page.emoji,
                        fallbackText: '📄',
                        size: 16,
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
        widget.onSearch != null ||
        widget.onForceSync != null ||
        widget.onLock != null;
    final scheme = Theme.of(context).colorScheme;

    final visible = _buildVisiblePageRows(session.pages);
    _hasChildrenById = visible.hasChildrenById;

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
                  if (widget.onSearch != null)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: widget.onSearch,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(l10n.search),
                      ),
                    ),
                  if (widget.onSearch != null &&
                      (widget.onForceSync != null || widget.onLock != null))
                    const SizedBox(width: FolioSpace.xs),
                  if (widget.onForceSync != null)
                    IconButton(
                      tooltip: l10n.forceSyncTooltip,
                      icon: const Icon(Icons.sync_rounded),
                      onPressed: widget.onForceSync,
                    ),
                  if (widget.onLock != null)
                    IconButton(
                      tooltip: l10n.lockNow,
                      icon: const Icon(Icons.lock_outline_rounded),
                      onPressed: widget.onLock,
                    ),
                ],
              ),
            ),
          ),
        if (widget.onQuickAddTask != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.sm,
              0,
              FolioSpace.sm,
              FolioSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.tonalIcon(
                  onPressed: widget.onQuickAddTask,
                  icon: const Icon(Icons.add_task_rounded, size: 20),
                  label: Text(l10n.sidebarQuickAddTask),
                ),
              ],
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
              IconButton(
                icon: const Icon(Icons.layers_outlined, size: 20),
                tooltip: l10n.templateFromGallery,
                onPressed: () => _openTemplateGallery(context),
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: () => session.addPage(parentId: null),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.createPage),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                tooltip: 'Nueva carpeta',
                onPressed: () => session.addFolder(parentId: null),
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
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                final draggedId = details.data;
                // Root nunca crea ciclo.
                return draggedId.trim().isNotEmpty;
              },
              onAcceptWithDetails: (details) {
                final draggedId = details.data;
                final order = session.pageOrderForParent(null);
                session.movePage(
                  pageId: draggedId,
                  newParentId: null,
                  newIndex: order.length,
                );
              },
              builder: (context, candidates, rejected) {
                final hoveringRoot = candidates.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(FolioRadius.xl),
                    border: hoveringRoot
                        ? Border.all(
                            color: scheme.primary.withValues(alpha: 0.25),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Scrollbar(
                    controller: _pagesScrollController,
                    child: ListView.builder(
                      controller: _pagesScrollController,
                      padding: EdgeInsets.zero,
                      itemCount: visible.rows.length * 2 + 1,
                      itemBuilder: (context, index) {
                        // Índices impares: items. Pares: gaps (drop zones).
                        if (index.isOdd) {
                          final row = visible.rows[index ~/ 2];
                          return _draggablePageTile(
                            context,
                            row.page,
                            row.indent,
                          );
                        }

                        final gapIdx = index ~/ 2; // 0..rows.length
                        final beforeRow = gapIdx < visible.rows.length
                            ? visible.rows[gapIdx]
                            : null;
                        final parentId =
                            beforeRow?.page.parentId ??
                            (visible.rows.isNotEmpty
                                ? visible.rows.last.page.parentId
                                : null);
                        final beforeId = beforeRow?.page.id;

                        return DragTarget<String>(
                          onWillAcceptWithDetails: (details) {
                            final draggedId = details.data;
                            if (beforeId != null && draggedId == beforeId) {
                              return false;
                            }
                            // Evitar ciclos si cambia de padre y el padre destino está bajo el dragged.
                            if (parentId != null &&
                                session.isUnderAncestor(
                                  ancestorId: draggedId,
                                  nodeId: parentId,
                                )) {
                              return false;
                            }
                            return true;
                          },
                          onAcceptWithDetails: (details) {
                            final draggedId = details.data;
                            final order = session.pageOrderForParent(parentId);
                            // Insertar en la posición del gap dentro de este parent.
                            final idx = gapIdx.clamp(0, order.length);
                            session.movePage(
                              pageId: draggedId,
                              newParentId: parentId,
                              newIndex: idx,
                            );
                          },
                          builder: (context, candidates, rejected) {
                            final hovering = candidates.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              margin: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 6,
                              ),
                              height: hovering ? 10 : 6,
                              decoration: BoxDecoration(
                                color: hovering
                                    ? scheme.primary.withValues(alpha: 0.45)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.onOpenSettings != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.sm,
              0,
              FolioSpace.sm,
              FolioSpace.sm,
            ),
            child: FilledButton.tonalIcon(
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.settings_rounded),
              label: Text(l10n.settings),
            ),
          ),
      ],
    );
  }
}

class _VisiblePageRow {
  const _VisiblePageRow({required this.page, required this.indent});
  final FolioPage page;
  final double indent;
}

class _RenamePageDialog extends StatefulWidget {
  const _RenamePageDialog({
    required this.initialTitle,
    required this.onSave,
  });

  final String initialTitle;
  final ValueChanged<String> onSave;

  @override
  State<_RenamePageDialog> createState() => _RenamePageDialogState();
}

class _RenamePageDialogState extends State<_RenamePageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    widget.onSave(_controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.renamePageTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.titleLabel),
        onSubmitted: (_) => _saveAndClose(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _saveAndClose,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
