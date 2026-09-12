import 'package:flutter/material.dart';

import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/admin/admin_entitlements_api.dart';
import '../../services/admin/admin_storage_api.dart';
import '../../services/admin/admin_users_api.dart';

/// User detail within the admin console: account overview + the storage/cloud-sync cleanup
/// tooling this whole console expansion was built for.
class AdminUserDetailPage extends StatefulWidget {
  const AdminUserDetailPage({
    super.key,
    required this.uid,
    required this.currentRole,
  });

  final String uid;

  /// The signed-in admin's own resolved role — used only to hide actions client-side;
  /// the backend re-checks the real minimum role on every call.
  final String currentRole;

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage>
    with SingleTickerProviderStateMixin {
  final _usersApi = const AdminUsersApi();
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;

  bool get _isModeratorOrAbove =>
      const {'MODERATOR', 'BILLING_ADMIN', 'SUPER_ADMIN'}.contains(widget.currentRole);
  bool get _isSuperAdmin => widget.currentRole == 'SUPER_ADMIN';
  bool get _canBillingGrant =>
      widget.currentRole == 'BILLING_ADMIN' || widget.currentRole == 'SUPER_ADMIN';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _usersApi.getUserDetail(widget.uid);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = _detail?['email']?.toString() ?? widget.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(email),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.adminTabOverview),
            Tab(text: l10n.adminTabStorage),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: FolioLoadingIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                      detail: _detail!,
                      canAssignRole: _isSuperAdmin,
                      canGrantCloud: _canBillingGrant,
                      onRoleChanged: (role) async {
                        final updated = await _usersApi.setUserRole(widget.uid, role);
                        if (!mounted) return;
                        setState(() => _detail = updated);
                      },
                      onReload: _load,
                    ),
                    _StorageTab(
                      uid: widget.uid,
                      canMutate: _isModeratorOrAbove,
                      canReset: _isSuperAdmin,
                    ),
                  ],
                ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({
    required this.detail,
    required this.canAssignRole,
    required this.canGrantCloud,
    required this.onRoleChanged,
    required this.onReload,
  });

  final Map<String, dynamic> detail;
  final bool canAssignRole;
  final bool canGrantCloud;
  final Future<void> Function(String role) onRoleChanged;
  final Future<void> Function() onReload;

  static const _roles = ['NONE', 'SUPPORT', 'MODERATOR', 'BILLING_ADMIN', 'SUPER_ADMIN'];

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _entitlementsApi = const AdminEntitlementsApi();
  bool _grantBusy = false;

  Map<String, dynamic> get detail => widget.detail;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _grantCloud() async {
    final l10n = AppLocalizations.of(context);
    final uid = detail['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminGrantCloudQaTitle),
      content: Text(l10n.adminGrantCloudQaBody),
      confirmLabel: l10n.adminActionGrant,
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.grantCloud(uid);
      await widget.onReload();
      if (!mounted) return;
      _snack(l10n.adminCloudQaGranted);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.adminErrorWithDetails('$e'));
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  Future<void> _revokeCloud() async {
    final l10n = AppLocalizations.of(context);
    final uid = detail['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminRevokeCloudQaTitle),
      content: Text(l10n.adminRevokeCloudQaBody),
      confirmLabel: l10n.adminActionRevoke,
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.revokeCloud(uid);
      await widget.onReload();
      if (!mounted) return;
      _snack(l10n.adminCloudQaRevoked);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.adminErrorWithDetails('$e'));
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cloud = (detail['folioCloud'] as Map?) ?? const {};
    final ink = (detail['ink'] as Map?) ?? const {};
    final orgs = (detail['organizations'] as List?) ?? const [];
    final rows = <(String, String)>[
      ('uid', detail['uid']?.toString() ?? ''),
      ('email', detail['email']?.toString() ?? ''),
      ('displayName', detail['displayName']?.toString() ?? ''),
      ('status', detail['status']?.toString() ?? 'active'),
      ('folioStaff', '${detail['folioStaff'] == true}'),
      ('createdAt', detail['createdAt']?.toString() ?? ''),
      ('emailVerifiedAt', detail['emailVerifiedAt']?.toString() ?? ''),
      ('stripeCustomerId', detail['stripeCustomerId']?.toString() ?? ''),
      (
        'usedBytes / quotaBytes',
        '${detail['usedBytes'] ?? 0} / ${detail['quotaBytes'] ?? 0}',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 180, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(value.isEmpty ? '—' : value)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(l10n.adminSectionFolioCloudQa, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'active: ${cloud['active']} · status: ${cloud['subscriptionStatus'] ?? '—'} · '
          'adminOverride: ${cloud['adminOverride']}',
        ),
        Text(
          'ink monthly: ${ink['monthlyBalance'] ?? '—'} · purchased: ${ink['purchasedBalance'] ?? '—'}',
        ),
        if (widget.canGrantCloud) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _grantBusy ? null : _grantCloud,
                child: Text(l10n.adminButtonGrantCloudQa),
              ),
              OutlinedButton(
                onPressed: _grantBusy ? null : _revokeCloud,
                child: Text(l10n.adminButtonRevoke),
              ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.adminOnlyBillingAdminCanGrant,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(l10n.adminNavTeams, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (orgs.isEmpty)
          Text(l10n.adminNoActiveOrganizations)
        else
          for (final raw in orgs)
            Builder(
              builder: (context) {
                final o = raw is Map ? raw : const {};
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(o['name']?.toString() ?? o['id']?.toString() ?? ''),
                  subtitle: Text(
                    '${o['plan'] ?? '—'} · ${o['role'] ?? ''} · '
                    '${o['adminOverride'] == true ? l10n.adminQaOverrideBadge : l10n.adminNoOverrideBadge}',
                  ),
                );
              },
            ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(l10n.adminSectionAdminRole, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in _OverviewTab._roles)
              ChoiceChip(
                label: Text(role),
                selected: (detail['adminRole']?.toString() ?? 'NONE') == role,
                onSelected: !widget.canAssignRole ? null : (_) => widget.onRoleChanged(role),
              ),
          ],
        ),
        if (!widget.canAssignRole)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.adminOnlySuperAdminCanAssignRoles,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

class _StorageTab extends StatefulWidget {
  const _StorageTab({
    required this.uid,
    required this.canMutate,
    required this.canReset,
  });

  final String uid;
  final bool canMutate;
  final bool canReset;

  @override
  State<_StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends State<_StorageTab> {
  final _api = const AdminStorageApi();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _syncVaults = const [];
  List<Map<String, dynamic>> _backupVaults = const [];
  final _busyVaultIds = <String>{};
  bool _resetBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.summary(widget.uid),
        _api.listDeviceSyncVaults(widget.uid),
        _api.listBackupVaults(widget.uid),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _syncVaults = results[1] as List<Map<String, dynamic>>;
        _backupVaults = results[2] as List<Map<String, dynamic>>;
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

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _withVaultBusy(String vaultId, Future<void> Function() action) async {
    setState(() => _busyVaultIds.add(vaultId));
    try {
      await action();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).adminErrorWithDetails('$e'));
    } finally {
      if (mounted) setState(() => _busyVaultIds.remove(vaultId));
    }
  }

  Future<void> _purge(String vaultId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminPurgeVaultTitle),
      content: Text(l10n.adminPurgeVaultBody(vaultId)),
      confirmLabel: l10n.adminActionPurge,
      destructive: true,
    );
    if (ok != true) return;
    await _withVaultBusy(vaultId, () => _api.purgeDeviceSyncVault(widget.uid, vaultId));
  }

  Future<void> _deleteBackup(String vaultId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminDeleteBackupTitle),
      content: Text(l10n.adminDeleteBackupBody(vaultId)),
      confirmLabel: l10n.adminActionDelete,
      destructive: true,
    );
    if (ok != true) return;
    await _withVaultBusy('backup:$vaultId', () => _api.deleteBackupVault(widget.uid, vaultId));
  }

  Future<void> _resetAll() async {
    final l10n = AppLocalizations.of(context);
    final vaultsCount = _summary?['deviceSyncVaultCount'] ?? 0;
    final backupsCount = _summary?['backupVaultCount'] ?? 0;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminResetCloudSyncTitle),
      content: Text(l10n.adminResetCloudSyncBody(vaultsCount, backupsCount)),
      confirmLabel: l10n.adminActionReset,
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _resetBusy = true);
    try {
      final result = await _api.resetCloudSync(widget.uid);
      if (!mounted) return;
      _snack(
        l10n.adminResetCloudSyncSuccess(result['vaultsPurged'], result['backupVaultsDeleted']),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.adminErrorWithDetails('$e'));
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: FolioLoadingIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: scheme.error)));
    }
    final summary = _summary ?? const {};
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.adminStorageUsageTitle, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    l10n.adminStorageUsedOfQuota(
                      _formatBytes((summary['usedBytes'] as num?)?.toInt() ?? 0),
                      _formatBytes((summary['quotaBytes'] as num?)?.toInt() ?? 0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.adminStorageCountsSummary(
                      summary['deviceSyncVaultCount'] ?? 0,
                      summary['deviceSyncTrashedCount'] ?? 0,
                      summary['backupVaultCount'] ?? 0,
                      summary['backupBlobCount'] ?? 0,
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.adminSyncVaultsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_syncVaults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.adminNoSyncVaults),
            ),
          for (final v in _syncVaults) _buildSyncVaultTile(v, scheme),
          const SizedBox(height: 24),
          Text(l10n.adminBackupsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_backupVaults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.adminNoBackups),
            ),
          for (final v in _backupVaults) _buildBackupVaultTile(v, scheme),
          const SizedBox(height: 32),
          if (widget.canReset) ...[
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminDangerZoneTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.adminDangerZoneBody,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      onPressed: _resetBusy ? null : _resetAll,
                      child: _resetBusy
                          ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                          : Text(l10n.adminResetCloudSyncTitle),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncVaultTile(Map<String, dynamic> v, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    final vaultId = v['vaultId']?.toString() ?? '';
    final trashed = v['trashed'] == true;
    final busy = _busyVaultIds.contains(vaultId);
    final displayName = (v['displayName']?.toString() ?? '').trim();
    return Card(
      child: ListTile(
        leading: Icon(
          trashed ? Icons.delete_outline_rounded : Icons.book_outlined,
          color: trashed ? scheme.error : null,
        ),
        title: Text(displayName.isNotEmpty ? displayName : vaultId),
        subtitle: Text(
          '$vaultId${trashed ? ' · ${l10n.adminTrashedLabel}' : ''}${v['updatedAt'] != null ? ' · ${v['updatedAt']}' : ''}',
        ),
        trailing: busy
            ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
            : !widget.canMutate
                ? null
                : Wrap(
                    spacing: 4,
                    children: [
                      if (!trashed)
                        IconButton(
                          tooltip: l10n.adminMoveToTrashTooltip,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _withVaultBusy(
                            vaultId,
                            () => _api.trashDeviceSyncVault(widget.uid, vaultId),
                          ),
                        )
                      else
                        IconButton(
                          tooltip: l10n.adminRestoreTooltip,
                          icon: const Icon(Icons.restore_rounded),
                          onPressed: () => _withVaultBusy(
                            vaultId,
                            () => _api.restoreDeviceSyncVault(widget.uid, vaultId),
                          ),
                        ),
                      IconButton(
                        tooltip: l10n.adminPurgeForeverTooltip,
                        icon: Icon(Icons.delete_forever_rounded, color: scheme.error),
                        onPressed: () => _purge(vaultId),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildBackupVaultTile(Map<String, dynamic> v, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    final vaultId = v['vaultId']?.toString() ?? '';
    final busy = _busyVaultIds.contains('backup:$vaultId');
    final sizeBytes = (v['latestSizeBytes'] as num?)?.toInt() ?? 0;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: Text(vaultId),
        subtitle: Text(_formatBytes(sizeBytes)),
        trailing: busy
            ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
            : !widget.canMutate
                ? null
                : IconButton(
                    tooltip: l10n.adminDeleteBackupTitle,
                    icon: Icon(Icons.delete_forever_rounded, color: scheme.error),
                    onPressed: () => _deleteBackup(vaultId),
                  ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value < 10 && unitIndex > 0 ? 1 : 0)} ${units[unitIndex]}';
}
