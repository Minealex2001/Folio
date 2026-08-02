part of 'settings_page.dart';

extension _SettingsPageFolioCloudActions on _SettingsPageState {
  Future<void> _syncFolioCloudBilling() async {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      await _folio.refreshFolioCloudBillingFromServers();
      if (!mounted) return;
      _snack(l10n.settingsStripeSubscriptionRefreshed);
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _openFolioBillingPortal() async {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      final uri = await createBillingPortalUri();
      if (uri == null) {
        _snack(l10n.settingsStripeBillingPortalUnavailable);
        return;
      }
      if (FolioInAppCheckoutDialog.isSupported) {
        if (!mounted) return;
        await showDialog<bool>(
          context: context,
          builder: (ctx) => FolioInAppCheckoutDialog(
            url: uri.toString(),
            scheme: Theme.of(context).colorScheme,
          ),
        );
        if (mounted) {
          await _folio.refreshFolioCloudBillingFromServers(retryUntilActive: true);
        }
      } else {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          _snack(l10n.settingsCouldNotOpenLink);
        }
      }
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  String _l10nFolioWebPortalError(
    AppLocalizations l10n,
    FolioWebPortalException e,
  ) {
    final d = e.detail?.trim();
    switch (e.kind) {
      case FolioWebPortalErrorKind.network:
      case FolioWebPortalErrorKind.invalidBaseUrl:
        return l10n.folioWebPortalErrorNetwork;
      case FolioWebPortalErrorKind.timeout:
        return l10n.folioWebPortalErrorTimeout;
      case FolioWebPortalErrorKind.adminNotConfigured:
        return l10n.folioWebPortalErrorAdminNotConfigured;
      case FolioWebPortalErrorKind.unauthorized:
        return l10n.folioWebPortalErrorUnauthorized;
      case FolioWebPortalErrorKind.forbidden:
      case FolioWebPortalErrorKind.notFound:
      case FolioWebPortalErrorKind.conflict:
      case FolioWebPortalErrorKind.badRequest:
      case FolioWebPortalErrorKind.linkRejected:
      case FolioWebPortalErrorKind.serverError:
      case FolioWebPortalErrorKind.invalidJson:
      case FolioWebPortalErrorKind.entitlementParse:
        if (d != null && d.isNotEmpty) {
          return l10n.folioWebPortalServerMessage(d);
        }
        return l10n.folioWebPortalErrorGeneric;
    }
  }

  Future<void> _linkFolioWebPortalAccount() async {
    if (!AppSettings.folioWebPortalLinkEnabled) return;
    if (_webLinkBusy) return;
    final l10n = AppLocalizations.of(context);
    final user = null;
    if (user == null) {
      _snack(l10n.folioWebPortalNeedSignIn);
      return;
    }
    final base = _app.folioWebPortalBaseUrlEffective;
    _rebuild(() => _webLinkBusy = true);
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        if (mounted) _snack(l10n.folioWebPortalErrorUnauthorized);
        return;
      }
      await linkFolioWebAccount(
        portalBaseUrl: base,
        linkCode: _webLinkCodeController.text,
        idToken: token,
      );
      if (!mounted) return;
      _webLinkCodeController.clear();
      _snack(l10n.folioWebPortalLinkSuccess);
      await _folio.refreshWebPortalEntitlement();
    } on FolioWebPortalException catch (e) {
      if (mounted) {
        _snack(_l10nFolioWebPortalError(l10n, e));
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _webLinkBusy = false);
    }
  }

  Future<void> _refreshFolioWebPortalEntitlement() async {
    if (!AppSettings.folioWebPortalLinkEnabled) return;
    await _folio.refreshWebPortalEntitlement();
    if (!mounted) return;
    final err = _folio.webPortalRefreshError;
    if (err != null) {
      _snack(_l10nFolioWebPortalError(AppLocalizations.of(context), err));
    }
  }

  Future<void> _showFolioWebPortalLinkDialog() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return ListenableBuilder(
              listenable: _folio,
              builder: (context, _) {
                final scheme = Theme.of(context).colorScheme;
                final webSnap = _folio.webPortalEntitlement;
                return FolioDialog(
                  title: Text(l10n.folioWebPortalSubsectionTitle),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.folioWebMirrorNote,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.folioWebPortalLinkHelp,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _webLinkCodeController,
                          decoration: InputDecoration(
                            labelText: l10n.folioWebPortalLinkCodeLabel,
                            border: const OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enabled: !_webLinkBusy,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _webLinkBusy
                                    ? null
                                    : () async {
                                        await _linkFolioWebPortalAccount();
                                        setLocal(() {});
                                      },
                                child: _webLinkBusy
                                    ? const FolioLoadingIndicator(
                                        size: FolioLoadingSize.small,
                                      )
                                    : Text(l10n.folioWebPortalLinkButton),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.folioWebPortalRefreshWeb,
                              onPressed: () async {
                                await _refreshFolioWebPortalEntitlement();
                                setLocal(() {});
                              },
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        if (_folio.webPortalRefreshError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _l10nFolioWebPortalError(
                              l10n,
                              _folio.webPortalRefreshError!,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.error),
                          ),
                        ],
                        if (webSnap != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            webSnap.linked
                                ? l10n.folioWebEntitlementLinked
                                : l10n.folioWebEntitlementNotLinked,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (webSnap.folioCloud != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              l10n.folioWebEntitlementWebPlan(
                                webSnap.folioCloud!
                                    ? l10n.settingsLabelYes
                                    : l10n.settingsLabelNo,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openFolioCloudSubscriptionPitch() async {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    final signedIn = _cloud.isSignedIn;
    final catalog = signedIn
        ? await FolioCloudCatalogPricesService.getPricing()
        : null;
    if (!mounted) return;
    final primaryLabel = signedIn
        ? FolioCloudCatalogLabels.subscribeMonthly(context, l10n, catalog)
        : l10n.folioCloudPitchCtaNeedAccount;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'folio_cloud_pitch'),
        builder: (ctx) => FolioCloudSubscriptionPitchPage(
          busy: _folioCloudActionBusy,
          primaryCtaLabel: primaryLabel,
          primaryIcon: signedIn
              ? Icons.subscriptions_outlined
              : Icons.person_add_outlined,
          onPrimaryCta: () {
            Navigator.of(ctx).pop();
            if (!mounted) return;
            if (signedIn) {
              unawaited(
                _openFolioCheckout(FolioCheckoutKind.folioCloudMonthly),
              );
            } else {
              unawaited(_showCloudAuthDialog(register: false));
            }
          },
        ),
      ),
    );
  }

  Future<void> _showCloudInkPricingTableDialog() {
    const preferredOrder = <String>[
      'rewrite_block',
      'summarize_selection',
      'extract_tasks',
      'summarize_page',
      'generate_insert',
      'generate_page',
      'chat_turn',
      'agent_main',
      'agent_followup',
      'edit_page_panel',
      'default',
    ];

    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final theme = Theme.of(ctx);
        final dialogScheme = theme.colorScheme;
        return FolioDialog(
          title: Text(l10n.settingsCloudInkUsageTableTitle),
          content: SizedBox(
            width: 540,
            child: FutureBuilder<FolioCloudAiPricingSnapshot>(
              future: FolioCloudAiPricingService.getPricing(),
              builder: (context, snapshot) {
                final pricing =
                    snapshot.data ?? FolioCloudAiPricingSnapshot.fallback();

                final allKeys = <String>{
                  ...preferredOrder,
                  ...pricing.costByOperation.keys,
                };
                final orderedKeys = <String>[
                  ...preferredOrder.where(allKeys.contains),
                  ...allKeys.where((k) => !preferredOrder.contains(k)).toList()
                    ..sort(),
                ];

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: FolioPricingTableSkeleton(),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.settingsCloudInkUsageTableIntro,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dialogScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...orderedKeys.map((operation) {
                        final drops = pricing.costForOperation(operation);
                        final label = settingsCloudInkOperationLabel(
                          l10n,
                          operation,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: dialogScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: dialogScheme.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        operation,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  dialogScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$drops',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: dialogScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.settingsCloudInkDrops,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: dialogScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.settingsClose),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeStripeFolioCheckout(FolioCheckoutKind kind) async {
    final l10n = AppLocalizations.of(context);
    if (kind == FolioCheckoutKind.folioCloudMonthly) {
      await FolioCloudConversionFlow(cloud: _cloud, folio: _folio)
          .openMonthlyCheckout(context, l10n: l10n);
      return;
    }
    final uri = await createFolioCheckoutUri(kind);
    if (uri == null) {
      _snack(l10n.settingsStripeCheckoutUnavailable);
      return;
    }
    if (FolioInAppCheckoutDialog.isSupported) {
      if (!mounted) return;
      final success = await showDialog<bool>(
        context: context,
        builder: (ctx) => FolioInAppCheckoutDialog(
          url: uri.toString(),
          scheme: Theme.of(context).colorScheme,
        ),
      );
      if (success == true && mounted) {
        _snack(l10n.folioCloudCheckoutSuccess);
        await _folio.refreshFolioCloudBillingFromServers(retryUntilActive: true);
      }
    } else {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _snack(l10n.settingsCouldNotOpenLink);
      } else {
        _folio.scheduleStripeSyncOnNextResume();
      }
    }
  }

  Future<void> _openFolioCheckout(FolioCheckoutKind kind) async {
    if (_folioCloudActionBusy) return;
    if (_folio.snapshot.hasPendingAccountDeletion) {
      if (mounted) {
        _snack(AppLocalizations.of(context).accountDeletionBlocksCheckout);
      }
      return;
    }
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      await _completeStripeFolioCheckout(kind);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<bool> _reauthFolioCloudForAccountLifecycle() async {
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

  Future<void> _exportFolioCloudAccountData() async {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    final ok = await _reauthFolioCloudForAccountLifecycle();
    if (!ok || !mounted) return;
    _rebuild(() => _folioCloudActionBusy = true);
    _snack(l10n.accountExportSaving);
    try {
      final result =
          await FolioCloudAccountLifecycle.exportAccountDataAndSave();
      if (!mounted) return;
      if (result == null) return;
      _snack(l10n.accountExportSaved);
      await _folio.refreshUserDocFromServer();
    } catch (e) {
      if (mounted) _snack(l10n.accountExportFailed('$e'));
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _requestFolioCloudAccountDeletion() async {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    final previewDate = DateTime.now().add(const Duration(days: 30));
    final dateLabel =
        MaterialLocalizations.of(context).formatFullDate(previewDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return FolioDialog(
          title: Text(l10n.accountDeleteDialogTitle),
          content: Text(l10n.accountDeleteDialogBody(dateLabel)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.accountDeleteConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final ok = await _reauthFolioCloudForAccountLifecycle();
    if (!ok || !mounted) return;
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      final scheduled =
          await FolioCloudAccountLifecycle.requestAccountDeletion();
      await _folio.refreshUserDocFromServer();
      if (!mounted) return;
      final label =
          MaterialLocalizations.of(context).formatFullDate(scheduled);
      _snack(l10n.accountDeleteRequestedOk(label));
    } catch (e) {
      if (mounted) _snack(l10n.accountDeleteFailed('$e'));
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _cancelFolioCloudAccountDeletion() async {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      await FolioCloudAccountLifecycle.cancelAccountDeletion();
      await _folio.refreshUserDocFromServer();
      if (mounted) _snack(l10n.accountDeleteCancelOk);
    } catch (e) {
      if (mounted) _snack(l10n.accountDeleteCancelFailed('$e'));
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _signOutFolioCloudAccount() async {
    final l10n = AppLocalizations.of(context);
    try {
      await _cloud.signOut();
      if (mounted) _snack(l10n.settingsSessionEndedSnack);
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _editCloudDisplayName() async {
    if (!_cloud.isSignedIn) return;
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: _cloud.displayName?.trim() ?? '',
    );
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return FolioDialog(
          title: Text(l10n.cloudAccountDisplayNameDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.cloudAccountDisplayNameHint,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.cloudAccountDisplayNameLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  final t = value.trim();
                  if (t.isEmpty) return;
                  Navigator.of(ctx).pop(t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isEmpty) {
                  _snack(l10n.cloudAccountDisplayNameRequired);
                  return;
                }
                Navigator.of(ctx).pop(t);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    if (_folioCloudActionBusy) return;
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      await FolioCloudAccountLifecycle.updateDisplayName(saved);
      await _cloud.reloadCurrentUser();
      if (mounted) _snack(l10n.cloudAccountDisplayNameSaved);
    } catch (e) {
      if (mounted) _snack(l10n.cloudAccountDisplayNameFailed('$e'));
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _inviteFamilyMember(String email) async {
    if (_folioCloudActionBusy) return;
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      await callFolioHttpsCallable('inviteFamilyMember', {'email': email});
      _snack('Familiar invitado correctamente.');
      await _folio.refreshFolioCloudBillingFromServers();
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _removeFamilyMember(String memberUid) async {
    if (_folioCloudActionBusy) return;
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      await callFolioHttpsCallable('removeFamilyMember', {'memberUid': memberUid});
      _snack('Acción realizada correctamente.');
      await _folio.refreshFolioCloudBillingFromServers();
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _verifyStudentStatus(String email) async {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      final res = await callFolioHttpsCallable('verifyStudentStatus', {'email': email});
      final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
      final pending = map['pending'] == true;
      final verified = map['verified'] == true;
      if (pending) {
        _snack(l10n.folioCloudStudentVerifyEmailSent);
        await _folio.refreshFolioCloudBillingFromServers();
      } else if (verified) {
        // Compat: should not happen with link-based flow.
        _snack(l10n.folioCloudStudentVerifySuccess);
        await _folio.refreshFolioCloudBillingFromServers();
      } else {
        _snack(l10n.folioCloudStudentVerifyFail);
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) _rebuild(() => _folioCloudActionBusy = false);
    }
  }


  /// Devuelve false si el usuario cancela o hay salida anticipa sin error.
  Future<bool> _uploadFolioCloudBackup({
    bool suppressSuccessSnack = false,
    VaultBackupProgressController? progress,
    double cloudProgressMin = 0.0,
    double cloudProgressMax = 1.0,
    bool manageBusyState = true,
  }) async {
    if (manageBusyState && _folioCloudActionBusy) return false;
    if (_s.state != VaultFlowState.unlocked) return false;
    final l10n = AppLocalizations.of(context);
    final vaultId = _s.activeVaultId;
    if (vaultId == null || vaultId.trim().isEmpty) {
      if (progress == null) {
        _snack(l10n.settingsNoActiveVault);
      }
      return false;
    }
    final snap = _folio.snapshot;
    if (!snap.canUseCloudBackup) {
      if (progress == null) {
        _snack(l10n.settingsCloudBackupEnablePlanSnack);
      }
      return false;
    }
    if (manageBusyState) {
      _rebuild(() => _folioCloudActionBusy = true);
    }
    try {
      final label = await _s.getActiveVaultDisplayLabel();
      try {
        await upsertFolioCloudBackupVaultIndex(
          vaultId: vaultId,
          displayName: label,
          entitlementSnapshot: snap,
        );
      } catch (_) {}
      String? restoreWrapPassword;
      // El envoltorio de recuperación se toma de vault.keys (cifrada) o se
      // genera vacío (en claro); no hace falta pedir contraseña al subir.
      try {
        final raw = await callFolioHttpsCallable(
          'folioGetLatestCloudPackMeta',
          <String, dynamic>{'vaultId': vaultId},
        );
        final latest = raw is Map ? raw['latest'] : null;
        final hasRestoreWrap =
            latest is Map && latest['hasRestoreWrap'] == true;
        // Solo en libreta en claro sin wrap: opcional contraseña de recuperación.
        if (!hasRestoreWrap &&
            !_s.vaultUsesEncryption &&
            mounted) {
          final l10nDlg = AppLocalizations.of(context);
          final pwd = await showDialog<String?>(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => _CloudPackWrapPasswordDialog(
              l10n: l10nDlg,
              encrypted: false,
            ),
          );
          if (pwd != null && pwd.trim().isNotEmpty) {
            restoreWrapPassword = pwd.trim();
          }
        }
      } catch (_) {
        // Si falla el meta, uploadOpenVaultCloudPack volverá a comprobar.
      }
      await uploadOpenVaultCloudPack(
        session: _s,
        vaultId: vaultId,
        entitlementSnapshot: snap,
        restoreWrapPassword: restoreWrapPassword,
        telemetrySettings: _app,
        onProgress: progress == null
            ? null
            : (u) {
                final span = cloudProgressMax - cloudProgressMin;
                final t =
                    cloudProgressMin + span * u.progress.clamp(0.0, 1.0);
                progress.setProgress(t);
                VaultBackupProgressController.logConsole(
                  cloudPackProgressLogLine(l10n, u),
                );
              },
      );
      if (mounted && !suppressSuccessSnack) {
        _snack(AppLocalizations.of(context).folioCloudUploadSnackOk);
      }
      if (mounted) {
        unawaited(_folio.refreshBackupStorageUsageFromServer());
        await _refreshCloudBackupCount();
      }
      return true;
    } catch (e) {
      if (progress != null) rethrow;
      if (mounted) {
        final msg = '$e';
        if (msg.contains('resource-exhausted') ||
            msg.contains('cuota') ||
            msg.contains('Cuota') ||
            msg.contains('superó')) {
          _snack(l10n.folioCloudBackupQuotaExceeded);
        } else {
          _snack(msg);
        }
      }
      return false;
    } finally {
      if (mounted && manageBusyState) {
        _rebuild(() => _folioCloudActionBusy = false);
      }
    }
  }

  /// Actualiza el contador de copias en la nube. No pide reautenticación Folio Cloud
  /// (eso queda solo para [downloadFolioCloudBackup] vía el diálogo de descarga).
  Future<void> _refreshCloudBackupCount() async {
    if (!mounted) return;
    if (_cloudBackupCountBusy) return;
    if (!_cloud.isAvailable || !_cloud.isSignedIn) return;
    final vaultId = _s.activeVaultId;
    if (vaultId == null || vaultId.trim().isEmpty) return;
    final snap = _folio.snapshot;
    if (!snap.canUseCloudBackup) return;
    if (!mounted) return;
    _rebuild(() => _cloudBackupCountBusy = true);
    try {
      await listFolioCloudBackups(vaultId: vaultId, entitlementSnapshot: snap);
      if (!mounted) return;
    } catch (_) {
      // No interrumpimos la UI por el contador.
    } finally {
      if (mounted) _rebuild(() => _cloudBackupCountBusy = false);
    }
  }

  Future<void> _openFolioCloudBackupsDialog() async {
    if (_folioCloudActionBusy) return;
    final dlgL10n = AppLocalizations.of(context);
    final snap = _folio.snapshot;
    if (!snap.canUseCloudBackup) {
      _snack(dlgL10n.settingsCloudBackupsNeedPlan);
      return;
    }
    _rebuild(() => _folioCloudActionBusy = true);

    late final List<FolioCloudBackupVaultEntry> vaults;
    late String initialVaultId;
    late List<FolioCloudBackupEntry> initialEntries;
    try {
      vaults = await listFolioCloudBackupVaults(entitlementSnapshot: snap);
      final activeId = _s.activeVaultId?.trim() ?? '';
      initialVaultId = vaults.any((v) => v.vaultId == activeId)
          ? activeId
          : (vaults.isNotEmpty ? vaults.first.vaultId : '');
      initialEntries = initialVaultId.isNotEmpty
          ? await listFolioCloudBackups(
              vaultId: initialVaultId,
              entitlementSnapshot: snap,
            )
          : const [];
    } catch (e) {
      if (mounted) {
        _rebuild(() => _folioCloudActionBusy = false);
        _snack('$e');
      }
      return;
    }
    if (!mounted) return;
    _rebuild(() => _folioCloudActionBusy = false);

    await showFolioCloudBackupsSheet(
      context: context,
      entitlementSnapshot: snap,
      session: _s,
      telemetrySettings: _app,
      vaults: vaults,
      initialVaultId: initialVaultId,
      initialEntries: initialEntries,
      formatByteSize: _formatByteSize,
      verifyAccount: _verifyFolioCloudAccountForBackups,
      onSnack: _snack,
      onQuotaChanged: _refreshCloudBackupCount,
    );
  }

  Future<void> _openPublishedPagesDialog() async {
    if (_folioCloudActionBusy) return;
    final l10nEarly = AppLocalizations.of(context);
    final snap = _folio.snapshot;
    if (!snap.canPublishToWeb) {
      _snack(l10nEarly.settingsPublishedRequiresPlan);
      return;
    }
    _rebuild(() => _folioCloudActionBusy = true);
    late final List<PublishedPageEntry> entries;
    try {
      entries = await listMyPublishedPages();
    } catch (e) {
      if (mounted) {
        _rebuild(() => _folioCloudActionBusy = false);
        _snack('$e');
      }
      return;
    }
    if (!mounted) return;
    _rebuild(() => _folioCloudActionBusy = false);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.settingsPublishedPagesTitle),
        content: SizedBox(
          width: 440,
          child: entries.isEmpty
              ? Text(l10n.settingsPublishedPagesEmpty)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (c, i) {
                      final e = entries[i];
                      final when = e.updatedAt != null
                          ? '${e.updatedAt!.toLocal()}'
                          : '—';
                      return ListTile(
                        title: Text(
                          e.slug,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.open,
                              icon: const Icon(Icons.open_in_new_outlined),
                              onPressed: () async {
                                final u = Uri.tryParse(e.publicUrl);
                                if (u != null) {
                                  await launchUrl(
                                    u,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: l10n.delete,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                              onPressed: () async {
                                final sure = await FolioDialog.confirm(
                                  ctx,
                                  title: Text(
                                    l10n.settingsPublishedDeleteDialogTitle,
                                  ),
                                  content: Text(
                                    l10n.settingsPublishedDeleteDialogBody,
                                  ),
                                  confirmLabel: l10n.delete,
                                  destructive: true,
                                );
                                if (sure != true || !ctx.mounted) return;
                                try {
                                  await deletePublishedPage(
                                    e,
                                    entitlementSnapshot: snap,
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (mounted) {
                                    _snack(l10n.settingsPublishedRemovedSnack);
                                  }
                                } catch (err) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('$err')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.settingsClose),
          ),
        ],
      ),
    );
  }

  String _suggestedBackupFileName() {
    final d = DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'folio-libreta-$y-$m-$day.folio.zip';
  }

  Future<void> _uploadAppProfileFromSettings() async {
    final ctrl = widget.cloudSettingsSyncController;
    final l10n = AppLocalizations.of(context);
    if (ctrl == null) {
      _snack('${l10n.folioCloudAppProfileRestoreFail} (sin controlador)');
      return;
    }
    final ok = await ctrl.pushAppProfileNow(notifyUser: true);
    if (!mounted) return;
    if (ok) {
      _snack(l10n.folioCloudAppProfilePushOk);
    } else {
      final detail = ctrl.lastError;
      _snack(
        detail == null || detail.isEmpty
            ? l10n.folioCloudAppProfileRestoreFail
            : '${l10n.folioCloudAppProfileRestoreFail}\n$detail',
      );
    }
  }

  Future<void> _restoreAppProfileFromSettings() async {
    final ctrl = widget.cloudSettingsSyncController;
    final l10n = AppLocalizations.of(context);
    if (ctrl == null) {
      _snack('${l10n.folioCloudAppProfileRestoreFail} (sin controlador)');
      return;
    }
    final ok = await ctrl.restoreAppProfileFromCloud();
    if (!mounted) return;
    if (ok) {
      _snack(l10n.folioCloudAppProfileRestoreOk);
    } else if (ctrl.lastError == 'empty_cloud_profile') {
      _snack(l10n.folioCloudAppProfileEmptyCloud);
    } else {
      final detail = ctrl.lastError;
      _snack(
        detail == null || detail.isEmpty
            ? l10n.folioCloudAppProfileRestoreFail
            : '${l10n.folioCloudAppProfileRestoreFail}\n$detail',
      );
    }
  }

  Future<void> _restoreVaultProfileFromSettings() async {
    final ctrl = widget.cloudSettingsSyncController;
    final l10n = AppLocalizations.of(context);
    if (ctrl == null) {
      _snack('${l10n.folioCloudAppProfileRestoreFail} (sin controlador)');
      return;
    }
    final vaultId = _s.activeVaultId ?? VaultPaths.activeVaultId ?? '';
    if (vaultId.isEmpty) {
      _snack('${l10n.folioCloudAppProfileRestoreFail} (sin vaultId)');
      return;
    }
    final ok = await ctrl.restoreVaultProfileFromCloud(vaultId);
    if (!mounted) return;
    if (ok) {
      await _loadVaultBackupPrefs();
      _snack(l10n.folioCloudAppProfileRestoreOk);
    } else if (ctrl.lastError == 'empty_cloud_vault_profile') {
      _snack(l10n.folioCloudAppProfileEmptyCloud);
    } else {
      final detail = ctrl.lastError;
      _snack(
        detail == null || detail.isEmpty
            ? l10n.folioCloudAppProfileRestoreFail
            : '${l10n.folioCloudAppProfileRestoreFail}\n$detail',
      );
    }
  }
}
