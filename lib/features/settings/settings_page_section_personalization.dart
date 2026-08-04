part of 'settings_page.dart';

/// Primera superficie visible del sistema de personalización de UI (Fases
/// 0-7 del plan) — deliberadamente mínima y aislada en su propio archivo
/// (mismo motivo que `settings_page_section_organization.dart`): el resto
/// de `_SettingsPageState` es la clase más grande/riesgosa del repo, así
/// que esta sección no le añade campos ni lógica nueva, solo lee/escribe
/// [LayoutEngineController] directamente.
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
          child: _PersonalizationSectionBody(layoutEngine: _layoutEngine),
        ),
      ),
    );
  }
}

class _PersonalizationSectionBody extends StatelessWidget {
  const _PersonalizationSectionBody({required this.layoutEngine});

  final LayoutEngineController layoutEngine;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: layoutEngine,
      builder: (context, _) {
        final sidebar = layoutEngine.panelFor(PanelRegionIds.sidebarLeft);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SettingsPanelHeroCard(
              icon: Icons.dashboard_customize_outlined,
              title: 'Personalización (beta)',
              description:
                  'Motor de layout, tema y dashboard nuevos — esta pantalla '
                  'controla directamente el LayoutEngineController que ya '
                  'gestiona el ancho del sidebar en segundo plano.',
              chips: [
                _SettingsInfoChip(
                  icon: Icons.view_sidebar_outlined,
                  label: 'Motor de paneles',
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
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
                    onPressed: () =>
                        unawaited(layoutEngine.resetToDefault()),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer layout de paneles'),
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
