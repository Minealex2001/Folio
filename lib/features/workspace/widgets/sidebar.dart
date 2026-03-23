import 'package:flutter/material.dart';

import '../../../data/vault_registry.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.session});

  final VaultSession session;

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
    if (vaultId == session.activeVaultId) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar de cofre'),
        content: const Text(
          'Se cerrará la sesión de este cofre y tendrás que desbloquear el otro con su contraseña, '
          'Hello o passkey (si los tienes configurados allí).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cambiar'),
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
        title: const Text('Renombrar cofre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
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
    final active = session.activeVaultId;
    final others = _vaults.where((e) => e.id != active).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay otros cofres que borrar.')),
      );
      return;
    }
    VaultEntry? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar otro cofre'),
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
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final target = picked!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar cofre?'),
        content: Text(
          'Se borrará por completo «${target.displayName}». No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
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
          ).showSnackBar(const SnackBar(content: Text('Cofre eliminado.')));
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
    final scheme = Theme.of(context).colorScheme;
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cofre',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: current.id,
                    items: _vaults
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              e.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) _confirmSwitchVault(id);
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Añadir cofre',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _addVault,
              ),
              PopupMenuButton<String>(
                tooltip: 'Más',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'rename') _renameActiveVault();
                  if (value == 'deleteOther') _deleteOtherVault();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Renombrar cofre activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (_vaults.length > 1)
                    const PopupMenuItem(
                      value: 'deleteOther',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Eliminar otro cofre…'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _rename(BuildContext context, FolioPage page) {
    final titleController = TextEditingController(text: page.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar página'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Título'),
          onSubmitted: (_) => Navigator.of(ctx).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              session.renamePage(page.id, titleController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) => titleController.dispose());
  }

  void _move(BuildContext context, FolioPage page) {
    final options = <MapEntry<String?, String>>[
      const MapEntry(null, 'Raíz'),
      ...session.pages
          .where(
            (p) =>
                p.id != page.id &&
                !session.isUnderAncestor(ancestorId: page.id, nodeId: p.id),
          )
          .map((p) => MapEntry(p.id, p.title)),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text('Mover «${page.title}»')),
              ...options.map(
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, FolioPage page, double indent) {
    final scheme = Theme.of(context).colorScheme;
    final selected = page.id == session.selectedPageId;
    final canDelete = session.pages.length > 1 && !_hasChildren(page);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Material(
        color: selected
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.85)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => session.selectPage(page.id),
          onDoubleTap: () => _rename(context, page),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      page.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Subpágina',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    session.addPage(parentId: page.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline, size: 20),
                  tooltip: 'Mover',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _move(context, page),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Renombrar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _rename(context, page),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Eliminar',
                  visualDensity: VisualDensity.compact,
                  onPressed: canDelete
                      ? () => session.deletePage(page.id)
                      : null,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _vaultToolbar(context),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
          child: Row(
            children: [
              Text(
                'Páginas',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => session.addPage(parentId: null),
                icon: const Icon(Icons.add),
                tooltip: 'Nueva página (raíz)',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: _buildLevel(context, null, 4),
          ),
        ),
      ],
    );
  }
}
