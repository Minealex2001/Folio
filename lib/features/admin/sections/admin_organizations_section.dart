import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_organizations_api.dart';
import '../widgets/admin_paginated_list.dart';

/// Lista y detalle de organizaciones / equipos con grants QA.
class AdminOrganizationsSection extends StatefulWidget {
  const AdminOrganizationsSection({super.key, required this.canGrant});

  final bool canGrant;

  @override
  State<AdminOrganizationsSection> createState() => _AdminOrganizationsSectionState();
}

class _AdminOrganizationsSectionState extends State<AdminOrganizationsSection> {
  final _api = const AdminOrganizationsApi();
  AdminPaginatedListController? _listController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchHint: l10n.adminOrgsSearchHint,
      emptyLabel: l10n.adminNoTeams,
      controllerBuilder: (c) => _listController = c,
      fetch: (page, limit, query) => _api.list(page: page, limit: limit, query: query),
      itemBuilder: (context, item) {
        final id = item['id']?.toString() ?? '';
        final override = item['adminOverride'] == true;
        return ListTile(
          leading: Icon(
            Icons.groups_outlined,
            color: override ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(item['name']?.toString() ?? id),
          subtitle: Text(
            l10n.adminOrgSummary(item['type'] ?? '—', item['plan'] ?? '—', item['memberCount'] ?? 0, item['seats'] ?? 0) +
                (override ? ' · ${l10n.adminQaOverrideBadge}' : ''),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            await showDialog<void>(
              context: context,
              builder: (ctx) => _OrgDetailDialog(
                orgId: id,
                api: _api,
                canGrant: widget.canGrant,
              ),
            );
            _listController?.reload();
          },
        );
      },
    );
  }
}

class _OrgDetailDialog extends StatefulWidget {
  const _OrgDetailDialog({
    required this.orgId,
    required this.api,
    required this.canGrant,
  });

  final String orgId;
  final AdminOrganizationsApi api;
  final bool canGrant;

  @override
  State<_OrgDetailDialog> createState() => _OrgDetailDialogState();
}

class _OrgDetailDialogState extends State<_OrgDetailDialog> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final d = await widget.api.detail(widget.orgId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);
    try {
      final d = await action();
      if (!mounted) return;
      setState(() {
        _detail = d;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).adminErrorWithDetails('$e'))),
      );
    }
  }

  Future<void> _grantCloud() async {
    final l10n = AppLocalizations.of(context);
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminGrantCloudQaOrgTitle),
      content: Text(l10n.adminGrantCloudQaOrgBody),
      confirmLabel: l10n.adminActionGrant,
    );
    if (ok != true) return;
    await _run(() => widget.api.grantCloud(widget.orgId));
  }

  Future<void> _revokeCloud() async {
    final l10n = AppLocalizations.of(context);
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminRevokeCloudQaOrgTitle),
      content: Text(l10n.adminRevokeCloudQaOrgBody),
      confirmLabel: l10n.adminActionRevoke,
      destructive: true,
    );
    if (ok != true) return;
    await _run(() => widget.api.revokeCloud(widget.orgId));
  }

  Future<void> _grantInk() async {
    final l10n = AppLocalizations.of(context);
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminAddInkTitle),
      content: Text(l10n.adminAddInkBody),
      confirmLabel: l10n.adminActionAddInk,
    );
    if (ok != true) return;
    await _run(() => widget.api.grantInk(widget.orgId, inkDrops: 1000));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = _detail;
    final ent = (d?['entitlement'] as Map?) ?? const {};
    final ink = (d?['ink'] as Map?) ?? const {};
    final members = (d?['members'] as List?) ?? const [];
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(d?['name']?.toString() ?? l10n.adminTeamFallbackTitle),
      content: SizedBox(
        width: 480,
        height: 420,
        child: _error != null
            ? Center(child: Text(_error!, style: TextStyle(color: scheme.error)))
            : d == null
                ? const Center(child: FolioLoadingIndicator())
                : ListView(
                    children: [
                      Text('id: ${d['id']}'),
                      Text('type: ${d['type']} · plan: ${d['plan']}'),
                      Text('slug: ${d['slug'] ?? '—'}'),
                      Text(
                        'entitlement: active=${ent['active']} · '
                        'override=${ent['adminOverride']} · '
                        'status=${ent['subscriptionStatus']} · seats=${ent['seats']}',
                      ),
                      Text(
                        'ink: monthly=${ink['monthlyBalance'] ?? 0} · '
                        'purchased=${ink['purchasedBalance'] ?? 0}',
                      ),
                      if (widget.canGrant) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _busy ? null : _grantCloud,
                              child: Text(l10n.adminButtonGrantCloudQa),
                            ),
                            OutlinedButton(
                              onPressed: _busy ? null : _revokeCloud,
                              child: Text(l10n.adminButtonRevoke),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _grantInk,
                              child: Text(l10n.adminAddInkButton),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 24),
                      Text(l10n.adminMembersCount(members.length), style: Theme.of(context).textTheme.titleSmall),
                      for (final raw in members)
                        Builder(
                          builder: (context) {
                            final m = raw is Map ? raw : const {};
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(m['email']?.toString() ?? m['userId']?.toString() ?? ''),
                              subtitle: Text('${m['role'] ?? ''} · ${m['userId'] ?? ''}'),
                            );
                          },
                        ),
                    ],
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }
}
