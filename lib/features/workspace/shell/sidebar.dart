import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, setEquals;
import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_feedback.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_icon_picker.dart';
import '../../../data/vault_registry.dart';
import '../../../services/app_logger.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../../../app/widgets/folio_interactions.dart';
import '../recent_page_visits.dart';
import '../templates/template_gallery_page.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';
import 'sidebar/sidebar_footer.dart';
import 'sidebar/sidebar_page_tree.dart';
import 'sidebar/sidebar_recents.dart';
import 'sidebar/sidebar_vault_toolbar.dart';
import '../collab/vault_share_sheet.dart';

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
    this.onOpenVaultTaskHub,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final CloudAccountController cloudAccountController;
  final VoidCallback? onSearch;
  final VoidCallback? onForceSync;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLock;
  final VoidCallback? onQuickAddTask;
  final VoidCallback? onOpenVaultTaskHub;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  VaultSession get session => widget.session;

  List<VaultEntry> _vaults = [];
  var _vaultsLoading = true;
  Set<String> _lastVaultIds = const <String>{};
  final Set<String> _collapsedPageIds = <String>{};
  // Performance: track what's visible in the sidebar to skip unnecessary rebuilds
  String _lastSidebarFingerprint = '';
  Set<String> _lastPageIds = const {};
  final ScrollController _pagesScrollController = ScrollController();
  String? _loadedCollapsedVaultId;
  final List<RecentPageVisit> _recentVisits = <RecentPageVisit>[];
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

    // El registro de libretas puede cambiar (borrar/añadir otra libreta desde
    // Ajustes) sin que cambie ni una sola página de la libreta activa, así que
    // el gate de fingerprint de más abajo (pensado solo para el contenido
    // visible de páginas) no lo detectaría nunca. Se comprueba aparte y antes
    // de ese gate para que el selector de libretas del sidebar no se quede
    // mostrando libretas ya borradas.
    final currentVaultIds = {
      for (final e in VaultRegistry.instance.vaults) e.id,
    };
    if (!setEquals(currentVaultIds, _lastVaultIds)) {
      unawaited(_reloadVaults());
    }

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
    buf.write(session.spotifyConnections.map((c) => c.id).join(','));
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
      buf.write(p.trashedAt?.millisecondsSinceEpoch ?? '');
      buf.write(':');
      buf.write(p.tags.join(','));
      buf.write('|');
    }
    return buf.toString();
  }

  Future<void> _loadCollapsedState() async {
    final vaultId = session.activeVaultId;
    final validPageIds = session.activePages.map((p) => p.id).toSet();
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
    final validPageIds = session.activePages.map((p) => p.id).toSet();
    final restored = await RecentPageVisitsStore.load(
      vaultId: vaultId,
      validPageIds: validPageIds,
      limit: kRecentPageVisitsStorageLimit,
    );
    if (!mounted) return;
    setState(() {
      _loadedRecentVaultId = vaultId;
      _recentVisits
        ..clear()
        ..addAll(restored);
    });
  }

  Future<void> _persistRecentState() async {
    await RecentPageVisitsStore.save(
      vaultId: session.activeVaultId,
      visits: _recentVisits,
      limit: kRecentPageVisitsStorageLimit,
    );
  }

  void _registerRecentPage(String pageId) {
    if (!session.activePages.any((p) => p.id == pageId)) return;
    setState(() {
      final next = RecentPageVisitsStore.withNewVisit(
        _recentVisits,
        pageId,
        limit: kRecentPageVisitsStorageLimit,
      );
      _recentVisits
        ..clear()
        ..addAll(next);
    });
    unawaited(_persistRecentState());
  }

  Future<void> _reloadVaults() async {
    final list = await session.listVaultEntries();
    final validPageIds = session.activePages.map((p) => p.id).toSet();
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
    _recentVisits.removeWhere((v) {
      final remove = !validPageIds.contains(v.pageId);
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
        _lastVaultIds = {for (final e in list) e.id};
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

  void _toggleExpandCollapseAll() {
    final pagesWithChildren = session.activePages.where((p) {
      final childCounts = <String, int>{};
      for (final pg in session.activePages) {
        final pid = pg.parentId;
        if (pid != null) {
          childCounts[pid] = (childCounts[pid] ?? 0) + 1;
        }
      }
      return (childCounts[p.id] ?? 0) > 0 || p.isFolder;
    }).map((p) => p.id).toSet();

    setState(() {
      final allCollapsed = pagesWithChildren.every((id) => _collapsedPageIds.contains(id));
      if (allCollapsed) {
        _collapsedPageIds.clear();
      } else {
        _collapsedPageIds.addAll(pagesWithChildren);
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
      builder: (ctx) => SidebarRenamePageDialog(
        initialTitle: page.title,
        onSave: (newTitle) => session.renamePage(page.id, newTitle),
      ),
    );
  }

  void _move(BuildContext context, FolioPage page) {
    final l10n = AppLocalizations.of(context);
    final options = <MapEntry<String?, String>>[
      MapEntry(null, l10n.rootPage),
      ...session.activePages
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
          contentWidth: 420,
          content: SizedBox(
            height: math.min(480, math.max(160, options.length * 56 + 24)),
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, i) {
                final e = options[i];
                return ListTile(
                  title: Text(e.value),
                  trailing: page.parentId == e.key
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () {
                    session.setPageParent(page.id, e.key);
                    Navigator.pop(ctx);
                  },
                );
              },
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
    FolioPage page,
  ) async {
    try {
      final hasChildren = _hasChildrenById[page.id] ?? false;
      final isFolderWithChildren = page.isFolder && hasChildren;
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final label = _sidebarDeleteLabel(page, l10n);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => FolioDialog(
          title: Text(
            isFolderWithChildren
                ? l10n.sidebarDeleteFolderMenuTitle
                : l10n.sidebarDeletePageMenuTitle,
          ),
          content: Text(
            isFolderWithChildren
                ? l10n.sidebarDeleteFolderConfirmInline(label)
                : l10n.sidebarDeletePageConfirmInline(label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.sidebarDeletePageMenuTitle),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
      session.movePageToTrash(page.id);
    } catch (e, stack) {
      AppLogger.error(
        'Delete page confirm menu failed',
        tag: 'vault',
        error: e,
        stackTrace: stack,
      );
    }
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

    final selected = page.id == session.selectedPageId;
    final hasChildren = _hasChildrenById[page.id] ?? false;
    final collapsed = _isCollapsed(page.id);
    final canDelete = session.canMovePageToTrash(page.id);

    // Builds a tile widget. interactive=false for drag feedback / ghost copies.
    SidebarTile buildTile({bool interactive = true}) {
      return SidebarTile(
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
            ? () => unawaited(_showDeletePageConfirmMenu(page))
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showDeskTools =
        widget.onSearch != null ||
        widget.onForceSync != null ||
        widget.onLock != null;
    final scheme = Theme.of(context).colorScheme;

    final visible = buildSidebarVisiblePageRows(
      session.activePages,
      pageOrderForParent: session.pageOrderForParent,
      isCollapsed: _isCollapsed,
      tagFilter: _selectedTagFilter,
    );
    _hasChildrenById = visible.hasChildrenById;

    final pagesWithChildren = session.activePages.where((p) {
      final childCounts = <String, int>{};
      for (final pg in session.activePages) {
        final pid = pg.parentId;
        if (pid != null) {
          childCounts[pid] = (childCounts[pid] ?? 0) + 1;
        }
      }
      return (childCounts[p.id] ?? 0) > 0 || p.isFolder;
    }).map((p) => p.id).toSet();
    final allCollapsed = pagesWithChildren.every((id) => _collapsedPageIds.contains(id));
    final trashCount = session.trashedPages.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // When the sidebar is animating to/from zero width, the available
        // width can be tiny (a few pixels). Rendering the full Column in
        // that state causes a RenderFlex overflow because Wrap stacks all
        // chips vertically. Return an empty box to avoid the assertion.
        if (constraints.maxWidth < FolioSidebar.collapseThreshold) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SidebarVaultToolbar(
              vaults: _vaults,
              loading: _vaultsLoading,
              activeVaultId: session.activeVaultId,
              onSwitchVault: (vaultId) => unawaited(_confirmSwitchVault(vaultId)),
              onAddVault: () => unawaited(_addVault()),
              onRenameVault: () => unawaited(_renameActiveVault()),
              onShareVault: () => unawaited(
                showVaultShareSheet(
                  context: context,
                  session: session,
                ),
              ),
            ),
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
                          child: Material(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(FolioRadius.md),
                            child: InkWell(
                              onTap: widget.onSearch,
                              borderRadius: BorderRadius.circular(FolioRadius.md),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(FolioRadius.md),
                                  border: Border.all(
                                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: FolioSpace.sm,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: FolioSpace.xs),
                                    Expanded(
                                      child: Text(
                                        l10n.search,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
            if (widget.onQuickAddTask != null || widget.onOpenVaultTaskHub != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.sm,
                  0,
                  FolioSpace.sm,
                  FolioSpace.sm,
                ),
                child: Row(
                  children: [
                    if (widget.onQuickAddTask != null)
                      IconButton(
                        tooltip: l10n.sidebarQuickAddTask,
                        icon: const Icon(Icons.add_task_rounded),
                        onPressed: widget.onQuickAddTask,
                      ),
                    if (widget.onOpenVaultTaskHub != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenVaultTaskHub,
                          icon: const Icon(Icons.task_alt_outlined, size: 20),
                          label: Text(l10n.sidebarTaskHub),
                        ),
                      ),
                  ],
                ),
              ),
            SidebarRecentsSection(
              appSettings: widget.appSettings,
              session: session,
              recentVisits: _recentVisits,
              onSelectPage: session.selectPage,
              onToggleCollapsed: () {
                final next = !widget.appSettings.workspaceSidebarRecentPagesCollapsed;
                widget.appSettings.setWorkspaceSidebarRecentPagesCollapsed(next);
                setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.md,
                FolioSpace.sm,
                FolioSpace.sm,
                FolioSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.pages,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      allCollapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                      size: 20,
                    ),
                    tooltip: allCollapsed ? l10n.aiExpand : l10n.aiCollapse,
                    onPressed: _toggleExpandCollapseAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.layers_outlined, size: 20),
                    tooltip: l10n.templateFromGallery,
                    onPressed: () => _openTemplateGallery(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.note_add_outlined, size: 20),
                    tooltip: l10n.createPage,
                    onPressed: () => session.addPage(parentId: null),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 20,
                    ),
                    tooltip: l10n.driveNewFolder,
                    onPressed: () => session.addFolder(parentId: null),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    tooltip: l10n.settings,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FolioRadius.md),
                    ),
                    color: scheme.surfaceContainerHighest,
                    onSelected: (value) {
                      if (value == 'show_recents') {
                        final next = !widget.appSettings.workspaceSidebarShowRecentPages;
                        widget.appSettings.setWorkspaceSidebarShowRecentPages(next);
                        setState(() {});
                      }
                    },
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: 'show_recents',
                        checked: widget.appSettings.workspaceSidebarShowRecentPages,
                        child: Text(AppLocalizations.of(context).workspaceRecentPagesSectionTitle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SidebarTagFilterBar(
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
                          ? FadingEmptyState(
                              child: Center(
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
            SidebarFooter(
              session: session,
              appSettings: widget.appSettings,
              trashCount: trashCount,
              onOpenSettings: widget.onOpenSettings,
              onSpotifyExpandedChanged: () => setState(() {}),
            ),
          ],
        );
      },
    );
  }
}
