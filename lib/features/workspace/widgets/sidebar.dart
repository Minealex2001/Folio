import 'package:flutter/material.dart';

import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.session,
  });

  final VaultSession session;

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

  void _rename(BuildContext context, FolioPage page) {
    final titleController = TextEditingController(text: page.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar página'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: OutlineInputBorder(),
          ),
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

  Widget _tile(
    BuildContext context,
    FolioPage page,
    double indent,
  ) {
    final selected = page.id == session.selectedPageId;
    final canDelete = session.pages.length > 1 && !_hasChildren(page);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.85) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => session.selectPage(page.id),
          onDoubleTap: () => _rename(context, page),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      page.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
                  onPressed: canDelete ? () => session.deletePage(page.id) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLevel(BuildContext context, String? parentId, double indent) {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
          child: Row(
            children: [
              Text(
                'Páginas',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black54,
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
