import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../ui_tokens.dart';

/// Insignia "BETA" compartida por las tarjetas/diálogos de integración que
/// aún no tienen la cobertura o estabilidad de las integraciones ya
/// asentadas (Jira, Trello, GitHub...). Reutiliza la cadena `aiBetaBadge` ya
/// traducida a los 6 idiomas en vez de crear claves nuevas.
class IntegrationBetaBadge extends StatelessWidget {
  const IntegrationBetaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppLocalizations.of(context).aiBetaBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

/// Muestra el diálogo de configuración de una integración como un bottom
/// sheet modal (mismo cromo que "Copias en la nube": tirador, icono+título+X
/// en cabecera), pero más ancho para dar espacio a tabs/formularios.
Future<void> showIntegrationConfigSheet({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: FolioDesktop.editorMaxWidth),
    builder: builder,
  );
}

/// Enmascara un secreto (URL de webhook, token) para mostrarlo en listas,
/// dejando visibles solo los últimos [visibleTail] caracteres.
String maskIntegrationSecret(String value, {int visibleTail = 6}) {
  final v = value.trim();
  if (v.length <= visibleTail) return '•' * v.length;
  return '••••••…${v.substring(v.length - visibleTail)}';
}

/// Widgets compartidos por las tarjetas/diálogos de configuración de
/// integraciones (Jira, YouTrack, Trello, y futuras), para que todas
/// compartan el mismo lenguaje visual usado en el resto de Ajustes
/// (filas de dispositivos vinculados, paneles de Folio Cloud).
class IntegrationStatChip extends StatelessWidget {
  const IntegrationStatChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class IntegrationCard extends StatelessWidget {
  const IntegrationCard({
    super.key,
    this.logoAsset,
    this.brandIcon,
    this.brandColor,
    this.beta = false,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.configureLabel,
    required this.onConfigure,
  }) : assert(
          logoAsset != null || brandIcon != null,
          'Provide either logoAsset or brandIcon',
        );

  /// Ruta de un asset en `appLogos/`. Si es `null`, se usa [brandIcon] en su
  /// lugar (para proveedores sin un logo de marca embebido en el repo).
  final String? logoAsset;
  final IconData? brandIcon;
  final Color? brandColor;
  final bool beta;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final String configureLabel;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: logoAsset != null
                    ? Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(logoAsset!),
                      )
                    : Icon(
                        brandIcon,
                        size: 22,
                        color: brandColor ?? scheme.primary,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (beta) ...[
                      const SizedBox(width: 6),
                      const IntegrationBetaBadge(),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onConfigure,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(configureLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid responsive de tarjetas de integración (2–3 columnas según ancho).
class IntegrationCardsGrid extends StatelessWidget {
  const IntegrationCardsGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900
            ? 3
            : (width >= 520 ? 2 : 1);
        const spacing = 10.0;
        final itemWidth =
            (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Cromo compartido para el sheet de configuración de una integración,
/// calcado del usado por "Copias en la nube"
/// (`folio_cloud_backups_sheet.dart`): cabecera con logo + título + botón
/// de cierre en X, sin fila de acciones al pie. Se muestra vía
/// [showIntegrationConfigSheet].
class IntegrationConfigDialogShell extends StatelessWidget {
  const IntegrationConfigDialogShell({
    super.key,
    this.logoAsset,
    this.brandIcon,
    this.brandColor,
    this.beta = false,
    required this.title,
    required this.tabController,
    required this.connectionsTabLabel,
    required this.sourcesTabLabel,
    required this.connectionsTab,
    required this.sourcesTab,
    this.commandsTabLabel,
    this.commandsTab,
    this.errorText,
  }) : assert(
          logoAsset != null || brandIcon != null,
          'Provide either logoAsset or brandIcon',
        );

  /// Ruta de un asset en `appLogos/`. Si es `null`, se usa [brandIcon].
  final String? logoAsset;
  final IconData? brandIcon;
  final Color? brandColor;
  final bool beta;
  final String title;
  final TabController tabController;
  final String connectionsTabLabel;
  final String sourcesTabLabel;
  final Widget connectionsTab;
  final Widget sourcesTab;
  final String? commandsTabLabel;
  final Widget? commandsTab;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.lg,
          FolioSpace.xs,
          FolioSpace.lg,
          FolioSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: logoAsset != null
                      ? Image.asset(logoAsset!)
                      : Icon(brandIcon, size: 24, color: brandColor ?? scheme.primary),
                ),
                const SizedBox(width: FolioSpace.sm),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (beta) ...[
                        const SizedBox(width: 8),
                        const IntegrationBetaBadge(),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: FolioSpace.xs),
            TabBar(
              controller: tabController,
              tabs: [
                Tab(text: connectionsTabLabel),
                Tab(text: sourcesTabLabel),
                if (commandsTab != null) Tab(text: commandsTabLabel ?? ''),
              ],
            ),
            const SizedBox(height: FolioSpace.sm),
            if (errorText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
                ),
                child: Text(
                  errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ),
              const SizedBox(height: FolioSpace.sm),
            ],
            SizedBox(
              height: 480,
              child: TabBarView(
                controller: tabController,
                children: [
                  connectionsTab,
                  sourcesTab,
                  if (commandsTab != null) commandsTab!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de lista para una conexión o fuente configurada (reemplaza los
/// `Container` bespoke de Jira y los `Card`+`ListTile` de YouTrack/Trello).
class IntegrationEntryRow extends StatelessWidget {
  const IntegrationEntryRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleMaxLines = 1,
    this.extra,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int subtitleMaxLines;
  final Widget? extra;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 6),
                  extra!,
                ],
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// Cabecera de un formulario embebido dentro de una tab del sheet de
/// configuración (p. ej. "Nueva conexión"), con flecha de volver en vez de
/// abrirse como un diálogo apilado encima del sheet.
class IntegrationInlineFormHeader extends StatelessWidget {
  const IntegrationInlineFormHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class IntegrationEmptyState extends StatelessWidget {
  const IntegrationEmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class IntegrationImportOption {
  const IntegrationImportOption({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
}

class IntegrationImportOptionsChips extends StatelessWidget {
  const IntegrationImportOptionsChips({super.key, required this.options});

  final List<IntegrationImportOption> options;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in options)
          FilterChip(
            selected: o.selected,
            onSelected: o.onChanged,
            label: Text(o.label),
          ),
      ],
    );
  }
}
