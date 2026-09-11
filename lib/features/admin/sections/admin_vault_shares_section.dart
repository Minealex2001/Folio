import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_vault_shares_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminVaultSharesSection extends StatefulWidget {
  const AdminVaultSharesSection({super.key});

  @override
  State<AdminVaultSharesSection> createState() => _AdminVaultSharesSectionState();
}

class _AdminVaultSharesSectionState extends State<AdminVaultSharesSection> {
  final _api = const AdminVaultSharesApi();
  bool _activeOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchable: false,
      searchHint: l10n.search,
      emptyLabel: l10n.adminNoVaultShareLinks,
      extraActions: [
        FilterChip(
          label: Text(l10n.adminActiveOnlyFilter),
          selected: _activeOnly,
          onSelected: (v) => setState(() => _activeOnly = v),
        ),
      ],
      fetch: (page, limit, query) => _api.list(page: page, limit: limit, activeOnly: _activeOnly),
      itemBuilder: (context, item) {
        final revoked = item['revokedAt'] != null;
        return ListTile(
          leading: Icon(revoked ? Icons.link_off_rounded : Icons.link_rounded),
          title: Text((item['displayName']?.toString().trim().isNotEmpty ?? false) ? item['displayName'].toString() : item['vaultId']?.toString() ?? ''),
          subtitle: Text('owner: ${item['ownerUid']} · vault: ${item['vaultId']}${revoked ? ' · revoked' : ''}'),
        );
      },
    );
  }
}
