part of 'settings_page.dart';

extension _SettingsPageBackupSecurityActions on _SettingsPageState {
  Future<void> _loadMeetingNoteDevices() async {
    try {
      final micDevices = await _meetingNoteDeviceProbe.listInputDevices();
      final systemDevices = await SystemAudioService.instance
          .listOutputDevices();
      if (!mounted) return;
      _rebuild(() {
        _meetingNoteMicDevices = micDevices;
        _meetingNoteSystemDevices = systemDevices;
      });
    } catch (_) {
      // Si falla la enumeracion, mantenemos la UI estable con listas vacias.
      if (!mounted) return;
      _rebuild(() {
        _meetingNoteMicDevices = const [];
        _meetingNoteSystemDevices = const [];
      });
    }
  }

  bool _meetingMicExists(String id) {
    for (final d in _meetingNoteMicDevices) {
      if (d.id == id) return true;
    }
    return false;
  }

  bool _meetingSystemExists(String id) {
    for (final d in _meetingNoteSystemDevices) {
      if (d.id == id) return true;
    }
    return false;
  }

  bool _meetingModelExists(String id) {
    for (final m in WhisperService.supportedModels) {
      if (m.id == id) return true;
    }
    return false;
  }

  /// Evita [value] duplicado con el ítem '' (predeterminado) o ids repetidos del SO.
  List<DropdownMenuItem<String>> _meetingMicDropdownItems(
    AppLocalizations l10n,
  ) {
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: '',
        child: Text(l10n.meetingNoteSettingsSystemDefault),
      ),
    ];
    final seen = <String>{''};
    for (final d in _meetingNoteMicDevices) {
      final id = d.id;
      if (id.isEmpty || !seen.add(id)) continue;
      items.add(
        DropdownMenuItem<String>(
          value: id,
          child: Text(
            d.label.trim().isEmpty ? id : d.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return items;
  }

  List<DropdownMenuItem<String>> _meetingSystemDropdownItems(
    AppLocalizations l10n,
  ) {
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: '',
        child: Text(l10n.meetingNoteSettingsSystemDefault),
      ),
    ];
    final seen = <String>{''};
    for (final d in _meetingNoteSystemDevices) {
      final id = d.id;
      if (id.isEmpty || !seen.add(id)) continue;
      items.add(
        DropdownMenuItem<String>(
          value: id,
          child: Text(
            d.label.trim().isEmpty ? id : d.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return items;
  }

  String _meetingModelLabel(AppLocalizations l10n, String id) {
    return switch (id) {
      'tiny' => l10n.meetingNoteModelTiny,
      'small' => l10n.meetingNoteModelSmall,
      'medium' => l10n.meetingNoteModelMedium,
      'turbo' => l10n.meetingNoteModelTurbo,
      _ => l10n.meetingNoteModelBase,
    };
  }





  List<_SettingsSectionNavItem> _filterDesktopSections(
    List<_SettingsSectionNavItem> all,
  ) {
    final q = _settingsSectionFilterController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) {
          if (s.label.toLowerCase().contains(q)) return true;
          for (final extra in s.searchExtra) {
            if (extra.toLowerCase().contains(q)) return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  String _scheduledVaultBackupIntervalSummary(
    AppLocalizations l10n,
    int minutes,
  ) {
    if (AppSettings.isContinuousVaultBackupInterval(minutes)) {
      return l10n.scheduledVaultBackupEveryChange;
    }
    if (minutes < 60) {
      return l10n.scheduledVaultBackupEveryNMinutes(minutes);
    }
    return l10n.scheduledVaultBackupEveryNHours(minutes ~/ 60);
  }

  String _formatScheduledBackupTime(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = d.year.toString().padLeft(4, '0');
    final mo = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$y-$mo-$day $h:$mi';
  }

  String _formatByteSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 100 ? 1 : 2)} GB';
  }

  Future<int> _loadActiveVaultDiskUsageBytes() async {
    final dir = await VaultPaths.vaultDirectory();
    return VaultPaths.directoryTotalFileBytes(dir);
  }

  Future<void> _pickScheduledVaultBackupFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;
    await _app.setVaultBackupDirectory(_vaultId, path);
    await _loadVaultBackupPrefs();
  }

  Future<void> _enterNetworkBackupPath() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: _vaultBackupPrefs.directory);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.remoteBackupEnterNetworkPath),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: l10n.remoteBackupNetworkPathLabel,
            hintText: l10n.remoteBackupNetworkPathHint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.remoteBackupSave),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await _app.setVaultBackupDirectory(_vaultId, result);
    await _loadVaultBackupPrefs();
  }

  Future<void> _openRemoteBackupConfig({int initialTab = 0}) async {
    if (_vaultId == null) return;
    final updated = await RemoteBackupConfigDialog.show(
      context,
      l10n: AppLocalizations.of(context),
      initialPrefs: _vaultBackupPrefs,
      vaultId: _vaultId!,
      credentials: _backupCredentials,
      initialTab: initialTab,
    );
    if (updated == null || !mounted) return;
    await _app.updateVaultBackupPrefs(_vaultId, updated);
    await _loadVaultBackupPrefs();
  }

  Future<void> _openRemoteBackupRestore() async {
    if (_vaultId == null) return;
    final l10n = AppLocalizations.of(context);
    if (!_vaultBackupPrefs.hasConfiguredNetworkDestination) {
      final updated = await RemoteBackupConfigDialog.show(
        context,
        l10n: l10n,
        initialPrefs: _vaultBackupPrefs,
        vaultId: _vaultId!,
        credentials: _backupCredentials,
      );
      if (updated == null || !mounted) return;
      await _app.updateVaultBackupPrefs(_vaultId, updated);
      await _loadVaultBackupPrefs();
      if (!_vaultBackupPrefs.hasConfiguredNetworkDestination) return;
    }
    if (!mounted) return;
    await RemoteBackupRestoreDialog.show(
      context,
      l10n: l10n,
      session: _s,
      prefs: _vaultBackupPrefs,
      vaultId: _vaultId!,
      credentials: _backupCredentials,
    );
  }







  Future<void> _refreshSecurityFlags() async {
    final q = await _s.quickUnlockEnabled;
    final p = await _s.hasPasskey;
    if (mounted) {
      _rebuild(() {
        _quickEnabled = q;
        _passkeyRegistered = p;
      });
    }
  }

  Future<void> _loadInstalledVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      _rebuild(() {
        _installedVersionLabel = info.version;
      });
      await _refreshReleaseReadiness();
    } catch (_) {
      if (!mounted) return;
      _rebuild(() {
        _installedVersionLabel = 'desconocida';
      });
      await _refreshReleaseReadiness();
    }
  }

  Future<void> _reportBugFlow() async {
    final l10n = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    try {
      final send = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return FolioDialog(
            title: Text(l10n.settingsReportBugDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.settingsReportBugDialogBody),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.settingsReportBugNoteLabel,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.settingsReportBugSend),
              ),
            ],
          );
        },
      );
      if (send != true || !mounted) return;
      final ok = await FolioDiagnosticReporter.submit(
        kind: 'manual',
        userNote: noteCtrl.text,
        settings: _app,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? l10n.settingsReportBugSentOk : l10n.settingsReportBugSentFail,
          ),
        ),
      );
      final uri = Uri.parse(kFolioBugReportUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _refreshReleaseReadiness() async {
    final vaultId = _s.activeVaultId;
    var vaultPath = '-';
    try {
      final dir = await VaultPaths.vaultDirectory();
      vaultPath = dir.path;
    } catch (_) {
      vaultPath = '-';
    }

    evaluateReleaseReadiness(
      l10n: lookupAppLocalizations(_app.locale ?? const Locale('es')),
      installedVersionLabel: _installedVersionLabel,
      updateReleaseChannel: _app.updateReleaseChannel,
      activeVaultId: vaultId,
      activeVaultPath: vaultPath,
      isVaultUnlocked: _s.state == VaultFlowState.unlocked,
      isVaultEncrypted: _s.vaultUsesEncryption,
      isAiEnabled: _app.aiEnabled,
      aiProvider: _app.aiProvider,
      aiBaseUrl: _app.aiBaseUrl,
      aiEndpointMode: _app.aiEndpointMode,
      aiRemoteEndpointConfirmed: _app.aiRemoteEndpointConfirmed,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _verifyVaultIdentity({
    required Widget title,
    required Widget body,
    String? passwordButtonLabel,
  }) async {
    if (_s.state != VaultFlowState.unlocked) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: title,
        body: body,
        passwordButtonLabel: passwordButtonLabel ?? l10n.verifyAndContinue,
      ),
    );
    return result == true;
  }

  /// Descarga de copias desde Storage: reautenticación con **cuenta Folio Cloud**, no libreta local.
  /// El listado y el contador en ajustes no pasan por aquí.
  Future<bool> _verifyFolioCloudAccountForBackups() async {
    if (!_cloud.isAvailable || !_cloud.isSignedIn) {
      _snack(AppLocalizations.of(context).settingsSignInFolioCloudSnack);
      return false;
    }
    if (!_cloud.canReauthenticateWithPassword) {
      _snack(
        AppLocalizations.of(context).folioCloudReauthRequiresPasswordProvider,
      );
      return false;
    }
    final l10n = AppLocalizations.of(context);
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FolioCloudReauthDialog(
        l10n: l10n,
        cloud: _cloud,
        onAuthError: (code) => _cloudAuthErrorMessage(l10n, code),
        initialEmail: _cloud.email,
      ),
    );
    return password != null && password.isNotEmpty;
  }

  Future<void> _runBackupNowToScheduledFolder() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final canCloud =
        _folio.isAvailable &&
        _cloud.isSignedIn &&
        _folio.snapshot.canUseCloudBackup;
    final wantFolder = _vaultBackupPrefs.hasFolderDestination;
    final wantWebdav = _vaultBackupPrefs.hasWebDavDestination;
    final wantNetwork = wantFolder || wantWebdav;
    final wantCloud = _vaultBackupPrefs.alsoCloud && canCloud;
    if (!wantNetwork && !wantCloud) {
      _snack(l10n.vaultBackupRunNowNeedDestination);
      return;
    }
    if (wantCloud && !_folio.snapshot.canUseCloudBackup) {
      _snack(l10n.settingsCloudBackupEnablePlanSnack);
      return;
    }
    if (!mounted) return;
    try {
      await showVaultBackupProgressDialog(
        context: context,
        l10n: l10n,
        work: (ctrl) async {
          if (wantNetwork) {
            ctrl.setProgress(0, indeterminate: true);
            VaultBackupProgressController.logConsole(
              l10n.vaultBackupProgressNetworkStart,
            );
            if (_vaultId == null) return;
            await BackupExportRunner(credentials: _backupCredentials)
                .exportToDestinations(
              session: _s,
              prefs: _vaultBackupPrefs,
              vaultId: _vaultId!,
            );
            ctrl.setProgress(0.15, indeterminate: false);
            VaultBackupProgressController.logConsole(
              l10n.vaultBackupProgressNetworkDone,
            );
          }
          if (wantCloud) {
            final cloudOk = await _uploadFolioCloudBackup(
              suppressSuccessSnack: true,
              progress: ctrl,
              cloudProgressMin: wantNetwork ? 0.15 : 0.0,
              cloudProgressMax: 1.0,
              manageBusyState: false,
            );
            if (!cloudOk) return;
          }
          await _app.setVaultBackupLastMs(
            _vaultId,
            DateTime.now().millisecondsSinceEpoch,
          );
          if (mounted) {
            if (wantCloud && wantFolder) {
              _snack(l10n.scheduledVaultBackupSnackOk);
            } else if (wantCloud) {
              _snack(l10n.folioCloudUploadSnackOk);
            } else {
              _snack(l10n.scheduledVaultBackupSnackOk);
            }
            await _loadVaultBackupPrefs();
          }
        },
      );
    } on VaultBackupException catch (e) {
      if (mounted) _snack('$e');
    } catch (e) {
      if (mounted) _snack(l10n.scheduledVaultBackupSnackFail('$e'));
    }
  }

  Future<void> _revokeIntegrationApp(String appId) async {
    await _app.revokeIntegrationApp(appId);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).settingsAppRevoked(appId));
  }

  String _formatLastSyncLabel() {
    final ms = _app.syncLastSuccessMs;
    if (ms <= 0) {
      return AppLocalizations.of(context).settingsNotSyncedYet;
    }
    final at = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
  }

  String _shortCloudUid(String uid) {
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 8)}…${uid.substring(uid.length - 4)}';
  }

  String _cloudAuthErrorMessage(AppLocalizations l10n, String code) {
    switch (code) {
      case 'invalid-email':
        return l10n.cloudAuthErrorInvalidEmail;
      case 'wrong-password':
        return l10n.cloudAuthErrorWrongPassword;
      case 'user-not-found':
        return l10n.cloudAuthErrorUserNotFound;
      case 'user-disabled':
        return l10n.cloudAuthErrorUserDisabled;
      case 'email-already-in-use':
        return l10n.cloudAuthErrorEmailAlreadyInUse;
      case 'weak-password':
        return l10n.cloudAuthErrorWeakPassword;
      case 'invalid-credential':
        return l10n.cloudAuthErrorInvalidCredential;
      case 'password-reset-required':
        return l10n.cloudAuthErrorPasswordResetRequired;
      case 'invalid-token':
        return l10n.cloudAuthErrorInvalidToken;
      case 'token-expired':
        return l10n.cloudAuthErrorTokenExpired;
      case 'token-used':
        return l10n.cloudAuthErrorTokenUsed;
      case 'already-verified':
        return l10n.cloudAccountVerificationNowVerified;
      case 'network-request-failed':
        return l10n.cloudAuthErrorNetwork;
      case 'too-many-requests':
        return l10n.cloudAuthErrorTooManyRequests;
      case 'operation-not-allowed':
        return l10n.cloudAuthErrorOperationNotAllowed;
      default:
        return l10n.cloudAuthErrorGeneric;
    }
  }

}
