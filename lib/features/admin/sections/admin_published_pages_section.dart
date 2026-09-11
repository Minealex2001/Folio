import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
<<<<<<< HEAD
=======
import '../../../l10n/generated/app_localizations.dart';
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
import '../../../services/admin/admin_published_pages_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminPublishedPagesSection extends StatefulWidget {
  const AdminPublishedPagesSection({super.key, required this.canDelete});

  final bool canDelete;

  @override
  State<AdminPublishedPagesSection> createState() => _AdminPublishedPagesSectionState();
}

class _AdminPublishedPagesSectionState extends State<AdminPublishedPagesSection> {
  final _api = const AdminPublishedPagesApi();
  AdminPaginatedListController? _listController;

  Future<void> _delete(Map<String, dynamic> page) async {
<<<<<<< HEAD
=======
    final l10n = AppLocalizations.of(context);
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    final id = page['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
<<<<<<< HEAD
      title: const Text('Despublicar página'),
      content: Text('Esto elimina la página publicada "${page['storagePath']}". No se puede deshacer.'),
      confirmLabel: 'Despublicar',
=======
      title: Text(l10n.adminUnpublishPageTitle),
      content: Text(l10n.adminUnpublishPageBody(page['storagePath'])),
      confirmLabel: l10n.adminActionUnpublish,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _api.delete(id);
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
    final scheme = Theme.of(context).colorScheme;
<<<<<<< HEAD
    return AdminPaginatedList(
      searchHint: 'Filtrar por uid del propietario',
      emptyLabel: 'Sin páginas publicadas.',
=======
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchHint: l10n.adminFilterByOwnerUidHint,
      emptyLabel: l10n.adminNoPublishedPages,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      controllerBuilder: (c) => _listController = c,
      fetch: (page, limit, query) => _api.list(page: page, limit: limit, ownerUid: query),
      itemBuilder: (context, item) => ListTile(
        leading: const Icon(Icons.public_rounded),
        title: Text(item['storagePath']?.toString() ?? ''),
        subtitle: Text('owner: ${item['ownerUid']} · ${item['updatedAt'] ?? ''}'),
        trailing: !widget.canDelete
            ? null
            : IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                onPressed: () => _delete(item),
              ),
      ),
    );
  }
}
