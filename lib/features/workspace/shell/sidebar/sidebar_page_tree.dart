import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../../../app/app_settings.dart';
import '../../../../app/ui_tokens.dart';
import '../../../../app/widgets/folio_dialog.dart';
import '../../../../app/widgets/folio_icon_token_view.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/folio_page.dart';

class SidebarVisiblePageRow {
  const SidebarVisiblePageRow({required this.page, required this.indent});
  final FolioPage page;
  final double indent;
}

bool sidebarHasCollapsedAncestor(
  FolioPage page,
  Map<String, FolioPage> byId,
  bool Function(String pageId) isCollapsed,
) {
  var current = page.parentId;
  final seen = <String>{};
  while (current != null && current.trim().isNotEmpty) {
    final id = current.trim();
    if (!seen.add(id)) break;
    if (isCollapsed(id)) return true;
    current = byId[id]?.parentId;
  }
  return false;
}

({List<SidebarVisiblePageRow> rows, Map<String, bool> hasChildrenById})
buildSidebarVisiblePageRows(
  List<FolioPage> pages, {
  required List<String> Function(String? parentId) pageOrderForParent,
  required bool Function(String pageId) isCollapsed,
  String? tagFilter,
}) {
  // Filtro por tag: lista plana de coincidencias (sin jerarquía).
  if (tagFilter != null && tagFilter.isNotEmpty) {
    final matched = pages.where((p) => p.tags.contains(tagFilter)).toList();
    final rows = matched
        .map((p) => SidebarVisiblePageRow(page: p, indent: 4))
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

  final rows = <SidebarVisiblePageRow>[];
  // Camino actual + ya emitidos: evita ciclos parent/orden (p. ej. tras sync).
  final walking = <String>{};
  final emitted = <String>{};
  const maxDepth = 64;

  void walk(String? parentId, double indent, int depth) {
    if (depth > maxDepth) return;
    final orderIds = pageOrderForParent(parentId);
    if (orderIds.isEmpty) return;
    for (final rawId in orderIds) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      if (walking.contains(id) || emitted.contains(id)) continue;
      final p = byId[id];
      if (p == null) continue;
      // Ignorar entradas de orden inconsistentes con parentId (aristas fantasma).
      final expectedParent = parentId;
      final actualParent = p.parentId;
      if (expectedParent == null) {
        if (actualParent != null && actualParent.trim().isNotEmpty) continue;
      } else if (actualParent != expectedParent) {
        continue;
      }
      emitted.add(id);
      rows.add(SidebarVisiblePageRow(page: p, indent: indent));
      if (hasChildrenById[p.id] == true && !isCollapsed(p.id)) {
        walking.add(p.id);
        walk(p.id, indent + 14, depth + 1);
        walking.remove(p.id);
      }
    }
  }

  walk(null, 4, 0);
  // Huérfanos / orden inconsistente: no volcar hijos de carpetas colapsadas.
  for (final p in pages) {
    if (emitted.contains(p.id)) continue;
    if (sidebarHasCollapsedAncestor(p, byId, isCollapsed)) continue;
    emitted.add(p.id);
    rows.add(SidebarVisiblePageRow(page: p, indent: 4));
  }
  return (rows: rows, hasChildrenById: hasChildrenById);
}

// ---------------------------------------------------------------------------
// Per-tile widget that owns its own hover state.
// Moving hover tracking here means mouse movements only rebuild the individual
// tile, NOT the entire sidebar (which was the main source of mouse-lag).
// ---------------------------------------------------------------------------

class SidebarTile extends StatefulWidget {
  const SidebarTile({
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
  final VoidCallback? onDeleteRequest;

  @override
  State<SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<SidebarTile> {
  bool _hovered = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final page = widget.page;
    final selected = widget.selected;
    final hasChildren = widget.hasChildren;
    final collapsed = widget.collapsed;
    final isFolder = page.isFolder;
    // En táctil/web no hay hover fiable: las acciones (⋯) deben quedar visibles.
    // En escritorio nativo se revelan al pasar el ratón.
    final isDesktopPointer =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final showRowActions = _hovered || !isDesktopPointer;

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
          // Material local + sin splash: al seleccionar, el tile se reconstruye
          // y un InkWell colgado del Material del Scaffold deja el ink huérfano
          // (assertion `referenceBox.attached` en paint).
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            child: InkWell(
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              borderRadius: BorderRadius.circular(FolioRadius.lg),
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
                    ? (collapsed
                          ? l10n.sidebarItemCollapsedSemantics
                          : l10n.sidebarItemExpandedSemantics)
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
                          (showRowActions || _menuOpen) &&
                          constraints.maxWidth >= FolioSidebar.tileActionsMinWidth;
                      return Row(
                        children: [
                          // Selection bar indicator
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: selected ? 3 : 0,
                            height: selected ? 16 : 0,
                            margin: EdgeInsets.only(right: selected ? 6 : 0),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                if (hasChildren)
                                  Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      FolioRadius.sm,
                                    ),
                                    child: InkWell(
                                      splashFactory: NoSplash.splashFactory,
                                      overlayColor:
                                          const WidgetStatePropertyAll(
                                            Colors.transparent,
                                          ),
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
                        if (constraints.maxWidth >= FolioSidebar.tileActionsMinWidth)
                          SizedBox(
                            width: FolioSidebar.tileActionsSlotWidth,
                            child: IgnorePointer(
                              ignoring: !allowInlineActions,
                              child: AnimatedOpacity(
                                opacity: allowInlineActions ? 1 : 0,
                                duration: FolioMotion.short2,
                                child: Container(
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
                                      if (isFolder && widget.onAddSubpage != null)
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 18),
                                          tooltip: l10n.subpage,
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 36,
                                            minHeight: 36,
                                          ),
                                          style: IconButton.styleFrom(
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          color: selected
                                              ? scheme.onSecondaryContainer
                                              : scheme.onSurfaceVariant,
                                          onPressed: widget.onAddSubpage,
                                        ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_horiz_rounded,
                                          size: 18,
                                        ),
                                        tooltip: l10n.workspaceMoreActionsTooltip,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(FolioRadius.md),
                                        ),
                                        color: scheme.surfaceContainerHighest,
                                        iconColor: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant,
                                        onOpened: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) setState(() => _menuOpen = true);
                                        }),
                                        onCanceled: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) setState(() => _menuOpen = false);
                                        }),
                                        onSelected: (value) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            setState(() => _menuOpen = false);
                                            switch (value) {
                                              case 'emoji':
                                                widget.onSetEmoji();
                                                break;
                                              case 'move':
                                                widget.onMove();
                                                break;
                                              case 'rename':
                                                widget.onRename();
                                                break;
                                              case 'template':
                                                widget.onSaveAsTemplate();
                                                break;
                                              case 'delete':
                                                widget.onDeleteRequest?.call();
                                                break;
                                            }
                                          });
                                        },
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem(
                                            value: 'emoji',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.emoji_emotions_outlined, size: 18),
                                                const SizedBox(width: 8),
                                                Text(l10n.sidebarPageIconTitle),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'move',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.drive_file_move_outline, size: 18),
                                                const SizedBox(width: 8),
                                                Text(l10n.move),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'rename',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit_outlined, size: 18),
                                                const SizedBox(width: 8),
                                                Text(l10n.rename),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'template',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.bookmark_add_outlined, size: 18),
                                                const SizedBox(width: 8),
                                                Text(l10n.saveAsTemplate),
                                              ],
                                            ),
                                          ),
                                          if (widget.onDeleteRequest != null) ...[
                                            const PopupMenuDivider(),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 18, color: scheme.error),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    l10n.delete,
                                                    style: TextStyle(color: scheme.error),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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
                  },
                ),
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

class SidebarTagFilterBar extends StatelessWidget {
  const SidebarTagFilterBar({
    super.key,
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(FolioRadius.md),
          border: Border.all(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.2)
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check_rounded,
                size: 12,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SidebarRenamePageDialog extends StatefulWidget {
  const SidebarRenamePageDialog({
    super.key,
    required this.initialTitle,
    required this.onSave,
  });

  final String initialTitle;
  final ValueChanged<String> onSave;

  @override
  State<SidebarRenamePageDialog> createState() =>
      _SidebarRenamePageDialogState();
}

class _SidebarRenamePageDialogState extends State<SidebarRenamePageDialog> {
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
