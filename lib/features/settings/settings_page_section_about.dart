part of 'settings_page.dart';

/// The "About" section panel of the settings page (version info, release
/// notes, update channel/check). Extracted from the ~4,860-line build()
/// method as one bounded, self-contained Visibility-toggled section, per
/// the plan's "extract section-builder methods/widgets" recommendation.
/// Follows the same `extension _X on _SettingsPageState` convention already
/// used by the `_state_*.dart` part files.
extension _SettingsPageAboutSection on _SettingsPageState {
  Widget _buildAboutSection({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required bool showDesktopOnlySections,
    required _SettingsSectionId? activeSection,
  }) {
    return Visibility(
      visible: activeSection == _SettingsSectionId.about,
      maintainState: false,
      child: KeyedSubtree(
        key: const ValueKey(_SettingsSectionId.about),
        child: _SettingsPanel(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              _SettingsPanelHeroCard(
                icon: Icons.info_outline_rounded,
                title: l10n.about,
                description: l10n.settingsAboutHeroDescription,
              ),
              const Divider(height: 1),
              // Fase 3 del roadmap de producto (idea #6, "Folio Health") —
              // agrega sync/backup/vault ya observables en otras
              // sub-pantallas de Settings en una sola vista de solo
              // lectura; ver `folio_health_screen.dart`.
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: Text(l10n.folioHealthTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => FolioHealthScreen(
                        session: widget.session,
                        appSettings: _app,
                        folioCloudEntitlements: widget.folioCloudEntitlements,
                        cloudDeviceSyncController:
                            widget.cloudDeviceSyncController,
                        onResolveSyncConflicts: _showSyncConflictsDialog,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              // Fase 3 del roadmap de producto (idea #8, "Privacy Center").
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.privacyCenterTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openPrivacyCenter,
              ),
              const Divider(height: 1),
              // Fase 3 del roadmap de producto (idea #7, "Permisos").
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(l10n.permissionsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const FolioPermissionsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ..._buildPrivacyDiagnosticsChildren(
                l10n: l10n,
                scheme: scheme,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l10n.installedVersion),
                subtitle: Text(_installedVersionLabel),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(l10n.settingsOpenReleaseNotes),
                trailing: _openingReleaseNotes
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : null,
                onTap: _openingReleaseNotes ? null : _openReleaseNotesNow,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.balance_outlined),
                title: Text(l10n.settingsOpenThirdPartyLicenses),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ThirdPartyLicensesPage(),
                    ),
                  );
                },
              ),
              if (FolioDistribution.offersGitHubSelfUpdate) ...[
                if (showDesktopOnlySections) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: Text(l10n.updaterGithubRepository),
                    subtitle: Text(
                      '${_app.updaterGithubOwner}/${_app.updaterGithubRepo}',
                    ),
                  ),
                ],
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.settingsUpdateChannelLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<UpdateReleaseChannel>(
                        segments: [
                          ButtonSegment<UpdateReleaseChannel>(
                            value: UpdateReleaseChannel.stable,
                            label: Text(l10n.settingsUpdateChannelRelease),
                            icon: const Icon(
                              Icons.verified_outlined,
                              size: 18,
                            ),
                          ),
                          ButtonSegment<UpdateReleaseChannel>(
                            value: UpdateReleaseChannel.beta,
                            label: Text(l10n.settingsUpdateChannelBeta),
                            icon: const Icon(
                              Icons.science_outlined,
                              size: 18,
                            ),
                          ),
                        ],
                        selected: {_app.updateReleaseChannel},
                        onSelectionChanged: _downloadingUpdate
                            ? null
                            : (s) {
                                _app.setUpdateReleaseChannel(s.first);
                              },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _app.updateReleaseChannel == UpdateReleaseChannel.beta
                            ? l10n.updaterBetaDescription
                            : l10n.updaterStableDescription,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_rounded),
                  title: Text(l10n.checkUpdates),
                  trailing: _checkingUpdates && !_downloadingUpdate
                      ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                      : null,
                  onTap: (_checkingUpdates || _downloadingUpdate)
                      ? null
                      : _checkUpdatesNow,
                ),
                if (_downloadingUpdate) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _installingUpdate
                              ? l10n.updaterInstallingAfterDownload
                              : l10n.updaterDownloadProgressTitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _installingUpdate
                              ? null
                              : _updateDownloadProgress,
                          minHeight: 4,
                        ),
                        if (!_installingUpdate &&
                            _updateDownloadProgress != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            l10n.updaterDownloadProgressPercent(
                              (_updateDownloadProgress! * 100).round(),
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
