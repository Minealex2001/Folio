import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_billing_api.dart';
import '../../../services/admin/admin_entitlements_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminBillingSection extends StatefulWidget {
  const AdminBillingSection({super.key});

  @override
  State<AdminBillingSection> createState() => _AdminBillingSectionState();
}

class _AdminBillingSectionState extends State<AdminBillingSection> with SingleTickerProviderStateMixin {
  final _api = const AdminBillingApi();
  final _entitlementsApi = const AdminEntitlementsApi();
  final _uidController = TextEditingController();
  late final TabController _tabController = TabController(length: 2, vsync: this);
  bool _loading = false;
  bool _grantBusy = false;
  String? _error;
  Map<String, dynamic>? _billing;

  @override
  void dispose() {
    _uidController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final billing = await _api.userBilling(uid);
      if (!mounted) return;
      setState(() {
        _billing = billing;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _grantCloud() async {
    final l10n = AppLocalizations.of(context);
    final uid = _uidController.text.trim();
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminGrantCloudQaTitle),
      content: Text(l10n.adminGrantCloudQaForUidBody(uid)),
      confirmLabel: l10n.adminActionGrant,
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.grantCloud(uid);
      await _lookup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminCloudQaGranted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminErrorWithDetails('$e'))));
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  Future<void> _revokeCloud() async {
    final l10n = AppLocalizations.of(context);
    final uid = _uidController.text.trim();
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminRevokeCloudQaTitle),
      content: Text(l10n.adminRevokeCloudQaForUidBody(uid)),
      confirmLabel: l10n.adminActionRevoke,
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.revokeCloud(uid);
      await _lookup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminCloudQaRevoked)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminErrorWithDetails('$e'))));
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [Tab(text: l10n.adminTabByUser), Tab(text: l10n.adminTabWebhookEvents)],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildUserLookup(), _buildWebhookEvents()],
          ),
        ),
      ],
    );
  }

  Widget _buildUserLookup() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _uidController,
                  decoration: InputDecoration(labelText: l10n.adminUidInputLabel, border: const OutlineInputBorder(), isDense: true),
                  onSubmitted: (_) => _lookup(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(onPressed: _loading ? null : _lookup, child: Text(l10n.search)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const Center(child: FolioLoadingIndicator()),
          if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
          if (_billing != null) Expanded(child: SingleChildScrollView(child: _buildBillingCard(_billing!))),
        ],
      ),
    );
  }

  Widget _buildBillingCard(Map<String, dynamic> billing) {
    final l10n = AppLocalizations.of(context);
    final cloud = (billing['folioCloud'] as Map?) ?? const {};
    final stripe = (billing['stripe'] as Map?) ?? const {};
    final ms = (billing['microsoftStore'] as Map?) ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('uid: ${billing['uid']}'),
            Text('stripeCustomerId: ${billing['stripeCustomerId'] ?? '—'}'),
            const Divider(height: 24),
            Text('Folio Cloud', style: Theme.of(context).textTheme.titleSmall),
            Text('active: ${cloud['active']} · status: ${cloud['subscriptionStatus'] ?? '—'}'),
            Text('priceId: ${cloud['subscriptionPriceId'] ?? '—'} · family: ${cloud['family']} · student: ${cloud['student']} · adminOverride: ${cloud['adminOverride']}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: (_loading || _grantBusy) ? null : _grantCloud,
                  child: Text(l10n.adminButtonGrantCloudQa),
                ),
                OutlinedButton(
                  onPressed: (_loading || _grantBusy) ? null : _revokeCloud,
                  child: Text(l10n.adminButtonRevoke),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Stripe', style: Theme.of(context).textTheme.titleSmall),
            Text('subscriptionId: ${stripe['subscriptionId'] ?? '—'} · priceId: ${stripe['priceId'] ?? '—'}'),
            Text('familySeats: ${stripe['familySeats'] ?? 0} · studentVerified: ${stripe['studentVerified']}'),
            const Divider(height: 24),
            Text('Microsoft Store', style: Theme.of(context).textTheme.titleSmall),
            Text('active: ${ms['subscriptionActive']} · product: ${ms['subscriptionStoreProductId'] ?? '—'}'),
            Text('lastValidatedAt: ${ms['lastValidatedAt'] ?? '—'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildWebhookEvents() {
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchable: false,
      searchHint: l10n.search,
      pageSize: 50,
      emptyLabel: l10n.adminNoWebhookEvents,
      fetch: (page, limit, query) => _api.webhookEvents(page: page, limit: limit),
      itemBuilder: (context, item) => ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(item['eventId']?.toString() ?? ''),
        subtitle: Text('${item['processedAt'] ?? ''}'),
      ),
    );
  }
}
