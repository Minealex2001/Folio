part of 'settings_page.dart';

/// Primera superficie visible del sistema de personalización de UI (Fases
/// 0-7 del plan) — deliberadamente mínima y aislada en su propio archivo
/// (mismo motivo que `settings_page_section_organization.dart`): el resto
/// de `_SettingsPageState` es la clase más grande/riesgosa del repo, así
/// que esta sección no le añade campos ni lógica nueva, solo lee/escribe
/// [LayoutEngineController]/[ThemeConfigController] directamente.
extension _SettingsPagePersonalizationSection on _SettingsPageState {
  Widget _buildPersonalizationSection({
    required ColorScheme scheme,
    required _SettingsSectionId? activeSection,
  }) {
    return Visibility(
      visible: activeSection == _SettingsSectionId.personalization,
      maintainState: false,
      child: KeyedSubtree(
        key: const ValueKey(_SettingsSectionId.personalization),
        child: _SettingsPanel(
          margin: const EdgeInsets.only(bottom: 24),
          child: _PersonalizationSectionBody(
            layoutEngine: _layoutEngine,
            themeConfig: _themeConfig,
          ),
        ),
      ),
    );
  }
}

class _PersonalizationSectionBody extends StatelessWidget {
  const _PersonalizationSectionBody({
    required this.layoutEngine,
    required this.themeConfig,
  });

  final LayoutEngineController layoutEngine;
  final ThemeConfigController themeConfig;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([layoutEngine, themeConfig]),
      builder: (context, _) {
        final sidebar = layoutEngine.panelFor(PanelRegionIds.sidebarLeft);
        final theme = themeConfig.config;
        final cornerScale = theme.shape.radiusMd == 0
            ? 1.0
            : theme.shape.radiusMd / kFolioDefaultTheme.shape.radiusMd;
        final spacingScale = theme.spacing.md == 0
            ? 1.0
            : theme.spacing.md / kFolioDefaultTheme.spacing.md;
        final motionSpeed = theme.motion.short2Ms == 0
            ? 1.0
            : kFolioDefaultTheme.motion.short2Ms / theme.motion.short2Ms;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SettingsPanelHeroCard(
              icon: Icons.dashboard_customize_outlined,
              title: 'Personalización (beta)',
              description:
                  'Motor de layout, tema y dashboard nuevos — esta pantalla '
                  'controla directamente los controllers en vivo que ya '
                  'renderiza la app.',
              chips: [
                _SettingsInfoChip(
                  icon: Icons.view_sidebar_outlined,
                  label: 'Motor de paneles',
                ),
                _SettingsInfoChip(
                  icon: Icons.palette_outlined,
                  label: 'Motor de tema',
                ),
              ],
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Panel lateral',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sidebar == null
                        ? 'Región no disponible.'
                        : 'Ancho actual: ${sidebar.width?.toStringAsFixed(0) ?? '—'} px',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bloquear panel lateral'),
                    subtitle: const Text(
                      'Impide redimensionar/mover el sidebar hasta que se '
                      'desbloquee de nuevo.',
                    ),
                    value: sidebar?.locked ?? false,
                    onChanged: sidebar == null
                        ? null
                        : (value) => layoutEngine.setLocked(
                            PanelRegionIds.sidebarLeft,
                            value,
                          ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(layoutEngine.resetToDefault()),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer layout de paneles'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Editor de tema',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El color de acento y el modo claro/oscuro se editan en '
                    '"Apariencia" — esto controla la forma, densidad, '
                    'movimiento y transparencia del resto de la app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ThemeSlider(
                    label: 'Redondez de esquinas',
                    value: cornerScale,
                    min: 0.0,
                    max: 2.0,
                    onChanged: themeConfig.setCornerRoundness,
                  ),
                  _ThemeSlider(
                    label: 'Densidad de espaciado',
                    value: spacingScale,
                    min: 0.6,
                    max: 1.6,
                    onChanged: themeConfig.setSpacingDensity,
                  ),
                  _ThemeSlider(
                    label: 'Velocidad de movimiento',
                    value: motionSpeed,
                    min: 0.4,
                    max: 2.5,
                    onChanged: themeConfig.setMotionSpeed,
                  ),
                  _ThemeSlider(
                    label: 'Opacidad de superficies',
                    value: theme.surfaceOpacity,
                    min: 0.5,
                    max: 1.0,
                    onChanged: themeConfig.setSurfaceOpacity,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        unawaited(themeConfig.resetToDefault()),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer tema'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeSlider extends StatelessWidget {
  const _ThemeSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: clamped,
              min: min,
              max: max,
              label: clamped.toStringAsFixed(2),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
