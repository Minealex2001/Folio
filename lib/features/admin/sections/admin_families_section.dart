import 'package:flutter/material.dart';

import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_families_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminFamiliesSection extends StatelessWidget {
  const AdminFamiliesSection({super.key});

  @override
  Widget build(BuildContext context) {
    const api = AdminFamiliesApi();
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchable: false,
      searchHint: l10n.search,
      emptyLabel: l10n.adminNoFamilies,
      fetch: (page, limit, query) => api.list(page: page, limit: limit),
      itemBuilder: (context, item) => ListTile(
        leading: const Icon(Icons.family_restroom_outlined),
        title: Text(item['ownerUid']?.toString() ?? ''),
        subtitle: Text(l10n.adminFamilySummary(item['memberCount'] ?? 0, item['createdAt'] ?? '')),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => _FamilyDetailDialog(ownerUid: item['ownerUid']?.toString() ?? '', api: api),
        ),
      ),
    );
  }
}

class _FamilyDetailDialog extends StatefulWidget {
  const _FamilyDetailDialog({required this.ownerUid, required this.api});

  final String ownerUid;
  final AdminFamiliesApi api;

  @override
  State<_FamilyDetailDialog> createState() => _FamilyDetailDialogState();
}

class _FamilyDetailDialogState extends State<_FamilyDetailDialog> {
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    widget.api.detail(widget.ownerUid).then((d) {
      if (mounted) setState(() => _detail = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = (_detail?['members'] as List?) ?? const [];
    return AlertDialog(
      title: Text(l10n.adminFamilyOfTitle(widget.ownerUid)),
      content: SizedBox(
        width: 420,
        height: 320,
        child: _detail == null
            ? const Center(child: FolioLoadingIndicator())
            : ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, i) {
                  final m = members[i] as Map;
                  return ListTile(
                    dense: true,
                    title: Text(m['email']?.toString() ?? m['memberUid']?.toString() ?? ''),
                    subtitle: Text('joined: ${m['joinedAt'] ?? '—'}'),
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))],
    );
  }
}
