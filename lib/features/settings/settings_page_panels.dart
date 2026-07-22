part of 'settings_page.dart';

class _ProviderStatusLine extends StatelessWidget {
  const _ProviderStatusLine({
    required this.label,
    required this.installed,
    required this.reachable,
  });

  final String label;
  final bool installed;
  final bool reachable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text(label)),
        Icon(
          installed ? Icons.download_done_rounded : Icons.download_for_offline,
          size: 16,
          color: installed ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Icon(
          reachable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          size: 16,
          color: reachable ? Colors.green : scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Tarjeta-resumen al inicio de un panel de ajustes (mismo lenguaje visual que
/// iconos personalizados e integraciones).
class _SettingsPanelHeroCard extends StatelessWidget {
  const _SettingsPanelHeroCard({
    required this.icon,
    required this.title,
    required this.description,
    this.trailingBadge,
    this.chips = const [],
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailingBadge;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh.withValues(alpha: 0.9),
            scheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onSurfaceVariant, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (trailingBadge != null) ...[
                          const SizedBox(width: 8),
                          trailingBadge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }
}

class _SettingsInfoChip extends StatelessWidget {
  const _SettingsInfoChip({required this.icon, required this.label});

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
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
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

class _IntegrationsHero extends StatelessWidget {
  const _IntegrationsHero({
    required this.approvedCount,
    required this.hintText,
    required this.title,
    required this.featureChips,
  });

  final int approvedCount;
  final String hintText;
  final String title;
  final List<Widget> featureChips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SettingsPanelHeroCard(
      icon: Icons.hub_rounded,
      title: title,
      description: hintText,
      trailingBadge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$approvedCount',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      chips: featureChips,
    );
  }
}

class _IntegrationAppCard extends StatelessWidget {
  const _IntegrationAppCard({
    required this.entry,
    required this.detailsText,
    required this.revokeLabel,
    required this.onRevoke,
  });

  final IntegrationAppApproval entry;
  final String detailsText;
  final String revokeLabel;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              entry.appId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detailsText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRevoke,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(revokeLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, scheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: FolioShadows.card(scheme),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
    );
  }
}

class _SettingsOverviewBanner extends StatelessWidget {
  const _SettingsOverviewBanner({
    required this.appSettings,
    required this.session,
    required this.entitlements,
  });

  final AppSettings appSettings;
  final VaultSession session;
  final FolioCloudEntitlementsController entitlements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    
    final isPremium = entitlements.snapshot.isPaidPlan;
    final subLabel = isPremium 
        ? (Localizations.localeOf(context).languageCode == 'es' ? 'Premium' : 'Premium') 
        : (Localizations.localeOf(context).languageCode == 'es' ? 'Gratuito' : 'Free');

    final vaultLabel = session.vaultUsesEncryption
        ? l10n.encryptedVault
        : (Localizations.localeOf(context).languageCode == 'es'
              ? 'Sin cifrar'
              : 'Unencrypted');

    final vaultVersionLabel = session.vaultFormatVersion == 0
        ? (Localizations.localeOf(context).languageCode == 'es' ? 'v0 (Legacy)' : 'v0 (Legacy)')
        : (Localizations.localeOf(context).languageCode == 'es' ? 'v1 (Tree)' : 'v1 (Tree)');

    final statusLabel = Localizations.localeOf(context).languageCode == 'es' ? 'Al día' : 'Up to date';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.72),
            scheme.tertiaryContainer.withValues(alpha: 0.36),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settings,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'Personaliza la app, gestiona seguridad, IA, copias e integraciones desde un único panel.'
                          : 'Customize the app, security, AI, backups, and integrations from one place.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SettingsOverviewStat(
                icon: Icons.star_rounded,
                label: Localizations.localeOf(context).languageCode == 'es' ? 'Plan' : 'Plan',
                value: subLabel,
              ),
              _SettingsOverviewStat(
                icon: Icons.shield_outlined,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Libreta'
                    : 'Vault',
                value: vaultLabel,
              ),
              _SettingsOverviewStat(
                icon: Icons.storage_rounded,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Versión'
                    : 'Format',
                value: vaultVersionLabel,
              ),
              _SettingsOverviewStat(
                icon: Icons.check_circle_outline_rounded,
                label: Localizations.localeOf(context).languageCode == 'es' ? 'Estado' : 'Status',
                value: statusLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsOverviewStat extends StatelessWidget {
  const _SettingsOverviewStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Agrupa opciones dentro de un panel (sin cambiar el índice de sección del rail).
class _SettingsSubsectionTitle extends StatelessWidget {
  const _SettingsSubsectionTitle({
    required this.title,
    required this.scheme,
    this.topPadding = 16,
  });

  final String title;
  final ColorScheme scheme;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Diálogo de contraseña para el envoltorio de restauración en la nube.
/// El [TextEditingController] vive en el [State] y se dispone al desmontar la ruta.
class _CloudPackWrapPasswordDialog extends StatefulWidget {
  const _CloudPackWrapPasswordDialog({
    required this.l10n,
    required this.encrypted,
  });

  final AppLocalizations l10n;
  final bool encrypted;

  @override
  State<_CloudPackWrapPasswordDialog> createState() =>
      _CloudPackWrapPasswordDialogState();
}

class _CloudPackWrapPasswordDialogState extends State<_CloudPackWrapPasswordDialog> {
  late final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10nDlg = widget.l10n;
    return FolioDialog(
      title: Text(l10nDlg.settingsCloudBackupWrapPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.encrypted
                ? l10nDlg.settingsCloudBackupWrapPasswordBody
                : l10nDlg.settingsCloudBackupWrapPasswordBodyPlain,
          ),
          const SizedBox(height: 12),
          FolioPasswordField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            labelText: l10nDlg.backupPasswordLabel,
            showPasswordTooltip: l10nDlg.showPassword,
            hidePasswordTooltip: l10nDlg.hidePassword,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10nDlg.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_passwordCtrl.text.trim()),
          child: Text(l10nDlg.ok),
        ),
      ],
    );
  }
}

/// Invitación a ver el pitch de Folio Cloud cuando aún no hay sesión (cuenta opcional).
