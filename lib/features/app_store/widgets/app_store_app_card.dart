import 'package:flutter/material.dart';

import '../../../models/folio_app_registry_entry.dart';
import '../../../services/app_store/app_store_service.dart';

/// Tarjeta de una app en la tienda (para el listado del registry).
class AppStoreAppCard extends StatelessWidget {
  const AppStoreAppCard({
    super.key,
    required this.entry,
    required this.isInstalled,
    required this.onTap,
  });

  final FolioAppRegistryEntry entry;
  final bool isInstalled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono
              AppIcon(iconUrl: entry.iconUrl, size: 48),
              const SizedBox(width: 12),
              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.verifiedByFolio)
                          Tooltip(
                            message: 'Verificado por Folio',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                        const SizedBox(width: 4),
                        if (isInstalled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Instalada',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.author,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.description,
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (entry.tags.isNotEmpty) ...[
                          for (final tag in entry.tags.take(3))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _TagChip(label: tag),
                            ),
                        ],
                        const Spacer(),
                        if (entry.rating > 0)
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: scheme.tertiary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                entry.rating.toStringAsFixed(1),
                                style: textTheme.labelSmall,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de una app instalada (para la sección "Mis apps").
class InstalledAppCard extends StatelessWidget {
  const InstalledAppCard({
    super.key,
    required this.appId,
    required this.appName,
    required this.version,
    required this.iconUrl,
    required this.enabled,
    required this.onToggle,
    required this.onUninstall,
    required this.onTap,
  });

  final String appId;
  final String appName;
  final String version;
  final String? iconUrl;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUninstall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AppIcon(iconUrl: iconUrl ?? '', size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'v$version',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                tooltip: 'Desinstalar',
                onPressed: onUninstall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Widget para el icono de una app (intenta mostrar la URL, si falla muestra placeholder).
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.iconUrl, required this.size});
  final String iconUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(scheme),
        ),
      );
    }

    return _placeholder(scheme);
  }

  Widget _placeholder(ColorScheme scheme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.widgets_outlined,
        size: size * 0.5,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
