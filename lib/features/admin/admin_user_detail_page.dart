import 'package:flutter/material.dart';

import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_skeletons.dart';
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
    final email = _detail?['email']?.toString() ?? widget.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(email),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Almacenamiento'),
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
    final uid = detail['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Conceder Cloud QA'),
      content: const Text(
        'Activa admin_override con features completas de Folio Cloud para este usuario.',
      ),
      confirmLabel: 'Conceder',
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.grantCloud(uid);
      await widget.onReload();
      if (!mounted) return;
      _snack('Cloud QA concedido');
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  Future<void> _revokeCloud() async {
    final uid = detail['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Revocar Cloud QA'),
      content: const Text('Quita admin_override de Folio Cloud para este usuario.'),
      confirmLabel: 'Revocar',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _grantBusy = true);
    try {
      await _entitlementsApi.revokeCloud(uid);
      await widget.onReload();
      if (!mounted) return;
      _snack('Cloud QA revocado');
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _grantBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        Text('Folio Cloud QA', style: Theme.of(context).textTheme.titleMedium),
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
                child: const Text('Grant Cloud QA'),
              ),
              OutlinedButton(
                onPressed: _grantBusy ? null : _revokeCloud,
                child: const Text('Revoke'),
              ),
            ],
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Solo BILLING_ADMIN / SUPER_ADMIN pueden conceder Cloud QA.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text('Equipos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (orgs.isEmpty)
          const Text('Sin organizaciones activas.')
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
                    '${o['adminOverride'] == true ? 'QA override' : 'sin override'}',
                  ),
                );
              },
            ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text('Rol de administrador', style: Theme.of(context).textTheme.titleMedium),
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
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Solo SUPER_ADMIN puede asignar roles.',
              style: TextStyle(fontStyle: FontStyle.italic),
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
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busyVaultIds.remove(vaultId));
    }
  }

  Future<void> _purge(String vaultId) async {
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Purgar libreta definitivamente'),
      content: Text(
        'Esto borra permanentemente "$vaultId" del cloud sync de este usuario '
        '(storage + metadatos). No se puede deshacer.',
      ),
      confirmLabel: 'Purgar',
      destructive: true,
    );
    if (ok != true) return;
    await _withVaultBusy(vaultId, () => _api.purgeDeviceSyncVault(widget.uid, vaultId));
  }

  Future<void> _deleteBackup(String vaultId) async {
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Borrar copia de seguridad'),
      content: Text('Esto borra la copia de seguridad en la nube de "$vaultId". No se puede deshacer.'),
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (ok != true) return;
    await _withVaultBusy('backup:$vaultId', () => _api.deleteBackupVault(widget.uid, vaultId));
  }

  Future<void> _resetAll() async {
    final vaultsCount = _summary?['deviceSyncVaultCount'] ?? 0;
    final backupsCount = _summary?['backupVaultCount'] ?? 0;
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Restablecer sincronización en la nube'),
      content: Text(
        'Esto purga las $vaultsCount libretas de cloud sync y las $backupsCount copias de '
        'seguridad de este usuario, revoca sus vault shares y pone su uso a 0. '
        'Es la opción nuclear para una cuenta rota — no se puede deshacer.',
      ),
      confirmLabel: 'Restablecer',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _resetBusy = true);
    try {
      final result = await _api.resetCloudSync(widget.uid);
      if (!mounted) return;
      _snack(
        'Reset OK: ${result['vaultsPurged']} libretas, ${result['backupVaultsDeleted']} backups.',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Text('Uso de almacenamiento', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatBytes((summary['usedBytes'] as num?)?.toInt() ?? 0)} '
                    'de ${_formatBytes((summary['quotaBytes'] as num?)?.toInt() ?? 0)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary['deviceSyncVaultCount'] ?? 0} libretas '
                    '(${summary['deviceSyncTrashedCount'] ?? 0} en papelera) · '
                    '${summary['backupVaultCount'] ?? 0} backups '
                    '(${summary['backupBlobCount'] ?? 0} blobs)',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Libretas (cloud sync)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_syncVaults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin libretas sincronizadas.'),
            ),
          for (final v in _syncVaults) _buildSyncVaultTile(v, scheme),
          const SizedBox(height: 24),
          Text('Copias de seguridad', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_backupVaults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin copias de seguridad.'),
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
                      'Zona de peligro',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Restablecer la sincronización en la nube de este usuario: purga todas '
                      'las libretas y copias de seguridad, y pone su uso a 0.',
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
                          : const Text('Restablecer sincronización en la nube'),
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
          '$vaultId${trashed ? ' · en papelera' : ''}${v['updatedAt'] != null ? ' · ${v['updatedAt']}' : ''}',
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
                          tooltip: 'Mover a papelera',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _withVaultBusy(
                            vaultId,
                            () => _api.trashDeviceSyncVault(widget.uid, vaultId),
                          ),
                        )
                      else
                        IconButton(
                          tooltip: 'Restaurar',
                          icon: const Icon(Icons.restore_rounded),
                          onPressed: () => _withVaultBusy(
                            vaultId,
                            () => _api.restoreDeviceSyncVault(widget.uid, vaultId),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Purgar definitivamente',
                        icon: Icon(Icons.delete_forever_rounded, color: scheme.error),
                        onPressed: () => _purge(vaultId),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildBackupVaultTile(Map<String, dynamic> v, ColorScheme scheme) {
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
                    tooltip: 'Borrar copia de seguridad',
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
