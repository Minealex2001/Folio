import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/folio_app_package.dart';
import '../../models/folio_app_registry_entry.dart';
import '../../models/installed_folio_app.dart';
import '../../services/app_store/app_store_service.dart';
import '../../services/app_store/folio_built_in_apps.dart';
import 'widgets/app_detail_sheet.dart';
import 'widgets/app_store_app_card.dart';

/// Pantalla principal de la Tienda de Apps.
class AppStoreScreen extends StatefulWidget {
  const AppStoreScreen({super.key});

  @override
  State<AppStoreScreen> createState() => _AppStoreScreenState();
}

class _AppStoreScreenState extends State<AppStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loadingRegistry = false;
  String? _registryError;

  AppStoreService get _store => AppStoreService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _store.addListener(_onStoreChanged);
    _refreshRegistry();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshRegistry() async {
    setState(() {
      _loadingRegistry = true;
      _registryError = null;
    });
    try {
      await _store.fetchRegistry();
    } catch (e) {
      if (mounted)
        setState(() => _registryError = 'Error al cargar la tienda: $e');
    } finally {
      if (mounted) setState(() => _loadingRegistry = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appStoreTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.appStoreTabExplore),
            Tab(text: l10n.appStoreTabInstalled(_store.installedApps.length)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.appStoreTooltipRefresh,
            onPressed: _refreshRegistry,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: l10n.appStoreTooltipInstallFile,
            onPressed: _installFromFile,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ExploreTab(
            store: _store,
            loading: _loadingRegistry,
            error: _registryError,
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            onRefresh: _refreshRegistry,
            onTapEntry: (entry) =>
                AppDetailSheet.show(context, registryEntry: entry),
            onInstallBuiltIn: _installBuiltIn,
          ),
          _InstalledTab(
            store: _store,
            onTapInstalled: (app) =>
                AppDetailSheet.show(context, installed: app),
          ),
        ],
      ),
    );
  }

  Future<void> _installBuiltIn(FolioAppPackage pkg) async {
    if (_store.isInstalled(pkg.id)) return;
    final result = _store.installBuiltIn(pkg.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (result is AppInstallError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.appStoreInstallError(result.message))),
      );
    } else if (result is AppInstallSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.appStoreInstallSuccess(pkg.name))),
      );
    }
  }

  Future<void> _installFromFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['folioapp', 'zip'],
      dialogTitle: AppLocalizations.of(context).appStoreTooltipInstallFile,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.first.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final innerL10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(innerL10n.appStoreInstallConfirmTitle),
          content: Text(innerL10n.appStoreInstallConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(innerL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(innerL10n.appStoreInstallButton),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final installResult = await _store.installFromBytes(
      bytes,
      grantedPermissions: const [],
    );
    if (!mounted) return;

    if (installResult is AppInstallError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.appStoreInstallError(installResult.message)),
        ),
      );
    } else if (installResult is AppInstallSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.appStoreInstallSuccess(installResult.app.package.name),
          ),
        ),
      );
      _tabController.animateTo(1);
    }
  }
}

// ---------------------------------------------------------------------------
// Tab Explorar
// ---------------------------------------------------------------------------

class _ExploreTab extends StatelessWidget {
  const _ExploreTab({
    required this.store,
    required this.loading,
    required this.error,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onTapEntry,
    required this.onInstallBuiltIn,
  });

  final AppStoreService store;
  final bool loading;
  final String? error;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final ValueChanged<FolioAppRegistryEntry> onTapEntry;
  final Future<void> Function(FolioAppPackage) onInstallBuiltIn;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRefresh,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final entries = store.registry.apps.where((e) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    final builtIns = FolioBuiltInApps.all.where((pkg) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return pkg.name.toLowerCase().contains(q) ||
          pkg.description.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchBar(
            controller: searchController,
            hintText: l10n.appStoreSearchHint,
            onChanged: onSearchChanged,
            leading: const Icon(Icons.search_rounded),
            trailing: searchQuery.isNotEmpty
                ? [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    ),
                  ]
                : null,
          ),
        ),
        Expanded(
          child: (entries.isEmpty && builtIns.isEmpty)
              ? Center(child: Text(l10n.appStoreNoResults))
              : ListView(
                  children: [
                    // ── Sección Oficiales ──────────────────────────────────
                    if (builtIns.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.verified_rounded,
                        label: l10n.appStoreSectionOfficials,
                        subtitle: l10n.appStoreSectionOfficialsSubtitle,
                      ),
                      ...builtIns.map(
                        (pkg) => _BuiltInAppTile(
                          pkg: pkg,
                          installed: store.isInstalled(pkg.id),
                          onInstall: () => onInstallBuiltIn(pkg),
                        ),
                      ),
                      const Divider(height: 32),
                    ],
                    // ── Sección Community / Registry ───────────────────────
                    if (entries.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.public_rounded,
                        label: l10n.appStoreSectionCommunity,
                        subtitle: l10n.appStoreSectionCommunitySubtitle,
                      ),
                      ...entries.map(
                        (entry) => AppStoreAppCard(
                          entry: entry,
                          isInstalled: store.isInstalled(entry.id),
                          onTap: () => onTapEntry(entry),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Instaladas
// ---------------------------------------------------------------------------

class _InstalledTab extends StatelessWidget {
  const _InstalledTab({required this.store, required this.onTapInstalled});

  final AppStoreService store;
  final ValueChanged<InstalledFolioApp> onTapInstalled;

  @override
  Widget build(BuildContext context) {
    final apps = store.installedApps;
    if (apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.widgets_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).appStoreInstalledEmpty,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: apps.length,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemBuilder: (ctx, i) {
        final app = apps[i];
        return InstalledAppCard(
          appId: app.package.id,
          appName: app.package.name,
          version: app.package.version,
          iconUrl: app.package.iconUrl.isNotEmpty ? app.package.iconUrl : null,
          enabled: app.enabled,
          onToggle: (val) => store.setEnabled(app.package.id, enabled: val),
          onUninstall: () => _confirmUninstall(ctx, store, app),
          onTap: () => onTapInstalled(app),
        );
      },
    );
  }

  Future<void> _confirmUninstall(
    BuildContext context,
    AppStoreService store,
    InstalledFolioApp app,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final innerL10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(innerL10n.appStoreUninstallTitle),
          content: Text(innerL10n.appStoreUninstallBody(app.package.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(innerL10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(innerL10n.appStoreUninstallButton),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await store.uninstall(app.package.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers UI
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _BuiltInAppTile extends StatelessWidget {
  const _BuiltInAppTile({
    required this.pkg,
    required this.installed,
    required this.onInstall,
  });

  final FolioAppPackage pkg;
  final bool installed;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: const Icon(Icons.extension_rounded),
      ),
      title: Row(
        children: [
          Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Icon(Icons.verified_rounded, size: 14, color: scheme.primary),
        ],
      ),
      subtitle: Text(
        pkg.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: installed
          ? Chip(
              label: Text(AppLocalizations.of(context).appStoreInstalledChip),
              avatar: const Icon(Icons.check_rounded, size: 16),
              side: BorderSide.none,
              backgroundColor: scheme.secondaryContainer,
            )
          : FilledButton.tonal(
              onPressed: onInstall,
              child: Text(AppLocalizations.of(context).appStoreInstallButton),
            ),
    );
  }
}
