part of 'settings_page.dart';

/// Fase 3 del roadmap de producto (idea #8, "Privacy Center") — pantalla
/// dedicada que agrega en un solo sitio controles de privacidad que hoy
/// viven repartidos: telemetría/crash reports (`_buildPrivacyDiagnosticsChildren`,
/// sección About), y exportar/eliminar cuenta (ya funcionando end-to-end
/// contra el backend real — `_exportFolioCloudAccountData`,
/// `_requestFolioCloudAccountDeletion`, `_cancelFolioCloudAccountDeletion`
/// en `settings_page_state_folio_cloud.dart`). Es `part of settings_page.dart`
/// (mismo patrón que la sección About) en vez de una pantalla independiente
/// como `FolioHealthScreen`: esas acciones de cuenta son métodos privados de
/// `_SettingsPageState` con su propio manejo de estado ocupado/confirmación
/// — llamarlos directamente evita duplicar esa máquina de estados en una
/// segunda clase. No introduce ninguna proporción "datos locales vs
/// Cloud" inventada (el mockup original pedía un porcentaje): sin una
/// métrica real que lo respalde, se muestra el estado real y booleano de
/// cada control en su lugar.
extension _SettingsPagePrivacyCenter on _SettingsPageState {
  void _openPrivacyCenter() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _buildPrivacyCenterScreen()),
    );
  }

  Widget _buildPrivacyCenterScreen() {
    return _PrivacyCenterScaffold(state: this);
  }
}

class _PrivacyCenterScaffold extends StatelessWidget {
  const _PrivacyCenterScaffold({required this.state});

  final _SettingsPageState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyCenterTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListenableBuilder(
            listenable: Listenable.merge([state._app, state._cloud, state._folio]),
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Text(
                    l10n.privacyCenterIntro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PrivacySectionCard(
                    icon: Icons.smartphone_outlined,
                    title: l10n.privacyCenterLocalSectionTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatusRow(
                          icon: Icons.storage_rounded,
                          label: l10n.privacyCenterLocalDataLabel,
                          value: l10n.privacyCenterAlwaysOn,
                          positive: true,
                        ),
                        _StatusRow(
                          icon: Icons.cloud_sync_outlined,
                          label: l10n.privacyCenterCloudSyncLabel,
                          value: state._cloud.isSignedIn
                              ? l10n.privacyCenterEnabled
                              : l10n.privacyCenterDisabled,
                          positive: !state._cloud.isSignedIn,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PrivacySectionCard(
                    icon: Icons.analytics_outlined,
                    title: l10n.privacyCenterDiagnosticsSectionTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.analytics_outlined),
                          title: Text(l10n.settingsTelemetryTitle),
                          subtitle: Text(l10n.settingsTelemetrySubtitle),
                          value: state._app.telemetryEnabled,
                          onChanged: (v) => state._app.setTelemetryEnabled(v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.bug_report_outlined),
                          title: Text(l10n.settingsAutoCrashReportsTitle),
                          subtitle: Text(l10n.settingsAutoCrashReportsSubtitle),
                          value: state._app.autoCrashReports,
                          onChanged: (v) => state._app.setAutoCrashReports(v),
                        ),
                      ],
                    ),
                  ),
                  if (state._cloud.isSignedIn) ...[
                    const SizedBox(height: 16),
                    _PrivacySectionCard(
                      icon: Icons.folder_shared_outlined,
                      title: l10n.privacyCenterYourDataSectionTitle,
                      child: _buildAccountDataSection(context, l10n, scheme),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDataSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final snap = state._folio.snapshot;
    final pending = snap.hasPendingAccountDeletion;
    final scheduled = snap.accountDeletionScheduledFor;
    final busy = state._folioCloudActionBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pending && scheduled != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.accountDeletePendingBanner(
                MaterialLocalizations.of(context).formatFullDate(scheduled),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.accountExportMyData),
          subtitle: Text(l10n.accountExportMyDataHelp),
          enabled: !busy,
          onTap: busy
              ? null
              : () => unawaited(state._exportFolioCloudAccountData()),
        ),
        if (pending)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.undo_rounded, color: scheme.primary),
            title: Text(l10n.accountDeleteCancel),
            enabled: !busy,
            onTap: busy
                ? null
                : () => unawaited(state._cancelFolioCloudAccountDeletion()),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(
              l10n.accountDeleteRequest,
              style: TextStyle(color: scheme.error),
            ),
            subtitle: Text(l10n.accountDeleteRequestHelp),
            enabled: !busy,
            onTap: busy
                ? null
                : () => unawaited(state._requestFolioCloudAccountDeletion()),
          ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.positive,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: positive ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySectionCard extends StatelessWidget {
  const _PrivacySectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
