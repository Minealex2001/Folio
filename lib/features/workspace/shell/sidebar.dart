import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, setEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_feedback.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_icon_picker.dart';
import '../../../app/widgets/folio_icon_token_view.dart';
import '../../../data/vault_registry.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../editor/block_editor_support_widgets.dart';
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
  final Set<String> _collapsedPageIds = <String>{};
  // Performance: track what's visible in the sidebar to skip unnecessary rebuilds
  String _lastSidebarFingerprint = '';
  Set<String> _lastPageIds = const {};
  final ScrollController _pagesScrollController = ScrollController();
  String? _loadedCollapsedVaultId;
  final List<String> _recentPageIds = <String>[];
  String? _loadedRecentVaultId;
  String? _lastSelectedPageId;
  Map<String, bool> _hasChildrenById = const <String, bool>{};
  String? _selectedTagFilter;

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

    // Skip rebuild entirely when nothing sidebar-visible changed (e.g. only
    // block content was edited — the main source of per-keystroke lag).
    final fp = _sidebarFingerprint();
    if (fp == _lastSidebarFingerprint) return;
    _lastSidebarFingerprint = fp;

    // Only run the async vault-list reload when the page set changes.
    // For title / emoji / selection changes a lightweight setState is enough.
    final currentPageIds = {for (final p in session.pages) p.id};
    if (!setEquals(currentPageIds, _lastPageIds)) {
      _lastPageIds = currentPageIds;
      unawaited(_reloadVaults());
    } else if (mounted) {
      setState(() {});
    }
  }

  /// Produces a string that changes whenever anything visible in the sidebar
  /// changes. Block-content edits do NOT appear here, so they are ignored.
  String _sidebarFingerprint() {
    final buf = StringBuffer();
    buf.write(session.selectedPageId ?? '');
    buf.write('|');
    for (final p in session.pages) {
      buf.write(p.id);
      buf.write(':');
      buf.write(p.title);
      buf.write(':');
      buf.write(p.emoji ?? '');
      buf.write(':');
      buf.write(p.parentId ?? '');
      buf.write(':');
      buf.write(p.tags.join(','));
      buf.write('|');
    }
    return buf.toString();
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
  _buildVisiblePageRows(List<FolioPage> pages, {String? tagFilter}) {
    // When a tag filter is active, show a flat list of matching pages.
    if (tagFilter != null) {
      final matched = pages.where((p) => p.tags.contains(tagFilter)).toList();
      final rows = matched
          .map((p) => _VisiblePageRow(page: p, indent: 4))
          .toList();
      final hasChildrenById = <String, bool>{
        for (final p in matched) p.id: false,
      };
      return (rows: rows, hasChildrenById: hasChildrenById);
    }

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

  String _sidebarDeleteLabel(FolioPage page, AppLocalizations l10n) {
    final t = page.title.trim();
    return t.isEmpty ? l10n.untitledFallback : t;
  }

  /// Mismo patrón que exportar página: [showMenu] anclado + [BlockEditorFloatingPanel].
  Future<void> _showDeletePageConfirmMenu(
    BuildContext anchorContext,
    FolioPage page,
  ) async {
    final hasChildren = _hasChildrenById[page.id] ?? false;
    final isFolderWithChildren = page.isFolder && hasChildren;
    final l10n = AppLocalizations.of(anchorContext);
    final theme = Theme.of(anchorContext);
    final scheme = theme.colorScheme;
    final label = _sidebarDeleteLabel(page, l10n);

    final buttonBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return;

    final buttonRect =
        buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
        buttonBox.size;
    final position = RelativeRect.fromRect(
      buttonRect,
      Offset.zero & overlayBox.size,
    );

    final maxW = math.min(420.0, overlayBox.size.width - 24.0);
    final menuW = maxW.clamp(280.0, 420.0);
    final maxH = math.min(320.0, overlayBox.size.height - 24.0);

    final confirmed = await showMenu<bool>(
      context: anchorContext,
      position: position,
      useRootNavigator: true,
      constraints: BoxConstraints.tightFor(width: menuW),
      items: [
        PopupMenuItem<bool>(
          enabled: false,
          height: 240,
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: BlockEditorFloatingPanel(
              scheme: scheme,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                      child: Text(
                        isFolderWithChildren
                            ? l10n.sidebarDeleteFolderMenuTitle
                            : l10n.sidebarDeletePageMenuTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Text(
                        isFolderWithChildren
                            ? l10n.sidebarDeleteFolderConfirmInline(label)
                            : l10n.sidebarDeletePageConfirmInline(label),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Builder(
                          builder: (menuCtx) {
                            return TextButton(
                              onPressed: () {
                                Navigator.of(
                                  menuCtx,
                                  rootNavigator: true,
                                ).pop(false);
                              },
                              child: Text(l10n.cancel),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (menuCtx) {
                            return FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.error,
                                foregroundColor: scheme.onError,
                              ),
                              onPressed: () {
                                Navigator.of(
                                  menuCtx,
                                  rootNavigator: true,
                                ).pop(true);
                              },
                              child: Text(l10n.delete),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    if (isFolderWithChildren) {
      session.deleteFolderMoveChildrenToRoot(page.id);
    } else {
      session.deletePage(page.id);
    }
  }

  // _tile() removed — replaced by _SidebarTile StatefulWidget below the class.

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

    final selected = page.id == session.selectedPageId;
    final hasChildren = _hasChildrenById[page.id] ?? false;
    final collapsed = _isCollapsed(page.id);
    final canDelete =
        session.pages.length > 1 && (!hasChildren || page.isFolder);

    // Builds a tile widget. interactive=false for drag feedback / ghost copies.
    _SidebarTile buildTile({bool interactive = true}) {
      return _SidebarTile(
        key: interactive ? ValueKey('tile_${page.id}') : null,
        page: page,
        indent: indent,
        selected: selected,
        hasChildren: hasChildren,
        collapsed: collapsed,
        canDelete: canDelete,
        appSettings: widget.appSettings,
        onTap: () => session.selectPage(page.id),
        onDoubleTap: () => _rename(context, page),
        onToggleCollapsed: () => _toggleCollapsed(page.id),
        onSetEmoji: () => _setPageEmoji(context, page),
        onAddSubpage: page.isFolder
            ? () => session.addPage(parentId: page.id)
            : null,
        onMove: () => _move(context, page),
        onRename: () => _rename(context, page),
        onSaveAsTemplate: () => _savePageAsTemplate(context, page),
        onDeleteRequest: interactive && canDelete
            ? (btnCtx) => unawaited(_showDeletePageConfirmMenu(btnCtx, page))
            : null,
      );
    }

    Widget buildDragChild() {
      return DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final draggedId = details.data;
          if (draggedId == page.id) return false;
          // Evitar ciclos: no permitir arrastrar un ancestro dentro de su descendiente.
          if (session.isUnderAncestor(ancestorId: draggedId, nodeId: page.id)) {
            return false;
          }
          return true;
        },
        onAcceptWithDetails: (details) {
          final draggedId = details.data;
          // Drop en el centro => anidar dentro de esta página.
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
            child: buildTile(),
          );
        },
      );
    }

    final feedback = Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Opacity(opacity: 0.92, child: buildTile(interactive: false)),
      ),
    );

    if (isDesktop) {
      return Draggable<String>(
        data: page.id,
        feedback: feedback,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: buildTile(interactive: false),
        ),
        child: buildDragChild(),
      );
    }

    return LongPressDraggable<String>(
      data: page.id,
      feedback: feedback,
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: buildTile(interactive: false),
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

    final visible = _buildVisiblePageRows(
      session.pages,
      tagFilter: _selectedTagFilter,
    );
    _hasChildrenById = visible.hasChildrenById;

    return LayoutBuilder(
      builder: (context, constraints) {
        // When the sidebar is animating to/from zero width, the available
        // width can be tiny (a few pixels). Rendering the full Column in
        // that state causes a RenderFlex overflow because Wrap stacks all
        // chips vertically. Return an empty box to avoid the assertion.
        if (constraints.maxWidth < 32) return const SizedBox.shrink();
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
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 20,
                    ),
                    tooltip: 'Nueva carpeta',
                    onPressed: () => session.addFolder(parentId: null),
                  ),
                ],
              ),
            ),
            _TagFilterBar(
              tags: session.allTags,
              selected: _selectedTagFilter,
              onSelect: (tag) => setState(() {
                _selectedTagFilter = _selectedTagFilter == tag ? null : tag;
              }),
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
                      child: visible.rows.isEmpty && _selectedTagFilter != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(FolioSpace.md),
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).tagNoPagesForFilter,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Scrollbar(
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
                                      if (beforeId != null &&
                                          draggedId == beforeId) {
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
                                      final order = session.pageOrderForParent(
                                        parentId,
                                      );
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
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 2,
                                          horizontal: 6,
                                        ),
                                        height: hovering ? 10 : 6,
                                        decoration: BoxDecoration(
                                          color: hovering
                                              ? scheme.primary.withValues(
                                                  alpha: 0.45,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
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
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.sm,
                  0,
                  FolioSpace.sm,
                  FolioSpace.xs,
                ),
                child: FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://minealexgames.com/folio'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l10n.downloadDesktopApp),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
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
      },
    );
  }
}

class _VisiblePageRow {
  const _VisiblePageRow({required this.page, required this.indent});
  final FolioPage page;
  final double indent;
}

// ---------------------------------------------------------------------------
// Per-tile widget that owns its own hover state.
// Moving hover tracking here means mouse movements only rebuild the individual
// tile, NOT the entire sidebar (which was the main source of mouse-lag).
// ---------------------------------------------------------------------------

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    super.key,
    required this.page,
    required this.indent,
    required this.selected,
    required this.hasChildren,
    required this.collapsed,
    required this.canDelete,
    required this.appSettings,
    required this.onTap,
    required this.onDoubleTap,
    required this.onToggleCollapsed,
    required this.onSetEmoji,
    required this.onAddSubpage,
    required this.onMove,
    required this.onRename,
    required this.onSaveAsTemplate,
    required this.onDeleteRequest,
  });

  final FolioPage page;
  final double indent;
  final bool selected;
  final bool hasChildren;
  final bool collapsed;
  final bool canDelete;
  final AppSettings appSettings;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onSetEmoji;
  final VoidCallback? onAddSubpage;
  final VoidCallback onMove;
  final VoidCallback onRename;
  final VoidCallback onSaveAsTemplate;
  final void Function(BuildContext btnCtx)? onDeleteRequest;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final page = widget.page;
    final selected = widget.selected;
    final hasChildren = widget.hasChildren;
    final collapsed = widget.collapsed;
    final isFolder = page.isFolder;
    final showRowActions = _hovered;

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.indent, 0, 0, FolioSpace.xs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected
                ? scheme.secondaryContainer
                : (_hovered
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : scheme.surface),
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            border: Border.all(
              color: selected
                  ? scheme.secondary.withValues(alpha: 0.2)
                  : scheme.outlineVariant.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: _hovered && !selected
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
                widget.onToggleCollapsed();
              } else {
                widget.onTap();
              }
            },
            onDoubleTap: widget.onDoubleTap,
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
                                  onTap: widget.onToggleCollapsed,
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
                                        onPressed: widget.onSetEmoji,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        tooltip: l10n.subpage,
                                        visualDensity: VisualDensity.compact,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                        onPressed: widget.onAddSubpage,
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
                                        onPressed: widget.onMove,
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
                                        onPressed: widget.onRename,
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
                                        onPressed: widget.onSaveAsTemplate,
                                      ),
                                      Builder(
                                        builder: (btnCtx) {
                                          return IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                            ),
                                            tooltip: l10n.delete,
                                            visualDensity:
                                                VisualDensity.compact,
                                            color: selected
                                                ? scheme.onSecondaryContainer
                                                : scheme.onSurfaceVariant,
                                            onPressed:
                                                widget.onDeleteRequest != null
                                                ? () => widget.onDeleteRequest!(
                                                    btnCtx,
                                                  )
                                                : null,
                                          );
                                        },
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
}

// ---------------------------------------------------------------------------
// Tag filter bar shown below the "Pages" header in the sidebar.
// ---------------------------------------------------------------------------

class _TagFilterBar extends StatelessWidget {
  const _TagFilterBar({
    required this.tags,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tags;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(FolioSpace.sm, 0, FolioSpace.sm, 6),
        children: [
          _filterChip(
            context: context,
            label: l10n.tagFilterAll,
            isSelected: selected == null,
            scheme: scheme,
            textTheme: textTheme,
            onTap: () {
              if (selected != null) onSelect(selected!); // toggle off
            },
          ),
          for (final tag in tags) ...[
            const SizedBox(width: 6),
            _filterChip(
              context: context,
              label: tag,
              isSelected: selected == tag,
              scheme: scheme,
              textTheme: textTheme,
              onTap: () => onSelect(tag),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
        ),
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: isSelected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _RenamePageDialog extends StatefulWidget {
  const _RenamePageDialog({required this.initialTitle, required this.onSave});

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
        TextButton(onPressed: _saveAndClose, child: Text(l10n.save)),
      ],
    );
  }
}
