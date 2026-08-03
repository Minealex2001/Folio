import 'package:flutter/material.dart';

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
    final id = template['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final nameController = TextEditingController(text: template['name']?.toString() ?? '');
    final descController = TextEditingController(text: template['description']?.toString() ?? '');
    final categoryController = TextEditingController(text: template['category']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar plantilla'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Categoría')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPaginatedList(
      searchHint: 'Buscar plantillas',
      emptyLabel: 'Sin plantillas.',
      controllerBuilder: (c) => _listController = c,
      fetch: (page, limit, query) => _api.list(page: page, limit: limit, query: query),
      itemBuilder: (context, item) => ListTile(
        leading: Text(item['emoji']?.toString().isNotEmpty == true ? item['emoji'].toString() : '📄'),
        title: Text(item['name']?.toString() ?? ''),
        subtitle: Text('owner: ${item['ownerUid']} · ${item['category'] ?? ''} · usos: ${item['useCount'] ?? 0}'),
        trailing: !widget.canEdit
            ? null
            : IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(item)),
      ),
    );
  }
}
