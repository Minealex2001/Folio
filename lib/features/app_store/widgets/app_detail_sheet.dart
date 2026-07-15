import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_app_package.dart';
import '../../../models/folio_app_registry_entry.dart';
import '../../../models/installed_folio_app.dart';
import '../../../services/app_store/app_store_service.dart';
import '../../../services/app_store/integration_auth_service.dart';
import 'app_store_app_card.dart' show AppIcon;

/// Hoja de detalle de una app (desde el registry o instalada).
class AppDetailSheet extends StatefulWidget {
  const AppDetailSheet({super.key, this.registryEntry, this.installed})
    : assert(
        registryEntry != null || installed != null,
        'Se requiere registryEntry o installed',
      );

  final FolioAppRegistryEntry? registryEntry;
  final InstalledFolioApp? installed;

  static Future<void> show(
    BuildContext context, {
    FolioAppRegistryEntry? registryEntry,
    InstalledFolioApp? installed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          AppDetailSheet(registryEntry: registryEntry, installed: installed),
    );
  }

  @override
  State<AppDetailSheet> createState() => _AppDetailSheetState();
}

class _AppDetailSheetState extends State<AppDetailSheet> {
  bool _installing = false;
  String? _errorMsg;

  AppStoreService get _store => AppStoreService.instance;

  String get _appId => widget.registryEntry?.id ?? widget.installed!.package.id;
  String get _appName =>
      widget.registryEntry?.name ?? widget.installed!.package.name;
  String get _description =>
      widget.registryEntry?.description ??
      widget.installed!.package.description;
  String get _author =>
      widget.registryEntry?.author ?? widget.installed!.package.author;
  String get _version =>
      widget.registryEntry?.version ?? widget.installed!.package.version;
  String get _iconUrl =>
      widget.registryEntry?.iconUrl ?? widget.installed!.package.iconUrl;

  bool get _isInstalled => _store.isInstalled(_appId);

  FolioAppPackage? get _installedPackage =>
      _store.installedById(_appId)?.package;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(iconUrl: _iconUrl, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _appName,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _author,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            l10n.appStoreVersionPrefix(_version),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Botón de instalación / desinstalación
                _buildActionButton(context),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMsg!,
                    style: textTheme.bodySmall?.copyWith(color: scheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),

                // Descripción
                Text(_description, style: textTheme.bodyMedium),
                const SizedBox(height: 20),

                // Capacidades
                if (_installedPackage != null) ...[
                  _buildCapabilitiesSection(context, _installedPackage!),
                  const SizedBox(height: 20),
                ],

                // Integraciones OAuth (si instalada)
                if (_isInstalled &&
                    (_store
                            .installedById(_appId)
                            ?.package
                            .integrations
                            .isNotEmpty ??
                        false)) ...[
                  _buildIntegrationsSection(
                    context,
                    _store.installedById(_appId)!.package.integrations,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_installing) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_isInstalled) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.delete_outline_rounded),
        label: Text(l10n.appStoreUninstallButton),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: _uninstall,
      );
    }

    if (widget.registryEntry != null) {
      return FilledButton.icon(
        icon: const Icon(Icons.download_rounded),
        label: Text(l10n.appStoreInstallButton),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: _installFromRegistry,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCapabilitiesSection(
    BuildContext context,
    FolioAppPackage pkg,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final capabilities = <String>[];
    if (pkg.blockTypes.isNotEmpty) {
      capabilities.add(l10n.appStoreCapabilityBlockTypes(pkg.blockTypes.length));
    }
    if (pkg.slashCommands.isNotEmpty) {
      capabilities.add(
        l10n.appStoreCapabilitySlashCommands(pkg.slashCommands.length),
      );
    }
    if (pkg.integrations.isNotEmpty) {
      capabilities.add(
        l10n.appStoreCapabilityIntegrations(pkg.integrations.length),
      );
    }
    if (pkg.aiTransformers.isNotEmpty) {
      capabilities.add(
        l10n.appStoreCapabilityAiTransformers(pkg.aiTransformers.length),
      );
    }
    if (capabilities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appStoreCapabilitiesTitle,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...capabilities.map(
          (c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(c, style: textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntegrationsSection(
    BuildContext context,
    List<FolioAppIntegration> integrations,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appStoreConnectionsTitle,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final integration in integrations)
          ListenableBuilder(
            listenable: IntegrationAuthService.instance,
            builder: (context, child) {
              final status = IntegrationAuthService.instance.statusFor(
                integration.key,
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: Text(integration.displayName),
                subtitle: Text(
                  status.isConnected
                      ? l10n.appStoreConnected
                      : l10n.appStoreNotConnected,
                  style: TextStyle(
                    color: status.isConnected ? Colors.green : null,
                  ),
                ),
                trailing: status.isConnected
                    ? TextButton(
                        onPressed: () => _disconnectIntegration(integration),
                        child: Text(l10n.appStoreDisconnect),
                      )
                    : FilledButton.tonal(
                        onPressed: () => _connectIntegration(integration),
                        child: Text(l10n.appStoreConnect),
                      ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _installFromRegistry() async {
    final entry = widget.registryEntry;
    if (entry == null) return;

    // Pedir confirmación de permisos si la app los requiere
    // (en registry no conocemos permisos hasta descargar; se conceden todos por defecto)
    final confirmed = await _showInstallConfirmDialog(
      context,
      appName: entry.name,
      permissions: const [],
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _installing = true;
      _errorMsg = null;
    });

    final result = await _store.installFromRegistry(
      entry,
      grantedPermissions: const [],
    );

    if (!mounted) return;
    setState(() => _installing = false);

    if (result is AppInstallError) {
      setState(() => _errorMsg = result.message);
    } else {
      setState(() {});
    }
  }

  Future<void> _uninstall() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await FolioDialog.confirm(
      context,
      title: Text(l10n.appStoreUninstallTitle),
      content: Text(l10n.appStoreUninstallBody(_appName)),
      confirmLabel: l10n.appStoreUninstallButton,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _store.uninstall(_appId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _connectIntegration(FolioAppIntegration integration) async {
    final l10n = AppLocalizations.of(context);
    if (integration.authType == FolioAppIntegrationAuthType.oauth2) {
      await IntegrationAuthService.instance.beginOAuthFlow(integration);
      if (!mounted) return;
      // Pedir token manual (hasta que haya deep-link callback)
      final token = await IntegrationAuthService.showTokenInputDialog(
        context,
        title: l10n.appStorePasteAccessToken,
        label: l10n.appStoreTokenLabel(integration.displayName),
      );
      if (token != null && token.isNotEmpty) {
        await IntegrationAuthService.instance.saveOAuthToken(
          integration.key,
          token,
        );
      }
    } else {
      final apiKey = await IntegrationAuthService.showTokenInputDialog(
        context,
        title: l10n.appStoreApiKeyTitle,
        label: integration.apiKeyLabel ?? l10n.appStoreApiKeyTitle,
      );
      if (apiKey != null && apiKey.isNotEmpty) {
        await IntegrationAuthService.instance.saveApiKey(
          integration.key,
          apiKey,
        );
      }
    }
  }

  Future<void> _disconnectIntegration(FolioAppIntegration integration) async {
    await IntegrationAuthService.instance.disconnect(integration.key);
  }

  static Future<bool> _showInstallConfirmDialog(
    BuildContext context, {
    required String appName,
    required List<FolioAppPermission> permissions,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await FolioDialog.confirm(
      context,
      title: Text(l10n.appStoreInstallFromRegistryTitle(appName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.appStoreInstallUnverifiedLocalBody),
          if (permissions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.appStorePermissionsRequested,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            for (final p in permissions)
              Text('• ${folioAppPermissionDisplayName(p)}'),
          ],
        ],
      ),
      confirmLabel: l10n.appStoreInstallButton,
    );
    return result == true;
  }
}
