part of 'settings_page.dart';

extension _SettingsPageAiActions on _SettingsPageState {
  Future<void> _confirmRemoteEndpointIfNeeded() async {
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(_app.aiBaseUrl);
    if (uri == null) return;
    final isRemote = !AiSafetyPolicy.isLocalhostHost(uri.host);
    if (!isRemote || _app.aiEndpointMode != AiEndpointMode.allowRemote) return;
    if (_app.aiRemoteEndpointConfirmed) return;
    final l10n = AppLocalizations.of(context);
    final go = await FolioDialog.confirm(
      context,
      title: Text(l10n.confirmRemoteEndpointTitle),
      content: Text(l10n.confirmRemoteEndpointBody(uri.host)),
      confirmLabel: l10n.confirmAction,
      cancelLabel: l10n.cancel,
    );
    if (go == true) {
      await _app.setAiRemoteEndpointConfirmed(true);
      return;
    }
    await _app.setAiEnabled(false);
  }

  Future<void> _saveAiFields() async {
    await _app.setAiBaseUrl(_aiBaseUrlController.text);
    await _app.setAiApiKey(_aiApiKeyController.text);
    final timeout = int.tryParse(_aiTimeoutController.text.trim());
    if (timeout != null) {
      await _app.setAiTimeoutMs(timeout);
    }
    final ctxWin = int.tryParse(_aiContextWindowController.text.trim());
    if (ctxWin != null) {
      await _app.setAiContextWindowTokens(ctxWin);
    }
    await _confirmRemoteEndpointIfNeeded();
    await _refreshReleaseReadiness();
  }

  Future<bool> _confirmQuillGlobalScopeIfNeeded() async {
    if (_app.hasAcceptedQuillGlobalScope) return true;
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.aiConsentTitle),
        content: Text(l10n.aiConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.aiConsentConfirm),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _app.setHasAcceptedQuillGlobalScope(true);
      return true;
    }
    return false;
  }

  Future<void> _showAiComplianceDocs() async {
    final l10n = AppLocalizations.of(context);
    final openPrivacy = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.aiComplianceDocsTitle),
        content: SingleChildScrollView(
          child: Text(l10n.aiComplianceDocsBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ok),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.aiComplianceDocsOpenPrivacy),
          ),
        ],
      ),
    );
    if (openPrivacy != true || !mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    final uri = FolioStatusUrls.privacyPolicyUri(languageCode: lang);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _providerLabel(AiProvider provider, AppLocalizations l10n) {
    switch (provider) {
      case AiProvider.ollama:
        return l10n.aiProviderOllamaName;
      case AiProvider.lmStudio:
        return l10n.aiProviderLmStudioName;
      case AiProvider.quillCloud:
        return 'Quill Cloud';
      case AiProvider.openAi:
        return 'OpenAI';
      case AiProvider.gemini:
        return 'Gemini';
      case AiProvider.geminiNano:
        return _onDeviceProviderLabel(l10n);
      case AiProvider.none:
        return l10n.aiProviderNone;
    }
  }

  String _onDeviceProviderLabel(AppLocalizations l10n) {
    switch (_onDeviceAiBrand) {
      case OnDeviceAiBrand.samsung:
        return l10n.aiProviderGalaxyAiByGemini;
      case OnDeviceAiBrand.google:
      case OnDeviceAiBrand.other:
        return l10n.aiProviderGeminiNano;
    }
  }

  Future<void> _refreshOnDeviceAiInfo({bool force = false}) async {
    if (!aiOnDeviceProviderSupported) return;
    try {
      final brand = await OnDeviceAiBridge.getDeviceBrand(force: force);
      final status = await OnDeviceAiBridge.checkStatus(force: force);
      if (!mounted) return;
      _rebuild(() {
        _onDeviceAiBrand = brand;
        _onDeviceAiStatus = status;
      });
    } catch (_) {
      if (!mounted) return;
      _rebuild(() {
        _onDeviceAiStatus = OnDeviceAiStatus.unavailable;
      });
    }
  }

  Future<void> _downloadOnDeviceAiModel() async {
    if (_onDeviceAiBusy) return;
    final l10n = AppLocalizations.of(context);
    _rebuild(() {
      _onDeviceAiBusy = true;
      _onDeviceAiStatus = OnDeviceAiStatus.downloading;
      _onDeviceDownloadBytes = null;
    });
    await _onDeviceDownloadSub?.cancel();
    _onDeviceDownloadSub = OnDeviceAiBridge.downloadEvents().listen((event) {
      if (!mounted) return;
      if (event.phase == 'progress' || event.phase == 'started') {
        _rebuild(() => _onDeviceDownloadBytes = event.bytesDownloaded);
      }
    });
    try {
      final status = await OnDeviceAiBridge.download();
      if (!mounted) return;
      _rebuild(() {
        _onDeviceAiStatus = status;
        _onDeviceAiBusy = false;
      });
      _snack(l10n.aiOnDeviceStatusAvailable);
    } catch (e) {
      if (!mounted) return;
      _rebuild(() {
        _onDeviceAiBusy = false;
        _onDeviceAiStatus = OnDeviceAiStatus.downloadable;
      });
      _snack(l10n.aiOnDeviceDownloadFailed('$e'));
    } finally {
      await _onDeviceDownloadSub?.cancel();
      _onDeviceDownloadSub = null;
    }
  }

  Future<AiProvider?> _askUserProviderChoice() async {
    final l10n = AppLocalizations.of(context);
    return showDialog<AiProvider>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.aiSetupChooseProviderTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.aiSetupChooseProviderBody),
            const SizedBox(height: 12),
            if (aiOnDeviceProviderSupported)
              ListTile(
                leading: const Icon(Icons.phone_android_outlined),
                title: Text(_onDeviceProviderLabel(l10n)),
                onTap: () => Navigator.pop(ctx, AiProvider.geminiNano),
              ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(_providerLabel(AiProvider.quillCloud, l10n)),
              onTap: () {
                if (!_folio.isAvailable) {
                  _snack(l10n.settingsAiSnackFirebaseUnavailableBuild);
                  return;
                }
                if (!_cloud.isSignedIn) {
                  _snack(l10n.settingsAiSnackSignInCloudAccount);
                  return;
                }
                if (!_folio.snapshot.canUseCloudAi) {
                  _snack(l10n.aiProviderFolioCloudBlockedSnack);
                  return;
                }
                Navigator.pop(ctx, AiProvider.quillCloud);
              },
            ),
            if (aiLocalProvidersSupported) ...[
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: Text(l10n.aiProviderOllamaName),
                onTap: () => Navigator.pop(ctx, AiProvider.ollama),
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: Text(l10n.aiProviderLmStudioName),
                onTap: () => Navigator.pop(ctx, AiProvider.lmStudio),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.rocket_launch_outlined),
              title: const Text('OpenAI'),
              onTap: () => Navigator.pop(ctx, AiProvider.openAi),
            ),
            ListTile(
              leading: const Icon(Icons.rocket_launch_outlined),
              title: const Text('Gemini'),
              onTap: () => Navigator.pop(ctx, AiProvider.gemini),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<bool> _autoDetectAndConfigureAiProvider() async {
    if (_detectingAiProvider) return false;
    _rebuild(() => _detectingAiProvider = true);
    try {
      final detector = const AiProviderDetector();
      final summary = await detector.detect(preferredProvider: _app.aiProvider);
      final recommended = summary.recommendedProvider;
      if (recommended != null) {
        await _app.setAiProvider(recommended);
        final baseUrl = recommended == AiProvider.ollama
            ? AppSettings.defaultOllamaUrl
            : AppSettings.defaultLmStudioUrl;
        _aiBaseUrlController.text = baseUrl;
        await _app.setAiBaseUrl(baseUrl);
        await _saveAiFields();
        await _loadAiModels();
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _snack(
            l10n.aiProviderAutoConfigured(_providerLabel(recommended, l10n)),
          );
        }
        return true;
      }

      if (!mounted) return false;
      final l10n = AppLocalizations.of(context);
      final selectedProvider = await _askUserProviderChoice();
      if (!mounted || selectedProvider == null) return false;
      if (selectedProvider == AiProvider.quillCloud) {
        await _app.setAiProvider(AiProvider.quillCloud);
        await _saveAiFields();
        if (mounted) {
          final l10nDone = AppLocalizations.of(context);
          _snack(
            l10nDone.aiProviderAutoConfigured(
              _providerLabel(AiProvider.quillCloud, l10nDone),
            ),
          );
        }
        return true;
      }
      if (selectedProvider == AiProvider.geminiNano) {
        await _app.setAiProvider(AiProvider.geminiNano);
        await _refreshOnDeviceAiInfo(force: true);
        await _saveAiFields();
        if (mounted) {
          final l10nDone = AppLocalizations.of(context);
          _snack(
            l10nDone.aiProviderAutoConfigured(
              _providerLabel(AiProvider.geminiNano, l10nDone),
            ),
          );
        }
        return true;
      }
      var retry = true;
      while (retry && mounted) {
        final action = await showDialog<_AiWizardAction>(
          context: context,
          builder: (ctx) => _AiSetupWizardDialog(
            summary: summary,
            selectedProvider: selectedProvider,
            title: l10n.aiSetupWizardTitle,
            noProviderTitle: l10n.aiSetupNoProviderTitle,
            noProviderBody: l10n.aiSetupNoProviderBody,
            ollamaInstallTitle: l10n.aiSetupOllamaTitle,
            ollamaInstallBody: l10n.aiSetupOllamaBody,
            lmStudioInstallTitle: l10n.aiSetupLmStudioTitle,
            lmStudioInstallBody: l10n.aiSetupLmStudioBody,
            openSettingsHint: l10n.aiSetupOpenSettingsHint,
            retryLabel: l10n.retry,
            closeLabel: l10n.cancel,
          ),
        );
        if (action == _AiWizardAction.retry) {
          final redetected = await detector.detect(
            preferredProvider: _app.aiProvider,
          );
          final selectedResult = selectedProvider == AiProvider.ollama
              ? redetected.ollama
              : redetected.lmStudio;
          if (selectedResult.reachable) {
            await _app.setAiProvider(selectedProvider);
            final baseUrl = selectedProvider == AiProvider.ollama
                ? AppSettings.defaultOllamaUrl
                : AppSettings.defaultLmStudioUrl;
            _aiBaseUrlController.text = baseUrl;
            await _app.setAiBaseUrl(baseUrl);
            await _saveAiFields();
            await _loadAiModels();
            if (mounted) {
              final l10n = AppLocalizations.of(context);
              _snack(
                l10n.aiProviderAutoConfigured(
                  _providerLabel(selectedProvider, l10n),
                ),
              );
            }
            return true;
          }
          retry = true;
          continue;
        }
        retry = false;
      }
      return false;
    } finally {
      if (mounted) _rebuild(() => _detectingAiProvider = false);
    }
  }

  AiService _buildAiServiceFromInputs() {
    switch (_app.aiProvider) {
      case AiProvider.quillCloud:
        return FolioCloudAiService(entitlements: _folio);
      case AiProvider.geminiNano:
        return GeminiNanoAiService(
          timeout: Duration(
            milliseconds: (int.tryParse(_aiTimeoutController.text.trim()) ??
                    _app.aiTimeoutMs)
                .clamp(3000, 120000),
          ),
        );
      case AiProvider.none:
        throw StateError('Selecciona un proveedor IA primero.');
      case AiProvider.ollama:
      case AiProvider.lmStudio:
      case AiProvider.openAi:
      case AiProvider.gemini:
        break;
    }
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(
      _aiBaseUrlController.text.trim(),
    );
    if (uri == null) {
      throw StateError('URL inválida. Usa http://localhost:1234');
    }
    final timeoutMs =
        int.tryParse(_aiTimeoutController.text.trim()) ?? _app.aiTimeoutMs;
    final timeout = Duration(milliseconds: timeoutMs.clamp(3000, 120000));
    switch (_app.aiProvider) {
      case AiProvider.ollama:
        return OllamaAiService(
          baseUrl: uri,
          timeout: timeout,
          defaultModel: _app.aiModel,
        );
      case AiProvider.lmStudio:
        return LmStudioAiService(
          baseUrl: uri,
          timeout: timeout,
          defaultModel: _app.aiModel,
        );
      case AiProvider.openAi:
      case AiProvider.gemini:
        return OpenAiCompatibleAiService(
          baseUrl: uri,
          timeout: timeout,
          defaultModel: _app.aiModel,
          apiKey: _aiApiKeyController.text,
          provider: _app.aiProvider.name,
        );
      case AiProvider.none:
      case AiProvider.quillCloud:
      case AiProvider.geminiNano:
        throw StateError(
          lookupAppLocalizations(
            _app.locale ?? const Locale('es'),
          ).settingsAiSelectProviderFirst,
        );
    }
  }

  Future<void> _testAiConnection() async {
    await _saveAiFields();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final isLocal = _app.aiProvider == AiProvider.ollama || _app.aiProvider == AiProvider.lmStudio;
    if (isLocal) {
      final err = AiSafetyPolicy.validateEndpointIssue(
        rawUrl: _app.aiBaseUrl,
        mode: _app.aiEndpointMode,
        remoteConfirmed: _app.aiRemoteEndpointConfirmed,
      );
      if (err != null) {
        _snack(err.localizedMessage(l10n));
        return;
      }
    }
    try {
      final service = _buildAiServiceFromInputs();
      await service.ping();
      await _loadAiModels();
      _snack(l10n.settingsAiConnectionOk);
    } catch (e) {
      if (e is FolioCloudAiException) {
        _snack(e.message);
      } else {
        _snack(l10n.settingsAiConnectionError('$e'));
      }
    }
  }

  Future<void> _loadAiModels() async {
    _rebuild(() => _loadingModels = true);
    try {
      final service = _buildAiServiceFromInputs();
      final models = await service.listModels();
      if (!mounted) return;
      _rebuild(() {
        _availableModels = models;
      });
      await _app.setCachedAiModelsFor(_app.aiProvider, models);
      if (models.isNotEmpty) {
        final selected = models.contains(_app.aiModel)
            ? _app.aiModel
            : models.first;
        await _app.setAiModel(selected);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).settingsAiListModelsFailed('$e'));
    } finally {
      if (mounted) {
        _rebuild(() => _loadingModels = false);
      }
    }
  }

}
