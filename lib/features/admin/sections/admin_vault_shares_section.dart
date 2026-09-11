import 'package:flutter/material.dart';

<<<<<<< HEAD
=======
import '../../../l10n/generated/app_localizations.dart';
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
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
<<<<<<< HEAD
    return AdminPaginatedList(
      searchable: false,
      emptyLabel: 'Sin enlaces de vault share.',
      extraActions: [
        FilterChip(
          label: const Text('Solo activos'),
=======
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchable: false,
      searchHint: l10n.search,
      emptyLabel: l10n.adminNoVaultShareLinks,
      extraActions: [
        FilterChip(
          label: Text(l10n.adminActiveOnlyFilter),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
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
<<<<<<< HEAD
          subtitle: Text('owner: ${item['ownerUid']} · vault: ${item['vaultId']}${revoked ? ' · revocado' : ''}'),
=======
          subtitle: Text('owner: ${item['ownerUid']} · vault: ${item['vaultId']}${revoked ? ' · revoked' : ''}'),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
        );
      },
    );
  }
}
