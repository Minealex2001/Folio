import 'package:flutter/material.dart';

import '../../../models/folio_page.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.pages,
    required this.selectedPageId,
    required this.onPageSelected,
    required this.onAddPage,
    required this.onDeletePage,
    required this.onRenamePage,
    this.canDelete = true,
  });

  final List<FolioPage> pages;
  final String selectedPageId;
  final ValueChanged<String> onPageSelected;
  final VoidCallback onAddPage;
  final ValueChanged<String> onDeletePage;
  final void Function(BuildContext context, FolioPage page) onRenamePage;
  final bool canDelete;

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
                onPressed: onAddPage,
                icon: const Icon(Icons.add),
                tooltip: 'Nueva página',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: pages.length,
            itemBuilder: (context, index) {
              final page = pages[index];
              final selected = page.id == selectedPageId;
              return GestureDetector(
                onDoubleTap: () => onRenamePage(context, page),
                child: ListTile(
                  title: Text(
                    page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: selected,
                  selectedTileColor: Colors.white.withValues(alpha: 0.75),
                  onTap: () => onPageSelected(page.id),
                  trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Renombrar',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRenamePage(context, page),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Eliminar',
                      visualDensity: VisualDensity.compact,
                      onPressed: canDelete ? () => onDeletePage(page.id) : null,
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
