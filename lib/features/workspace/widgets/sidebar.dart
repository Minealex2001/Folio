import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
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
  VaultSession get session => widget.session;

  List<VaultEntry> _vaults = [];
  var _vaultsLoading = true;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
    _reloadVaults();
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    _reloadVaults();
  }

  Future<void> _reloadVaults() async {
    final list = await session.listVaultEntries();
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

  Future<void> _confirmSwitchVault(String vaultId) async {
    final l10n = AppLocalizations.of(context);
    if (vaultId == session.activeVaultId) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
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
      builder: (ctx) => AlertDialog(
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

  Future<void> _deleteOtherVault() async {
    final l10n = AppLocalizations.of(context);
    final active = session.activeVaultId;
    final others = _vaults.where((e) => e.id != active).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noOtherVaultsSnack)));
      return;
    }
    VaultEntry? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteOtherVaultTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: others
                .map(
                  (e) => ListTile(
                    title: Text(e.displayName),
                    subtitle: Text(
                      e.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      picked = e;
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
      ),
    );
    if (picked == null || !mounted) return;
    final target = picked!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteVaultConfirmTitle),
        content: Text(l10n.deleteVaultConfirmBody(target.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await session.deleteVaultById(target.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.vaultDeletedSnack)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
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
          } else if (value == 'deleteOther') {
            _deleteOtherVault();
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
          if (_vaults.length > 1)
            PopupMenuItem(
              value: 'deleteOther',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text(l10n.deleteOtherVault),
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
      builder: (ctx) => AlertDialog(
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
        return AlertDialog(
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
        );
      },
    );
  }

  Widget _tile(BuildContext context, FolioPage page, double indent) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = page.id == session.selectedPageId;
    final canDelete = session.pages.length > 1 && !_hasChildren(page);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 0, 0, FolioSpace.xs),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FolioSpace.sm,
                      vertical: FolioSpace.xs,
                    ),
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
                ),
                Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.onSecondaryContainer.withValues(alpha: 0.08)
                        : scheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                    borderRadius: BorderRadius.circular(FolioRadius.md),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
              ],
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
      if (_hasChildren(p)) {
        tiles.addAll(_buildLevel(context, p.id, indent + 14));
      }
    }
    return tiles;
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
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Scrollbar(
              child: ListView(
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
