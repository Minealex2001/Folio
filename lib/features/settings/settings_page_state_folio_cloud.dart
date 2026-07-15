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
          await _folio.refreshFolioCloudBillingFromServers();
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
    final user = FirebaseAuth.instance.currentUser;
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

  void _openFolioCloudSubscriptionPitch() {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    final signedIn = _cloud.isSignedIn;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'folio_cloud_pitch'),
        builder: (ctx) => FolioCloudSubscriptionPitchPage(
          busy: _folioCloudActionBusy,
          primaryCtaLabel: signedIn
              ? l10n.folioCloudSubscribeMonthly
              : l10n.folioCloudPitchCtaNeedAccount,
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
        await _folio.refreshFolioCloudBillingFromServers();
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
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      await _completeStripeFolioCheckout(kind);
    } catch (e) {
      if (mounted) _snack('$e');
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
    _rebuild(() => _folioCloudActionBusy = true);
    try {
      final res = await callFolioHttpsCallable('verifyStudentStatus', {'email': email});
      final verified = (res as Map?)?.cast<String, dynamic>()['verified'] == true;
      if (verified) {
        _snack('¡Verificación completada con éxito!');
        await _folio.refreshFolioCloudBillingFromServers();
        if (mounted) {
          await _openFolioCheckout(FolioCheckoutKind.folioStudentMonthly);
        }
      } else {
        _snack('El correo ingresado no es válido para estudiantes.');
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
      try {
        final raw = await callFolioHttpsCallable(
          'folioGetLatestCloudPackMeta',
          <String, dynamic>{'vaultId': vaultId},
        );
        final latest = raw is Map ? raw['latest'] : null;
        final hasRestoreWrap =
            latest is Map && latest['hasRestoreWrap'] == true;
        if (!hasRestoreWrap && mounted) {
          final l10nDlg = AppLocalizations.of(context);
          final encrypted = _s.vaultUsesEncryption;
          final pwd = await showDialog<String?>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _CloudPackWrapPasswordDialog(
              l10n: l10nDlg,
              encrypted: encrypted,
            ),
          );
          if (pwd == null) return false;
          if (encrypted && pwd.isEmpty) {
            if (mounted) {
              _snack(l10n.settingsCloudBackupWrapPasswordRequired);
            }
            return false;
          }
          restoreWrapPassword = pwd.isEmpty ? null : pwd;
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

    // Pre-carga la lista de libretas y los backups de la libreta activa (o la primera).
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
    _rebuild(() {
      _folioCloudActionBusy = false;
    });

    final l10n = AppLocalizations.of(context);

    // Estado del diálogo.
    var selectedVaultId = initialVaultId;
    var entries = initialEntries;
    var dialogLoading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          Future<void> switchVault(String vaultId) async {
            setSt(() {
              selectedVaultId = vaultId;
              dialogLoading = true;
            });
            try {
              final newEntries = await listFolioCloudBackups(
                vaultId: vaultId,
                entitlementSnapshot: snap,
              );
              if (ctx.mounted) {
                setSt(() {
                  entries = newEntries;
                  dialogLoading = false;
                });
              }
            } catch (e) {
              if (ctx.mounted) {
                setSt(() => dialogLoading = false);
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          }

          Widget buildBackupList() {
            if (dialogLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (entries.isEmpty) {
              return Text(l10n.settingsCloudBackupsEmpty);
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.settingsCloudBackupsTotalLabel(
                        _formatByteSize(
                          entries.fold<int>(
                            0,
                            (a, e) => a + (e.sizeBytes > 0 ? e.sizeBytes : 0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (c, i) {
                        final e = entries[i];
                        final sizeLabel = e.sizeBytes > 0
                            ? _formatByteSize(e.sizeBytes)
                            : '—';
                        final whenRaw = e.createdAt.trim();
                        final when = whenRaw.isNotEmpty ? whenRaw : '—';
                        return ListTile(
                          title: Text(
                            e.isCloudPack
                                ? l10n.folioCloudBackupTypeIncremental
                                : e.fileName,
                            style: TextStyle(
                              fontFamily: e.isCloudPack ? null : 'monospace',
                              fontWeight: e.isCloudPack
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            e.isCloudPack
                                ? '${e.fileName} · $sizeLabel · $when'
                                : '$sizeLabel · $when',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: l10n.workspaceMoreActionsTooltip,
                            itemBuilder: (mCtx) => [
                              if (!e.isCloudPack)
                                PopupMenuItem(
                                  value: 'download',
                                  child: Text(
                                    l10n.settingsCloudBackupActionDownload,
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'import_overwrite',
                                child: Text(
                                  l10n.settingsCloudBackupActionImportOverwrite,
                                ),
                              ),
                              if (!e.isCloudPack)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.delete),
                                ),
                            ],
                            onSelected: (action) async {
                              if (action == 'download') {
                                if (e.isCloudPack) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.folioCloudBackupPackNoDownload,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final verified =
                                    await _verifyFolioCloudAccountForBackups();
                                if (!verified || !mounted) return;
                                try {
                                  if (kIsWeb) {
                                    final bytes =
                                        await downloadFolioCloudBackupBytes(
                                          entry: e,
                                          entitlementSnapshot: snap,
                                        );
                                    if (!ctx.mounted) return;
                                    folioTriggerBrowserDownload(
                                      e.fileName,
                                      bytes,
                                    );
                                  } else {
                                    final path = await FilePicker.saveFile(
                                      dialogTitle: l10n
                                          .settingsCloudBackupSaveDialogTitle,
                                      fileName: e.fileName,
                                    );
                                    if (path == null || !ctx.mounted) return;
                                    await downloadFolioCloudBackup(
                                      entry: e,
                                      destinationFile: File(path),
                                      entitlementSnapshot: snap,
                                    );
                                  }
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (mounted) {
                                    _snack(
                                      l10n.settingsCloudBackupDownloadedSnack,
                                    );
                                  }
                                } catch (err) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('$err')),
                                    );
                                  }
                                }
                                return;
                              }

                              if (action == 'import_overwrite') {
                                if (!_s.isUnlocked) {
                                  _snack(
                                    l10n.settingsCloudBackupVaultMustBeUnlocked,
                                  );
                                  return;
                                }
                                final verified =
                                    await _verifyFolioCloudAccountForBackups();
                                if (!verified || !mounted || !ctx.mounted) {
                                  return;
                                }

                                final sure = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text(
                                      l10n.settingsCloudBackupImportOverwriteTitle,
                                    ),
                                    content: Text(
                                      l10n.settingsCloudBackupImportOverwriteBody,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, true),
                                        child: Text(
                                          l10n.settingsCloudBackupActionImportOverwrite,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (sure != true || !ctx.mounted) return;

                                final tmpDir = await Directory.systemTemp
                                    .createTemp('folio_cloud_import_');
                                final localPath = p.join(
                                  tmpDir.path,
                                  e.fileName,
                                );
                                final localFile = File(localPath);
                                try {
                                  String password = '';
                                  if (e.isCloudPack) {
                                    final extract = Directory(
                                      p.join(tmpDir.path, 'vault_extract'),
                                    );
                                    await extract.create(recursive: true);
                                    final activeId =
                                        _s.activeVaultId?.trim() ?? '';
                                    final sameCloudVault =
                                        selectedVaultId == activeId;
                                    if (!sameCloudVault) {
                                      if (!ctx.mounted) return;
                                      final ctrl = TextEditingController();
                                      var obscure = true;
                                      final ok = await showDialog<bool>(
                                        context: ctx,
                                        builder: (dCtx) => StatefulBuilder(
                                          builder: (dCtx, setSt2) => AlertDialog(
                                            title: Text(
                                              l10n.backupPasswordDialogTitle,
                                            ),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                    l10n.settingsCloudBackupImportRemoteCloudPackIntro,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  FolioPasswordField(
                                                    controller: ctrl,
                                                    labelText:
                                                        l10n.passwordLabel,
                                                    obscureText: obscure,
                                                    onToggleObscure: () =>
                                                        setSt2(
                                                          () => obscure =
                                                              !obscure,
                                                        ),
                                                    showPasswordTooltip:
                                                        l10n.showPassword,
                                                    hidePasswordTooltip:
                                                        l10n.hidePassword,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    l10n.cloudPackRestorePasswordHelper,
                                                    style: Theme.of(
                                                      dCtx,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dCtx, false),
                                                child: Text(l10n.cancel),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(dCtx, true),
                                                child: Text(
                                                  l10n.settingsCloudBackupActionImportOverwrite,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      password = ctrl.text;
                                      ctrl.dispose();
                                      if (ok != true) {
                                        return;
                                      }
                                      await downloadCloudPackToDirectoryForRestore(
                                        vaultId: selectedVaultId,
                                        restorePassword: password,
                                        extractDir: extract,
                                        entitlementSnapshot: snap,
                                        telemetrySettings: _app,
                                      );
                                    } else {
                                      await downloadLatestCloudPackToDirectory(
                                        session: _s,
                                        vaultId: selectedVaultId,
                                        extractDir: extract,
                                        entitlementSnapshot: snap,
                                        telemetrySettings: _app,
                                      );
                                      final modeFile = File(
                                        p.join(
                                          extract.path,
                                          VaultPaths.vaultModeFile,
                                        ),
                                      );
                                      final isPlain =
                                          modeFile.existsSync() &&
                                          modeFile
                                                  .readAsStringSync()
                                                  .trim()
                                                  .toLowerCase() ==
                                              'plain';
                                      if (!isPlain) {
                                        if (!ctx.mounted) return;
                                        final ctrl = TextEditingController();
                                        var obscure = true;
                                        final ok = await showDialog<bool>(
                                          context: ctx,
                                          builder: (dCtx) => StatefulBuilder(
                                            builder: (dCtx, setSt2) => AlertDialog(
                                              title: Text(
                                                l10n.backupPasswordDialogTitle,
                                              ),
                                              content: FolioPasswordField(
                                                controller: ctrl,
                                                labelText: l10n.passwordLabel,
                                                obscureText: obscure,
                                                onToggleObscure: () => setSt2(
                                                  () => obscure = !obscure,
                                                ),
                                                showPasswordTooltip:
                                                    l10n.showPassword,
                                                hidePasswordTooltip:
                                                    l10n.hidePassword,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dCtx,
                                                        false,
                                                      ),
                                                  child: Text(l10n.cancel),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(dCtx, true),
                                                  child: Text(
                                                    l10n.settingsCloudBackupActionImportOverwrite,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        password = ctrl.text;
                                        ctrl.dispose();
                                        if (ok != true ||
                                            password.trim().isEmpty) {
                                          return;
                                        }
                                      }
                                    }
                                    await _s
                                        .importVaultBackupOverwriteActiveFromExtractedDir(
                                          extract,
                                          password,
                                        );
                                  } else {
                                    await downloadFolioCloudBackup(
                                      entry: e,
                                      destinationFile: localFile,
                                      entitlementSnapshot: snap,
                                    );
                                    final isPlain = await isPlainBackupArchive(
                                      localFile,
                                    );
                                    if (!isPlain) {
                                      if (!ctx.mounted) return;
                                      final ctrl = TextEditingController();
                                      var obscure = true;
                                      final ok = await showDialog<bool>(
                                        context: ctx,
                                        builder: (dCtx) => StatefulBuilder(
                                          builder: (dCtx, setSt2) => AlertDialog(
                                            title: Text(
                                              l10n.backupPasswordDialogTitle,
                                            ),
                                            content: FolioPasswordField(
                                              controller: ctrl,
                                              labelText: l10n.passwordLabel,
                                              obscureText: obscure,
                                              onToggleObscure: () => setSt2(
                                                () => obscure = !obscure,
                                              ),
                                              showPasswordTooltip:
                                                  l10n.showPassword,
                                              hidePasswordTooltip:
                                                  l10n.hidePassword,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dCtx, false),
                                                child: Text(l10n.cancel),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(dCtx, true),
                                                child: Text(
                                                  l10n.settingsCloudBackupActionImportOverwrite,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      password = ctrl.text;
                                      ctrl.dispose();
                                      if (ok != true ||
                                          password.trim().isEmpty) {
                                        return;
                                      }
                                    }
                                    await _s.importVaultBackupOverwriteActive(
                                      localFile.path,
                                      password,
                                    );
                                  }
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  _snack(l10n.settingsCloudBackupImportedSnack);
                                } catch (err) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('$err')),
                                    );
                                  }
                                } finally {
                                  try {
                                    if (tmpDir.existsSync()) {
                                      await tmpDir.delete(recursive: true);
                                    }
                                  } catch (_) {}
                                }
                                return;
                              }

                              if (action == 'delete') {
                                final sure = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text(l10n.delete),
                                    content: Text(
                                      l10n.settingsCloudBackupDeleteWarning,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, true),
                                        child: Text(l10n.delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (sure != true || !ctx.mounted) return;
                                try {
                                  await deleteFolioCloudBackup(
                                    entry: e,
                                    entitlementSnapshot: snap,
                                  );
                                  if (!ctx.mounted) return;
                                  // Refresca la lista en lugar de cerrar el diálogo.
                                  await switchVault(selectedVaultId);
                                  if (mounted) {
                                    _snack(
                                      l10n.settingsCloudBackupDeletedSnack,
                                    );
                                    await _refreshCloudBackupCount();
                                  }
                                } catch (err) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('$err')),
                                    );
                                  }
                                }
                                return;
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          return FolioDialog(
            title: Text(l10n.settingsCloudBackupsDialogTitle(entries.length)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (vaults.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedVaultId.isNotEmpty
                          ? selectedVaultId
                          : null,
                      decoration: InputDecoration(
                        labelText: l10n.settingsCloudBackupsVaultLabel,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: vaults.map((v) {
                        final name = v.displayName.isNotEmpty
                            ? v.displayName
                            : v.vaultId;
                        return DropdownMenuItem(
                          value: v.vaultId,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: dialogLoading
                          ? null
                          : (v) {
                              if (v != null && v != selectedVaultId) {
                                unawaited(switchVault(v));
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                  ],
                  buildBackupList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ],
          );
        },
      ),
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
                                final sure = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text(
                                      l10n.settingsPublishedDeleteDialogTitle,
                                    ),
                                    content: Text(
                                      l10n.settingsPublishedDeleteDialogBody,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, false),
                                        child: Text(
                                          MaterialLocalizations.of(
                                            dCtx,
                                          ).cancelButtonLabel,
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, true),
                                        child: Text(l10n.delete),
                                      ),
                                    ],
                                  ),
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
}
