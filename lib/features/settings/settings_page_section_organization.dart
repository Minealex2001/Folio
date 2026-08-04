part of 'settings_page.dart';

/// Fase 13 del roadmap de Organizations. Deliberadamente NO añade campos
/// de estado nuevos a `_SettingsPageState` — la lógica vive por completo en
/// `OrganizationManagementPanel` (`organization_management_panel.dart`),
/// autocontenido, para minimizar el riesgo de tocar una clase de estado
/// compartida y ya muy grande sin poder probar la UI en esta sesión.
extension _SettingsPageOrganizationSection on _SettingsPageState {
  Widget _buildOrganizationSection({
    required ColorScheme scheme,
    required _SettingsSectionId? activeSection,
  }) {
    final controller = _organizationContext;
    return Visibility(
      visible: activeSection == _SettingsSectionId.organization,
      maintainState: false,
      child: KeyedSubtree(
        key: const ValueKey(_SettingsSectionId.organization),
        child: _SettingsPanel(
          margin: const EdgeInsets.only(bottom: 24),
          child: controller == null
              ? const SizedBox.shrink()
              : OrganizationManagementPanel(controller: controller),
        ),
      ),
    );
  }
}
