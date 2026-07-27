part of 'settings_page.dart';

extension _SettingsPageBackupFlows on _SettingsPageState {
  Future<void> _openExportBackupFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.exportVaultDialogTitle),
        body: Text(l10n.exportVaultDialogBody),
        passwordButtonLabel: l10n.verifyAndExport,
      ),
    );
    if (verified != true || !mounted) return;

    final canFolder = _vaultBackupPrefs.hasConfiguredFolder;
    final canWebdav = _vaultBackupPrefs.hasConfiguredWebDav;
    RemoteBackupExportChoice? choice = RemoteBackupExportChoice.localFile;
    if (canFolder || canWebdav) {
      final picked = await RemoteBackupExportDestinationDialog.show(
        context,
        l10n: l10n,
        canFolder: canFolder,
        canWebdav: canWebdav,
      );
      if (picked == null || !mounted) return;
      choice = picked;
    }

    try {
      if (choice == RemoteBackupExportChoice.localFile) {
        final path = await FilePicker.saveFile(
          dialogTitle: l10n.saveVaultBackupDialogTitle,
          fileName: _suggestedBackupFileName(),
          type: FileType.custom,
          allowedExtensions: const ['zip'],
        );
        if (path == null || !mounted) return;
        await _s.exportVaultBackup(path);
      } else {
        if (_vaultId == null) return;
        BackupDestination? only;
        if (choice == RemoteBackupExportChoice.configuredFolder) {
          only = await VaultBackupDestinations.configuredFolder(
            prefs: _vaultBackupPrefs,
            vaultId: _vaultId!,
            credentials: _backupCredentials,
          );
        } else {
          only = await VaultBackupDestinations.configuredWebDav(
            prefs: _vaultBackupPrefs,
            vaultId: _vaultId!,
            credentials: _backupCredentials,
          );
        }
        if (only == null || !mounted) return;
        await showVaultBackupProgressDialog(
          context: context,
          l10n: l10n,
          work: (ctrl) async {
            ctrl.setProgress(0, indeterminate: true);
            await BackupExportRunner(credentials: _backupCredentials)
                .exportToDestinations(
              session: _s,
              prefs: _vaultBackupPrefs,
              vaultId: _vaultId!,
              onlyDestinations: [only!],
            );
            ctrl.setProgress(1, indeterminate: false);
          },
        );
      }
      if (mounted) {
        _snack(l10n.backupSavedSuccessSnack);
      }
    } on VaultBackupException catch (e) {
      if (mounted) _snack(l10n.exportFailedError('$e'));
    } catch (e) {
      if (mounted) {
        _snack(l10n.exportFailedError('$e'));
      }
    }
  }

  Future<void> _openImportBackupFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.importVaultDialogTitle),
        content: SingleChildScrollView(
          child: Text(
            l10n.importVaultDialogBody,
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.confirmIdentity),
        body: Text(l10n.importIdentityBody),
        passwordButtonLabel: l10n.verifyAndContinue,
      ),
    );
    if (verified != true || !mounted) return;

    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final fp = pick.files.single.path;
    if (fp == null) {
      _snack(l10n.filePathReadError);
      return;
    }

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _BackupPasswordDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    try {
      await _s.importVaultBackupAsNew(fp, password);
      await _refreshSecurityFlags();
      if (!mounted) return;
      _snack(l10n.importedVaultSuccessSnack);
      Navigator.of(context).pop();
    } on VaultBackupException catch (e) {
      if (mounted) _snack(l10n.importFailedGenericError('$e'));
    } catch (e) {
      if (mounted) _snack(l10n.importFailedGenericError('$e'));
    }
  }

  Future<void> _openImportNotionFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.importNotionDialogTitle),
        body: Text(l10n.importNotionDialogBody),
        passwordButtonLabel: l10n.verifyAndContinue,
      ),
    );
    if (verified != true || !mounted) return;

    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final fp = pick.files.single.path;
    if (fp == null) {
      _snack(l10n.filePathReadError);
      return;
    }

    final mode = await showDialog<_NotionImportMode>(
      context: context,
      builder: (ctx) => const _NotionImportModeDialog(),
    );
    if (mode == null || !mounted) return;

    try {
      if (mode == _NotionImportMode.currentVault) {
        await _s.importNotionIntoCurrentVault(fp);
        if (!mounted) return;
        _snack(l10n.importNotionSuccessCurrent);
      } else {
        final newPassword = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _NewVaultPasswordDialog(),
        );
        if (newPassword == null || newPassword.isEmpty || !mounted) return;
        await _s.importNotionAsNewVault(
          fp,
          masterPassword: newPassword,
          displayName: l10n.importNotionDefaultVaultName,
        );
        if (!mounted) return;
        _snack(l10n.importNotionSuccessNew);
      }
    } on NotionImportException catch (e) {
      if (mounted) _snack(l10n.importNotionError('$e'));
    } catch (e) {
      if (mounted) _snack(l10n.importNotionError('$e'));
    }
    if (!mounted) return;
    final warnings = _s.lastImportWarnings;
    if (warnings.isNotEmpty) {
      await _showImportWarningsDialog(warnings);
    }
  }

  Future<void> _showImportWarningsDialog(
    List<NotionImportWarning> warnings,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.importNotionWarningsTitle)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.importNotionWarningsBody),
                const SizedBox(height: 12),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(w.message)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _openWipeFlow() async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.wipeVaultDialogTitle),
        content: Text(l10n.wipeVaultDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    if (_s.vaultUsesEncryption) {
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => VaultIdentityVerifyDialog(
          session: _s,
          quickEnabled: _quickEnabled,
          passkeyRegistered: _passkeyRegistered,
          title: Text(l10n.confirmIdentity),
          body: Text(l10n.wipeIdentityBody),
          passwordButtonLabel: l10n.verifyAndDelete,
        ),
      );

      if (verified != true || !context.mounted) return;
    }

    try {
      await _s.wipeVaultAndReset();
      if (!context.mounted) return;
      if (_s.state == VaultFlowState.needsOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        });
      } else {
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!context.mounted) return;
      _snack(l10n.wipeFailedError('$e'));
    }
  }

  GitHubReleaseUpdater _buildUpdater() {
    return GitHubReleaseUpdater(
      owner: _app.updaterGithubOwner,
      repo: _app.updaterGithubRepo,
    );
  }

  Future<void> _checkUpdatesNow() async {
    if (_checkingUpdates) return;
    final l10n = AppLocalizations.of(context);
    _rebuild(() => _checkingUpdates = true);
    try {
      if (!FolioDistribution.offersGitHubSelfUpdate) {
        if (FolioDistribution.isMicrosoftStore) {
          if (defaultTargetPlatform != TargetPlatform.windows) {
            if (mounted) {
              _snack(l10n.updaterManualCheckUnsupportedPlatform);
            }
            return;
          }
          if (!FolioStoreListing.hasMicrosoftStoreListingProductId) {
            if (mounted) {
              _snack(l10n.updaterMicrosoftStoreListingMissing);
            }
            return;
          }
          final ok = await FolioStoreListing.openMicrosoftStoreProductPage();
          if (!mounted) return;
          if (!ok) {
            _snack(l10n.updaterStoreListingOpenFailed);
          }
          return;
        }
        if (FolioDistribution.isPlayStore) {
          if (defaultTargetPlatform != TargetPlatform.android) {
            if (mounted) {
              _snack(l10n.updaterManualCheckUnsupportedPlatform);
            }
            return;
          }
          final ok = await FolioStoreListing.openGooglePlayAppPage();
          if (!mounted) return;
          if (!ok) {
            _snack(l10n.updaterStoreListingOpenFailed);
          }
          return;
        }
        if (mounted) {
          _snack(l10n.updaterManualCheckUnsupportedPlatform);
        }
        return;
      }

      final updater = _buildUpdater();
      final result = await updater.checkForUpdate(
        channel: _app.updateReleaseChannel,
      );
      if (!mounted) return;
      if (!result.supportedPlatform) {
        _snack(l10n.updaterManualCheckUnsupportedPlatform);
        return;
      }
      if (!result.hasUpdate) {
        final r = result.reason;
        _snack(
          r != null && r.isNotEmpty ? r : l10n.updaterManualCheckAlreadyLatest,
        );
        return;
      }
      final betaNote = result.isPrerelease
          ? '\n\n${l10n.updaterStartupDialogBetaNote}'
          : '';
      final question = defaultTargetPlatform == TargetPlatform.android
          ? l10n.updaterOpenApkDownloadQuestion
          : l10n.updaterStartupDialogQuestion;
      final newVer = result.releaseVersion ?? result.currentVersion;
      final updateDialogIntro =
          '${l10n.updaterDialogLineCurrentVersion(result.currentVersion.toString())}\n'
          '${l10n.updaterDialogLineNewVersion(newVer.toString())}$betaNote';
      final go = await UpdateAvailableDialogContent.confirm(
        context: context,
        title: Text(
          result.isPrerelease
              ? l10n.updaterStartupDialogTitleBeta
              : l10n.updaterStartupDialogTitleStable,
        ),
        intro: updateDialogIntro,
        releaseNotes: result.releaseNotes,
        question: question,
        cancelLabel: l10n.updaterStartupDialogLater,
        confirmLabel: l10n.updaterStartupDialogUpdateNow,
      );
      if (go != true) return;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final raw = result.installerUrl ?? '';
        final uri = Uri.tryParse(raw);
        if (uri == null) {
          _snack(l10n.updaterApkUrlInvalidSnack);
          return;
        }
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          _snack(l10n.updaterApkOpenFailedSnack);
        }
        return;
      }
      _rebuild(() {
        _downloadingUpdate = true;
        _installingUpdate = false;
        _updateDownloadProgress = null;
      });
      final installer = await updater.downloadInstaller(
        result,
        onProgress: (p) {
          if (!mounted) return;
          _rebuild(() => _updateDownloadProgress = p);
        },
      );
      if (!mounted) return;
      _rebuild(() {
        _installingUpdate = true;
        _updateDownloadProgress = 1.0;
      });
      await updater.launchInstallerAndExit(installer);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.settingsUpdateFailed('$e'));
    } finally {
      if (mounted) {
        _rebuild(() {
          _checkingUpdates = false;
          _downloadingUpdate = false;
          _installingUpdate = false;
          _updateDownloadProgress = null;
        });
      }
    }
  }

  Future<void> _openReleaseNotesNow() async {
    if (_openingReleaseNotes) return;
    final l10nRn = AppLocalizations.of(context);
    _rebuild(() => _openingReleaseNotes = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final appVersion = info.version.trim();
      final buildNumber = info.buildNumber.trim();
      if (appVersion.isEmpty) {
        _snack(l10nRn.settingsCouldNotReadInstalledVersion);
        return;
      }
      final versionLabel = buildNumber.isEmpty
          ? appVersion
          : '$appVersion+$buildNumber';

      final updater = _buildUpdater();
      ReleaseNotesResult? release;
      try {
        release = await updater.fetchReleaseNotesForVersion(
          appVersion: appVersion,
          buildNumber: buildNumber,
        );
      } catch (_) {
        release = null;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            return ReleaseNotesPage(
              versionLabel: versionLabel,
              releaseTitle: release?.releaseName,
              releaseNotes: release?.releaseNotes ?? '',
              publishedAt: release?.publishedAt,
              tagName: release?.tagName,
            );
          },
          settings: const RouteSettings(name: 'release_notes_manual'),
        ),
      );
      await _app.setLastSeenReleaseNotesVersion(versionLabel);
    } catch (e) {
      if (!mounted) return;
      _snack(l10nRn.settingsCouldNotOpenReleaseNotes('$e'));
    } finally {
      if (mounted) _rebuild(() => _openingReleaseNotes = false);
    }
  }

  Future<void> _openChangeMasterPasswordFlow() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangeMasterPasswordDialog(session: _s),
    );
    if (changed == true && mounted) {
      _snack(AppLocalizations.of(context).masterPasswordUpdatedSnack);
    }
  }

  String _getSectionTitle(AppLocalizations l10n, _SettingsSectionId sectionId) {
    switch (sectionId) {
      case _SettingsSectionId.cloud:
        return l10n.cloudAccountSectionTitle;
      case _SettingsSectionId.vault:
        return l10n.settingsSectionVault;
      case _SettingsSectionId.uiWorkspace:
        return l10n.settingsSectionUiWorkspace;
      case _SettingsSectionId.ai:
        return l10n.ai;
      case _SettingsSectionId.sync:
        return l10n.settingsSectionDeviceSyncNav;
      case _SettingsSectionId.about:
        return l10n.about;
      case _SettingsSectionId.integrations:
        return l10n.integrations;
    }
  }

  Future<void> _showEditQuillPromptDialog(QuillSystemPrompt? item, {bool readOnly = false}) async {
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final promptCtrl = TextEditingController(text: item?.prompt ?? '');
    final isNew = item == null;

    final titleText = isNew
        ? (isEs ? 'Crear instrucciones' : 'Create Instructions')
        : (readOnly
            ? (isEs ? 'Ver instrucciones' : 'View Instructions')
            : (isEs ? 'Editar instrucciones' : 'Edit Instructions'));

    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(titleText),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!readOnly) ...[
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isEs ? 'Nombre' : 'Name',
                    hintText: isEs ? 'Ej. Escritor de Poesía' : 'E.g. Poetry Writer',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: promptCtrl,
                maxLines: 8,
                minLines: 3,
                readOnly: readOnly,
                decoration: InputDecoration(
                  labelText: isEs ? 'Instrucciones del sistema' : 'System Instructions',
                  hintText: isEs
                      ? 'Ej. Eres un experto tutor de inglés...'
                      : 'E.g. You are an expert English tutor...',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(readOnly ? (isEs ? 'Atrás' : 'Back') : (isEs ? 'Cancelar' : 'Cancel')),
          ),
          if (!readOnly)
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final promptText = promptCtrl.text.trim();
                if (name.isEmpty || promptText.isEmpty) return;
                if (isNew) {
                  final newPrompt = QuillSystemPrompt(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    prompt: promptText,
                    isSystemDefault: false,
                  );
                  await _app.addQuillSystemPrompt(newPrompt);
                } else {
                  final updated = item.copyWith(name: name, prompt: promptText);
                  await _app.updateQuillSystemPrompt(updated);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _rebuild(() {});
              },
              child: Text(isEs ? 'Guardar' : 'Save'),
            ),
        ],
      ),
    );
  }



  List<Widget> _buildSearchResults(BuildContext context, String query, AppLocalizations l10n, ColorScheme scheme) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];

    final isEs = l10n.localeName == 'es';

    final List<_SearchItem> items = [
      _SearchItem(
        category: _SettingsSectionId.uiWorkspace,
        title: l10n.settingsSearchThemeTitle,
        description: l10n.settingsSearchThemeDesc,
        keywords: isEs
            ? [
                'tema',
                'apariencia',
                'claro',
                'oscuro',
                'oled',
                'negro',
                'diseño',
                'color',
              ]
            : [
                'theme',
                'dark',
                'light',
                'oled',
                'black',
                'appearance',
                'color',
              ],
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<FolioThemeMode>(
              segments: [
                ButtonSegment<FolioThemeMode>(
                  value: FolioThemeMode.system,
                  label: Text(l10n.systemTheme),
                  icon: const Icon(Icons.brightness_auto, size: 18),
                ),
                ButtonSegment<FolioThemeMode>(
                  value: FolioThemeMode.light,
                  label: Text(l10n.lightTheme),
                  icon: const Icon(Icons.light_mode_outlined, size: 18),
                ),
                ButtonSegment<FolioThemeMode>(
                  value: FolioThemeMode.dark,
                  label: Text(l10n.darkTheme),
                  icon: const Icon(Icons.dark_mode_outlined, size: 18),
                ),
                ButtonSegment<FolioThemeMode>(
                  value: FolioThemeMode.oled,
                  label: Text(l10n.oledTheme),
                  icon: const Icon(Icons.contrast, size: 18),
                ),
              ],
              selected: {_app.themeMode},
              onSelectionChanged: (s) {
                _rebuild(() {
                  _app.setThemeMode(s.first);
                });
              },
            ),
          ],
        ),
      ),
      _SearchItem(
        category: _SettingsSectionId.uiWorkspace,
        title: l10n.settingsSearchLangTitle,
        description: l10n.settingsSearchLangDesc,
        keywords: isEs
            ? ['idioma', 'lenguaje', 'español', 'inglés']
            : ['language', 'spanish', 'english', 'lang'],
        builder: (context) => SegmentedButton<String?>(
          segments: [
            ButtonSegment<String?>(
              value: null,
              label: Text(l10n.useSystemLanguage),
            ),
            ButtonSegment<String?>(
              value: 'es',
              label: Text(l10n.spanishLanguage),
            ),
            ButtonSegment<String?>(
              value: 'en',
              label: Text(l10n.englishLanguage),
            ),
          ],
          selected: {_app.locale?.languageCode},
          onSelectionChanged: (s) {
            _rebuild(() {
              final code = s.first;
              _app.setLocale(code == null ? null : Locale(code));
            });
          },
        ),
      ),
      _SearchItem(
        category: _SettingsSectionId.ai,
        title: l10n.settingsSearchAiTitle,
        description: l10n.settingsSearchAiDesc,
        keywords: isEs
            ? ['ia', 'ai', 'proveedor', 'modelos', 'inteligencia']
            : ['ia', 'ai', 'provider', 'models', 'intelligence'],
        builder: (context) => SwitchListTile(
          title: Text(l10n.settingsSearchAiTitle),
          value: _app.aiEnabled,
          onChanged: (value) {
            _rebuild(() {
              _app.setAiEnabled(value);
            });
          },
        ),
      ),
      _SearchItem(
        category: _SettingsSectionId.vault,
        title: l10n.settingsSearchQuickUnlockTitle,
        description: l10n.settingsSearchQuickUnlockDesc,
        keywords: isEs
            ? ['desbloqueo', 'biometria', 'huella', 'rostro', 'seguridad']
            : ['unlock', 'biometrics', 'fingerprint', 'face', 'security'],
        builder: (context) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_quickEnabled ? l10n.active : l10n.inactive),
            _quickEnabled
                ? TextButton(
                    onPressed: () async {
                      await _s.disableQuickUnlock();
                      await _refreshSecurityFlags();
                      _snack(l10n.quickUnlockDisabledSnack);
                    },
                    child: Text(l10n.remove),
                  )
                : FilledButton.tonal(
                    onPressed: () async {
                      try {
                        await _s.enableDeviceQuickUnlock();
                        await _refreshSecurityFlags();
                        _snack(l10n.quickUnlockEnabledSnack);
                      } catch (e) {
                        _snack(isEs ? 'Error al habilitar' : 'Enable failed');
                      }
                    },
                    child: Text(isEs ? 'Configurar' : 'Configure'),
                  ),
          ],
        ),
      ),
      _SearchItem(
        category: _SettingsSectionId.vault,
        title: l10n.settingsSearchCloudBackupTitle,
        description: l10n.settingsSearchCloudBackupDesc,
        keywords: isEs
            ? ['copia', 'nube', 'backup', 'sincronizacion', 'guardar']
            : ['copy', 'cloud', 'backup', 'sync', 'save'],
        builder: (context) => SwitchListTile(
          title: Text(l10n.settingsSearchCloudBackupTitle),
          value: _vaultBackupPrefs.enabled,
          onChanged: _vaultId == null
              ? null
              : (value) async {
                  await _app.setVaultBackupEnabled(_vaultId, value);
                  await _loadVaultBackupPrefs();
                },
        ),
      ),
      _SearchItem(
        category: _SettingsSectionId.integrations,
        title: l10n.settingsSearchJiraTitle,
        description: l10n.settingsSearchJiraDesc,
        keywords: isEs
            ? ['jira', 'tareas', 'sincronizar', 'proyectos', 'tickets']
            : ['jira', 'tasks', 'sync', 'projects', 'tickets'],
        builder: (context) => ListTile(
          title: Text(l10n.settingsSearchJiraTitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            _rebuild(() {
              _selectedMobileSection = _SettingsSectionId.integrations;
            });
          },
        ),
      ),
      _SearchItem(
        category: _SettingsSectionId.integrations,
        title: l10n.settingsSearchYouTrackTitle,
        description: l10n.settingsSearchYouTrackDesc,
        keywords: isEs
            ? ['youtrack', 'bugs', 'tareas', 'tickets']
            : ['youtrack', 'bugs', 'tasks', 'tickets'],
        builder: (context) => ListTile(
          title: Text(l10n.settingsSearchYouTrackTitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            _rebuild(() {
              _selectedMobileSection = _SettingsSectionId.integrations;
            });
          },
        ),
      ),
    ];

    final matches = items.where((item) {
      return item.title.toLowerCase().contains(cleanQuery) ||
          item.description.toLowerCase().contains(cleanQuery) ||
          item.keywords.any((kw) => kw.toLowerCase().contains(cleanQuery));
    }).toList();

    if (matches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.settingsSearchNoResults,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          l10n.settingsSearchResultsTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
        ),
      ),
      ...matches.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SettingsPanel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getSectionTitle(l10n, item.category),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  item.builder(context),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }

}
