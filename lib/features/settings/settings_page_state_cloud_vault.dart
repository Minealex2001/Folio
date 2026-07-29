part of 'settings_page.dart';

extension _SettingsPageCloudVaultActions on _SettingsPageState {
  Future<void> _showCloudAuthDialog({required bool register}) async {
    final l10n = AppLocalizations.of(context);
    AppLogger.info(
      'cloud auth dialog',
      tag: 'settings',
      context: {'register': register},
    );
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final ok = await folioGoogleApisReachable();
      if (!ok) {
        if (!mounted) return;
        _snack(l10n.cloudAuthErrorNetwork);
        return;
      }
    }
    if (!mounted) return;
    final accountPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => _CloudAuthDialog(
        initialRegister: register,
        l10n: l10n,
        cloudAuthController: _cloud,
        onAuthError: (code) => _cloudAuthErrorMessage(l10n, code),
        onForgotPassword: () {
          Navigator.of(ctx).pop();
          Future.microtask(() {
            unawaited(_showCloudPasswordResetDialog());
          });
        },
      ),
    );
    if (!mounted) return;
    if (accountPassword == null || accountPassword.isEmpty) {
      AppLogger.debug('cloud auth dialog cancelled', tag: 'settings');
      return;
    }
    if (!_cloud.isSignedIn) return;

    AppLogger.info(
      'cloud auth ok → import all vaults',
      tag: 'settings',
      context: {'uid': _cloud.uid},
    );
    await showFolioCloudImportAllVaultsFlow(
      context: context,
      session: _s,
      entitlements: _folio,
      accountPassword: accountPassword,
      telemetrySettings: _app,
    );
  }

  Future<void> _showCloudPasswordResetDialog({String? fixedEmail}) async {
    if (!_cloud.isAvailable) return;
    final l10n = AppLocalizations.of(context);
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final ok = await folioGoogleApisReachable();
      if (!ok) {
        if (!mounted) return;
        _snack(l10n.cloudAuthErrorNetwork);
        return;
      }
    }
    if (!mounted) return;
    final email = await showDialog<String?>(
      context: context,
      builder: (ctx) =>
          _CloudPasswordResetDialog(l10n: l10n, fixedEmail: fixedEmail),
    );
    if (email == null || email.isEmpty) return;
    try {
      await _cloud.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cloudPasswordResetSent)));
    } on FolioAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cloudAuthErrorMessage(l10n, e.code))),
      );
    }
  }

  Future<void> _sendCloudEmailVerification() async {
    if (!_cloud.isAvailable || !_cloud.isSignedIn) return;
    final l10n = AppLocalizations.of(context);
    try {
      await _cloud.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cloudAccountVerificationSent)),
      );
    } on FolioAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cloudAuthErrorMessage(l10n, e.code))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reloadCloudUserVerificationStatus() async {
    if (!_cloud.isAvailable || !_cloud.isSignedIn) return;
    final l10n = AppLocalizations.of(context);
    try {
      await _cloud.reloadCurrentUser();
      if (!mounted) return;
      final verified = _cloud.emailVerified;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? l10n.cloudAccountVerificationNowVerified
                : l10n.cloudAccountVerificationStillPending,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editSyncDeviceName() async {
    var draft = _app.syncDeviceName;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final l10nD = AppLocalizations.of(ctx);
        return FolioDialog(
          title: Text(l10nD.settingsDeviceNameTitle),
          content: TextFormField(
            initialValue: draft,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              hintText: l10nD.settingsDeviceNameHintExample,
            ),
            onChanged: (v) => draft = v,
            onFieldSubmitted: (_) => Navigator.of(ctx).pop(draft.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(draft.trim()),
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    await _app.setSyncDeviceName(result);
  }

  void _activateEmojiPairingMode() {
    if (!_app.syncEnabled) return;
    _sync.generatePairingCode();
    _snack(AppLocalizations.of(context).settingsPairingModeEnabledTwoMin);
  }

  Future<void> _submitPairingCodeDialog({SyncPeer? peer}) async {
    final targetPeer = peer;
    if (targetPeer == null) {
      _snack(AppLocalizations.of(context).settingsPairingEnableModeFirst);
      return;
    }
    final l10nLink = AppLocalizations.of(context);
    final idOk = await _verifyVaultIdentity(
      title: Text(l10nLink.vaultIdentitySyncTitle),
      body: Text(l10nLink.vaultIdentitySyncBody),
    );
    if (!idOk || !mounted) return;
    if (!_sync.isPairingModeActive) {
      _sync.generatePairingCode();
    }
    final sharedEmojis = await _sync.sharedPairingEmojisForPeer(targetPeer);
    if (!mounted) return;
    if (sharedEmojis.isEmpty) {
      _snack(AppLocalizations.of(context).settingsPairingSameEmojisBothDevices);
      return;
    }
    final started = await _sync.submitEmojiPairingRequest(targetPeer);
    if (!started) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).settingsPairingCouldNotStart);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10nP = AppLocalizations.of(ctx);
        return FolioDialog(
          title: Text(l10nP.settingsConfirmPairingTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10nP.settingsPairingCheckOtherDeviceEmojis),
              const SizedBox(height: 12),
              SelectableText(
                sharedEmojis.join(' '),
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10nP.settingsPairingPopupInstructions),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _sync.cancelOutgoingPair(targetPeer.peerId);
                Navigator.of(ctx).pop(false);
              },
              child: Text(AppLocalizations.of(ctx).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10nP.settingsLinkDevice),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _sync.confirmOutgoingPair(targetPeer.peerId);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).settingsPairingConfirmationSent);
  }

  Future<void> _revokeSyncPeer(SyncPeer peer) async {
    final l10nRev = AppLocalizations.of(context);
    final ok = await _verifyVaultIdentity(
      title: Text(l10nRev.vaultIdentitySyncTitle),
      body: Text(l10nRev.vaultIdentitySyncBody),
    );
    if (!ok || !mounted) return;
    await _sync.revokePeer(peer.peerId);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).settingsDeviceRevokedSnack);
  }

  Future<void> _showSyncConflictsDialog() async {
    if (!mounted) return;
    await showSyncConflictMergeSheet(
      context: context,
      session: _s,
      onOpenPage: (pageId) {
        _s.selectPage(pageId);
        if (mounted) Navigator.of(context).maybePop();
      },
    );
  }

  Future<void> _importCustomIconFromSource(String source) async {
    final raw = source.trim();
    if (raw.isEmpty || _importingCustomIcon) return;
    final l10n = AppLocalizations.of(context);
    _rebuild(() => _importingCustomIcon = true);
    try {
      final entry = await _customIconImportService.importFromSource(
        l10n: l10n,
        source: raw,
        label: _customIconLabelController.text,
      );
      await _app.addOrUpdateCustomIcon(entry);
      if (!mounted) return;
      _customIconSourceController.clear();
      _customIconLabelController.clear();
      _snack(l10n.customIconImportSucceeded);
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _importingCustomIcon = false);
    }
  }

  Future<void> _importCustomIconFromClipboard() async {
    final l10n = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _snack(l10n.customIconClipboardEmpty);
      return;
    }
    _customIconSourceController.text = text;
    await _importCustomIconFromSource(text);
  }

  Future<void> _removeCustomIcon(CustomIconEntry entry) async {
    await _app.removeCustomIcon(entry.id);
    try {
      await _customIconImportService.deleteIconBytes(entry.filePath);
    } catch (_) {
      // Ignorar: la referencia ya se eliminó de ajustes.
    }
    if (!mounted) return;
    _snack(AppLocalizations.of(context).customIconRemoved);
  }

  Future<bool> _vaultRequiresPassword(String vaultId) async {
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    final modePath = File(p.join(dir.path, VaultPaths.vaultModeFile));
    if (!modePath.existsSync()) return true;
    final raw = await modePath.readAsString();
    return raw.trim().toLowerCase() != 'plain';
  }

  Future<bool> _verifyVaultPasswordForDelete(String vaultId) async {
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final keysPath = File(p.join(dir.path, VaultPaths.wrappedDekFile));
    if (!keysPath.existsSync()) return true;

    final controller = TextEditingController();
    var obscure = true;
    String? password;
    while (mounted) {
      if (!mounted) break;
      password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => FolioDialog(
            title: Text(l10n.confirmIdentity),
            content: FolioPasswordField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              labelText: l10n.currentPasswordLabel,
              showPasswordTooltip: l10n.showPassword,
              hidePasswordTooltip: l10n.hidePassword,
              onToggleObscure: () {
                setDialogState(() => obscure = !obscure);
              },
              onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(l10n.verifyAndDelete),
              ),
            ],
          ),
        ),
      );
      if (password == null) {
        controller.dispose();
        return false;
      }
      if (password.trim().isEmpty) {
        _snack(l10n.incorrectPasswordError);
        continue;
      }
      try {
        final wrapped = await keysPath.readAsBytes();
        await VaultCrypto.unwrapDek(
          wrapped: wrapped,
          password: password.trim(),
        );
        controller.dispose();
        return true;
      } catch (_) {
        _snack(l10n.incorrectPasswordError);
      }
    }
    controller.dispose();
    return false;
  }

  Future<void> _deleteOtherVault() async {
    final l10n = AppLocalizations.of(context);
    final active = _s.activeVaultId;
    final vaults = await _s.listVaultEntries();
    if (!mounted) return;
    final others = vaults.where((e) => e.id != active).toList(growable: false);
    if (others.isEmpty) {
      _snack(l10n.noOtherVaultsSnack);
      return;
    }

    VaultEntry? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.deleteOtherVaultTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: others
                .map(
                  (e) => ListTile(
                    title: Text(e.displayName),
                    subtitle: Text(
                      e.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      picked = e;
                      Navigator.pop(ctx);
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final target = picked!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.deleteVaultConfirmTitle),
        content: Text(l10n.deleteVaultConfirmBody(target.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final requiresPassword = await _vaultRequiresPassword(target.id);
    if (!mounted) return;
    if (requiresPassword) {
      final verified = await _verifyVaultPasswordForDelete(target.id);
      if (!verified || !mounted) return;
    }

    try {
      await _s.deleteVaultById(target.id);
      if (!mounted) return;
      _snack(l10n.vaultDeletedSnack);
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    }
  }

  Future<void> _openEncryptPlainVaultDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EncryptPlainVaultDialog(session: _s),
    );
    if (ok != true || !mounted) return;
    await _refreshSecurityFlags();
    if (!mounted) return;
    _snack(AppLocalizations.of(context).encryptPlainVaultSuccessSnack);
  }

}
