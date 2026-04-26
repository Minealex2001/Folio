import 'dart:async';

import 'package:flutter/material.dart';

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
                            'v$_version',
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
                  _buildCapabilitiesSection(_installedPackage!),
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
    if (_installing) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_isInstalled) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Desinstalar'),
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
        label: const Text('Instalar'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: _installFromRegistry,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCapabilitiesSection(FolioAppPackage pkg) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final capabilities = <String>[];
    if (pkg.blockTypes.isNotEmpty) {
      capabilities.add('${pkg.blockTypes.length} tipo(s) de bloque');
    }
    if (pkg.slashCommands.isNotEmpty) {
      capabilities.add('${pkg.slashCommands.length} comando(s) slash');
    }
    if (pkg.integrations.isNotEmpty) {
      capabilities.add('${pkg.integrations.length} integración(es)');
    }
    if (pkg.aiTransformers.isNotEmpty) {
      capabilities.add('${pkg.aiTransformers.length} transformer(s) IA');
    }
    if (capabilities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capacidades',
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

  Widget _buildIntegrationsSection(List<FolioAppIntegration> integrations) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conexiones',
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
                  status.isConnected ? 'Conectado' : 'No conectado',
                  style: TextStyle(
                    color: status.isConnected ? Colors.green : null,
                  ),
                ),
                trailing: status.isConnected
                    ? TextButton(
                        onPressed: () => _disconnectIntegration(integration),
                        child: const Text('Desconectar'),
                      )
                    : FilledButton.tonal(
                        onPressed: () => _connectIntegration(integration),
                        child: const Text('Conectar'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desinstalar app'),
        content: Text('¿Desinstalar "$_appName"? Se eliminarán sus archivos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desinstalar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _store.uninstall(_appId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _connectIntegration(FolioAppIntegration integration) async {
    if (integration.authType == FolioAppIntegrationAuthType.oauth2) {
      await IntegrationAuthService.instance.beginOAuthFlow(integration);
      if (!mounted) return;
      // Pedir token manual (hasta que haya deep-link callback)
      final token = await IntegrationAuthService.showTokenInputDialog(
        context,
        title: 'Pega tu access token',
        label: 'Token de ${integration.displayName}',
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
        title: 'API Key',
        label: integration.apiKeyLabel ?? 'API Key',
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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Instalar "$appName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta app no ha sido verificada localmente. '
              'Instala solo apps de fuentes en las que confíes.',
            ),
            if (permissions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Permisos que solicita:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final p in permissions)
                Text('• ${folioAppPermissionDisplayName(p)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Instalar'),
          ),
        ],
      ),
    );
    return result == true;
  }
}
