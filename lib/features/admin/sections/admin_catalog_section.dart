import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final id = template['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final nameController = TextEditingController(text: template['name']?.toString() ?? '');
    final descController = TextEditingController(text: template['description']?.toString() ?? '');
    final categoryController = TextEditingController(text: template['category']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminEditTemplateTitle),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: l10n.adminNameLabel)),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: l10n.adminDescriptionLabel),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(controller: categoryController, decoration: InputDecoration(labelText: l10n.adminCategoryLabel)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminErrorWithDetails('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchHint: l10n.adminSearchTemplatesHint,
      emptyLabel: l10n.adminNoTemplates,
      controllerBuilder: (c) => _listController = c,
      fetch: (page, limit, query) => _api.list(page: page, limit: limit, query: query),
      itemBuilder: (context, item) => ListTile(
        leading: Text(item['emoji']?.toString().isNotEmpty == true ? item['emoji'].toString() : '📄'),
        title: Text(item['name']?.toString() ?? ''),
        subtitle: Text('owner: ${item['ownerUid']} · ${item['category'] ?? ''} · uses: ${item['useCount'] ?? 0}'),
        trailing: !widget.canEdit
            ? null
            : IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(item)),
      ),
    );
  }
}
