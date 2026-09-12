import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_audit_log_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminAuditLogSection extends StatelessWidget {
  const AdminAuditLogSection({super.key});

  @override
  Widget build(BuildContext context) {
    const api = AdminAuditLogApi();
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchable: false,
      searchHint: l10n.search,
      pageSize: 50,
      emptyLabel: l10n.adminNoAuditActivity,
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
