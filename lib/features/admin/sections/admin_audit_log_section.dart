import 'package:flutter/material.dart';

<<<<<<< HEAD
=======
import '../../../l10n/generated/app_localizations.dart';
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
import '../../../services/admin/admin_audit_log_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminAuditLogSection extends StatelessWidget {
  const AdminAuditLogSection({super.key});

  @override
  Widget build(BuildContext context) {
    const api = AdminAuditLogApi();
<<<<<<< HEAD
    return AdminPaginatedList(
      searchable: false,
      pageSize: 50,
      emptyLabel: 'Sin actividad registrada todavía.',
=======
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchable: false,
      searchHint: l10n.search,
      pageSize: 50,
      emptyLabel: l10n.adminNoAuditActivity,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      fetch: (page, limit, query) => api.list(page: page, limit: limit),
      itemBuilder: (context, item) => ListTile(
        leading: const Icon(Icons.history_rounded),
        title: Text(item['action']?.toString() ?? ''),
        subtitle: Text(
          '${item['actorLabel'] ?? 'admin-api-key'} · ${item['targetType'] ?? ''}:${item['targetId'] ?? ''} · ${item['createdAt'] ?? ''}',
        ),
        isThreeLine: false,
      ),
    );
  }
}
