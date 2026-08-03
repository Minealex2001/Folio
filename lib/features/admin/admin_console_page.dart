import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/widgets/folio_skeletons.dart';
import '../../services/admin/admin_users_api.dart';
import 'admin_object_explorer_page.dart';
import 'admin_user_detail_page.dart';
import 'sections/admin_app_settings_section.dart';
import 'sections/admin_audit_log_section.dart';
import 'sections/admin_billing_section.dart';
import 'sections/admin_catalog_section.dart';
import 'sections/admin_collab_section.dart';
import 'sections/admin_dashboard_section.dart';
import 'sections/admin_diagnostics_section.dart';
import 'sections/admin_families_section.dart';
import 'sections/admin_published_pages_section.dart';
import 'sections/admin_vault_shares_section.dart';
import 'widgets/admin_paginated_list.dart';

enum _AdminSection {
  dashboard,
  users,
  publishedPages,
  diagnostics,
  billing,
  catalog,
  families,
  collab,
  vaultShares,
  auditLog,
  appSettings,
}

int _roleLevel(String role) => switch (role) {
      'SUPER_ADMIN' => 100,
      'BILLING_ADMIN' => 20,
      'MODERATOR' => 20,
      'SUPPORT' => 10,
      _ => 0,
    };

class _NavEntry {
  const _NavEntry(this.section, this.label, this.icon, this.visible);
  final _AdminSection section;
  final String label;
  final IconData icon;
  final bool Function(String role) visible;
}

final _navEntries = <_NavEntry>[
  _NavEntry(_AdminSection.dashboard, 'Inicio', Icons.dashboard_outlined, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.users, 'Usuarios', Icons.people_alt_outlined, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.publishedPages, 'Páginas publicadas', Icons.public_rounded, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.diagnostics, 'Diagnósticos', Icons.bug_report_outlined, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.billing, 'Facturación', Icons.payments_outlined, (r) => r == 'BILLING_ADMIN' || r == 'SUPER_ADMIN'),
  _NavEntry(_AdminSection.catalog, 'Catálogo de templates', Icons.grid_view_rounded, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.families, 'Familias', Icons.family_restroom_outlined, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.collab, 'Salas de colaboración', Icons.groups_2_outlined, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.vaultShares, 'Vault shares', Icons.link_rounded, (r) => _roleLevel(r) >= 10),
  _NavEntry(_AdminSection.auditLog, 'Auditoría', Icons.history_rounded, (r) => r == 'SUPER_ADMIN'),
  _NavEntry(_AdminSection.appSettings, 'Ajustes de la app', Icons.tune_rounded, (r) => r == 'SUPER_ADMIN'),
];

/// Top-level admin console: staff-only, reachable from the workspace (not nested in Settings —
/// this is meant to grow into "manage the whole app/backend", which doesn't fit a Settings
/// subsection). NavigationRail on wide screens, a section drawer on narrow ones; every section
/// is additionally gated server-side, this is UI convenience only.
class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  final _usersApi = const AdminUsersApi();

  String _role = 'NONE';
  bool _roleLoading = true;
  String? _error;
  _AdminSection _active = _AdminSection.dashboard;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final role = await _usersApi.whoami();
      if (!mounted) return;
      setState(() {
        _role = role;
        _roleLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roleLoading = false;
        _error = '$e';
      });
    }
  }

  List<_NavEntry> get _visibleEntries => _navEntries.where((e) => e.visible(_role)).toList();

  bool get _isModeratorOrAbove => const {'MODERATOR', 'BILLING_ADMIN', 'SUPER_ADMIN'}.contains(_role);
  bool get _isSuperAdmin => _role == 'SUPER_ADMIN';

  Widget _buildSection(_AdminSection section) {
    return switch (section) {
      _AdminSection.dashboard => AdminDashboardSection(role: _role),
      _AdminSection.users => _UsersSection(role: _role),
      _AdminSection.publishedPages => AdminPublishedPagesSection(canDelete: _isModeratorOrAbove),
      _AdminSection.diagnostics => AdminDiagnosticsSection(canResolve: _roleLevel(_role) >= 10),
      _AdminSection.billing => const AdminBillingSection(),
      _AdminSection.catalog => AdminCatalogSection(canEdit: _isModeratorOrAbove),
      _AdminSection.families => const AdminFamiliesSection(),
      _AdminSection.collab => const AdminCollabSection(),
      _AdminSection.vaultShares => const AdminVaultSharesSection(),
      _AdminSection.auditLog => const AdminAuditLogSection(),
      _AdminSection.appSettings => const AdminAppSettingsSection(),
    };
  }

  String _titleFor(_AdminSection section) =>
      _navEntries.firstWhere((e) => e.section == section).label;

  @override
  Widget build(BuildContext context) {
    if (_roleLoading) {
      return const Scaffold(body: Center(child: FolioLoadingIndicator()));
    }
    if (_role == 'NONE') {
      return Scaffold(
        appBar: AppBar(title: const Text('Consola de administración')),
        body: _buildNoAccess(Theme.of(context).colorScheme),
      );
    }

    final entries = _visibleEntries;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: Text(_titleFor(_active)),
            leading: wide
                ? null
                : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
            actions: [
              if (_isSuperAdmin)
                IconButton(
                  tooltip: 'Explorador de objetos',
                  icon: const Icon(Icons.folder_open_outlined),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const AdminObjectExplorerPage()),
                  ),
                ),
            ],
          ),
          drawer: wide ? null : Drawer(child: _buildNavList(entries, isDrawer: true)),
          body: Row(
            children: [
              if (wide) SizedBox(width: 240, child: _buildNavList(entries, isDrawer: false)),
              if (wide) const VerticalDivider(width: 1),
              Expanded(child: _buildSection(_active)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavList(List<_NavEntry> entries, {required bool isDrawer}) {
    return SafeArea(
      child: Builder(
        builder: (innerContext) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            for (final entry in entries)
              ListTile(
                leading: Icon(entry.icon),
                title: Text(entry.label),
                selected: entry.section == _active,
                onTap: () {
                  setState(() => _active = entry.section);
                  if (isDrawer) Navigator.of(innerContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccess(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            const Text('No tienes acceso a la consola de administración.'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsersSection extends StatefulWidget {
  const _UsersSection({required this.role});

  final String role;

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection> {
  final _usersApi = const AdminUsersApi();
  AdminPaginatedListController? _listController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminPaginatedList(
      searchHint: 'Buscar por email o uid',
      emptyLabel: 'Sin resultados',
      controllerBuilder: (c) => _listController = c,
      fetch: (page, limit, query) => _usersApi.listUsers(page: page, limit: limit, query: query),
      itemBuilder: (context, u) {
        final uid = u['uid']?.toString() ?? '';
        final status = u['status']?.toString() ?? 'active';
        final usedBytes = (u['usedBytes'] as num?)?.toInt() ?? 0;
        return ListTile(
          leading: Icon(
            status == 'suspended' ? Icons.block_rounded : Icons.person_outline_rounded,
            color: status == 'suspended' ? scheme.error : null,
          ),
          title: Text(u['email']?.toString() ?? uid),
          subtitle: Text(
            '$uid · ${_formatBytes(usedBytes)}'
            '${u['folioStaff'] == true ? ' · staff' : ''}'
            '${u['adminRole'] != null && u['adminRole'] != 'NONE' ? ' · ${u['adminRole']}' : ''}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => AdminUserDetailPage(uid: uid, currentRole: widget.role),
              ),
            );
            _listController?.reload();
          },
        );
      },
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
