import 'package:flutter/material.dart';

<<<<<<< HEAD
=======
import '../../../l10n/generated/app_localizations.dart';
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
import '../../../services/admin/admin_catalog_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminCatalogSection extends StatefulWidget {
  const AdminCatalogSection({super.key, required this.canEdit});

  final bool canEdit;

  @override
  State<AdminCatalogSection> createState() => _AdminCatalogSectionState();
}

class _AdminCatalogSectionState extends State<AdminCatalogSection> {
  final _api = const AdminCatalogApi();
  AdminPaginatedListController? _listController;

  Future<void> _edit(Map<String, dynamic> template) async {
<<<<<<< HEAD
=======
    final l10n = AppLocalizations.of(context);
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    final id = template['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final nameController = TextEditingController(text: template['name']?.toString() ?? '');
    final descController = TextEditingController(text: template['description']?.toString() ?? '');
    final categoryController = TextEditingController(text: template['category']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
<<<<<<< HEAD
        title: const Text('Editar plantilla'),
=======
        title: Text(l10n.adminEditTemplateTitle),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
<<<<<<< HEAD
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Categoría')),
=======
              TextField(controller: nameController, decoration: InputDecoration(labelText: l10n.adminNameLabel)),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: l10n.adminDescriptionLabel),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(controller: categoryController, decoration: InputDecoration(labelText: l10n.adminCategoryLabel)),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
            ],
          ),
        ),
        actions: [
<<<<<<< HEAD
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
=======
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
        ],
      ),
    );
    if (saved != true) return;
    try {
      await _api.update(
        id,
        name: nameController.text.trim(),
        description: descController.text,
        category: categoryController.text.trim(),
      );
      _listController?.reload();
    } catch (e) {
      if (!mounted) return;
<<<<<<< HEAD
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
=======
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminErrorWithDetails('$e'))));
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return AdminPaginatedList(
      searchHint: 'Buscar plantillas',
      emptyLabel: 'Sin plantillas.',
=======
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchHint: l10n.adminSearchTemplatesHint,
      emptyLabel: l10n.adminNoTemplates,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      controllerBuilder: (c) => _listController = c,
      fetch: (page, limit, query) => _api.list(page: page, limit: limit, query: query),
      itemBuilder: (context, item) => ListTile(
        leading: Text(item['emoji']?.toString().isNotEmpty == true ? item['emoji'].toString() : '📄'),
        title: Text(item['name']?.toString() ?? ''),
<<<<<<< HEAD
        subtitle: Text('owner: ${item['ownerUid']} · ${item['category'] ?? ''} · usos: ${item['useCount'] ?? 0}'),
=======
        subtitle: Text('owner: ${item['ownerUid']} · ${item['category'] ?? ''} · uses: ${item['useCount'] ?? 0}'),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
        trailing: !widget.canEdit
            ? null
            : IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(item)),
      ),
    );
  }
}
