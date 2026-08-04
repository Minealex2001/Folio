import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
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
    final uid = _uidController.text.trim();
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Conceder Cloud QA'),
      content: Text('Activa admin_override de Folio Cloud para $uid.'),
      confirmLabel: 'Conceder',
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.grantCloud(uid);
      await _lookup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud QA concedido')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  Future<void> _revokeCloud() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Revocar Cloud QA'),
      content: Text('Quita admin_override de Folio Cloud para $uid.'),
      confirmLabel: 'Revocar',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.revokeCloud(uid);
      await _lookup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud QA revocado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Por usuario'), Tab(text: 'Eventos de webhook')],
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
                  decoration: const InputDecoration(labelText: 'uid del usuario', border: OutlineInputBorder(), isDense: true),
                  onSubmitted: (_) => _lookup(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(onPressed: _loading ? null : _lookup, child: const Text('Buscar')),
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
                  child: const Text('Grant Cloud QA'),
                ),
                OutlinedButton(
                  onPressed: (_loading || _grantBusy) ? null : _revokeCloud,
                  child: const Text('Revoke'),
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
    return AdminPaginatedList(
      searchable: false,
      pageSize: 50,
      emptyLabel: 'Sin eventos procesados.',
      fetch: (page, limit, query) => _api.webhookEvents(page: page, limit: limit),
      itemBuilder: (context, item) => ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(item['eventId']?.toString() ?? ''),
        subtitle: Text('${item['processedAt'] ?? ''}'),
      ),
    );
  }
}
