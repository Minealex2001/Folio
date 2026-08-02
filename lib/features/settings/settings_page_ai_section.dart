part of 'settings_page.dart';

extension _SettingsPageAiSection on _SettingsPageState {
  Widget _aiSettingsSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildAiCloudVsLocalCompare(
    AppLocalizations l10n,
    ColorScheme scheme, {
    required bool aiLocalProvidersSupported,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.aiCompareCloudVsLocalTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              Widget card({
                required IconData icon,
                required String title,
                required List<String> bullets,
              }) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...bullets.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $b',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final cloudCard = card(
                icon: Icons.cloud_outlined,
                title: l10n.aiCompareCloudTitle,
                bullets: [
                  l10n.aiCompareCloudBulletNoSetup,
                  l10n.aiCompareCloudBulletNeedsSub,
                  l10n.aiCompareCloudBulletInk,
                ],
              );
              final localCard = card(
                icon: Icons.computer_outlined,
                title: l10n.aiCompareLocalTitle,
                bullets: [
                  l10n.aiCompareLocalBulletPrivacy,
                  l10n.aiCompareLocalBulletNoInk,
                  l10n.aiCompareLocalBulletSetup,
                ],
              );

              if (!aiLocalProvidersSupported) return cloudCard;
              if (narrow) {
                return Column(
                  children: [
                    cloudCard,
                    const SizedBox(height: 10),
                    localCard,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cloudCard),
                  const SizedBox(width: 10),
                  Expanded(child: localCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiProviderDropdown(AppLocalizations l10n) {
    return ListTile(
      leading: const Icon(Icons.hub_outlined),
      title: Text(l10n.aiProviderLabel),
      trailing: DropdownButton<AiProvider>(
        value: _app.aiProvider,
        underline: const SizedBox.shrink(),
        onChanged: (value) async {
          if (value == null) return;
          if (value == AiProvider.quillCloud) {
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
          }
          try {
            await _app.setAiProvider(value);
            if (!mounted) return;
            _rebuild(() {
              _availableModels = _app.cachedAiModelsFor(value);
            });
            if (_availableModels.isNotEmpty &&
                !_availableModels.contains(_app.aiModel)) {
              await _app.setAiModel(_availableModels.first);
            }
            _aiBaseUrlController.text = _app.defaultUrlForProvider(value);
            await _saveAiFields();
            if (value == AiProvider.quillCloud) {
              await _loadAiModels();
            }
            if (value == AiProvider.geminiNano) {
              await _refreshOnDeviceAiInfo(force: true);
            }
          } catch (e) {
            if (!mounted) return;
            _snack(l10n.settingsAiProviderSwitchFailed('$e'));
          }
        },
        items: [
          DropdownMenuItem(
            value: AiProvider.none,
            child: Text(l10n.aiProviderNone),
          ),
          if (aiLocalProvidersSupported) ...[
            DropdownMenuItem(
              value: AiProvider.ollama,
              child: Text(l10n.aiProviderOllamaName),
            ),
            DropdownMenuItem(
              value: AiProvider.lmStudio,
              child: Text(l10n.aiProviderLmStudioName),
            ),
          ],
          if (aiOnDeviceProviderSupported)
            DropdownMenuItem(
              value: AiProvider.geminiNano,
              child: Text(_onDeviceProviderLabel(l10n)),
            ),
          const DropdownMenuItem(
            value: AiProvider.openAi,
            child: Text('OpenAI'),
          ),
          const DropdownMenuItem(
            value: AiProvider.gemini,
            child: Text('Gemini'),
          ),
          const DropdownMenuItem(
            value: AiProvider.quillCloud,
            child: Text('Quill Cloud'),
          ),
        ],
      ),
    );
  }

  Widget _buildOnDeviceAiStatusTile(AppLocalizations l10n, ColorScheme scheme) {
    final status = _onDeviceAiStatus;
    final String statusLabel;
    switch (status) {
      case OnDeviceAiStatus.available:
        statusLabel = l10n.aiOnDeviceStatusAvailable;
      case OnDeviceAiStatus.downloadable:
        statusLabel = l10n.aiOnDeviceStatusDownloadable;
      case OnDeviceAiStatus.downloading:
        statusLabel = l10n.aiOnDeviceStatusDownloading;
      case OnDeviceAiStatus.unavailable:
      case null:
        statusLabel = l10n.aiOnDeviceStatusUnavailable;
    }
    final canDownload =
        status == OnDeviceAiStatus.downloadable && !_onDeviceAiBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(
            status == OnDeviceAiStatus.available
                ? Icons.check_circle_outline
                : Icons.smartphone_outlined,
          ),
          title: Text(_onDeviceProviderLabel(l10n)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusLabel),
              Text(
                l10n.aiOnDeviceHeroHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (_onDeviceAiBusy || status == OnDeviceAiStatus.downloading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
                if (_onDeviceDownloadBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.aiOnDeviceDownloadProgress(
                        '$_onDeviceDownloadBytes',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (canDownload)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.tonalIcon(
              onPressed: _downloadOnDeviceAiModel,
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.aiOnDeviceDownloadAction),
            ),
          ),
      ],
    );
  }

  Widget _buildAiModelDropdown(AppLocalizations l10n) {
    return ListTile(
      leading: const Icon(Icons.psychology_alt_outlined),
      title: Text(l10n.aiModel),
      subtitle: _loadingModels
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          : DropdownButton<String>(
              value: _availableModels.contains(_app.aiModel)
                  ? _app.aiModel
                  : null,
              hint: Text(l10n.aiConnectToListModels),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              onChanged: _availableModels.isEmpty
                  ? null
                  : (value) {
                      if (value != null) {
                        _app.setAiModel(value);
                      }
                    },
              items: _availableModels
                  .map(
                    (m) => DropdownMenuItem<String>(
                      value: m,
                      child: Text(m),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildQuillInstructionsBlock(AppLocalizations l10n, ColorScheme scheme) {
    return StatefulBuilder(
      builder: (context, setInnerState) {
        final prompts = _app.quillSystemPrompts;
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.psychology_alt_outlined),
              title: Text(l10n.settingsAiQuillInstructionsTitle),
              subtitle: Text(l10n.settingsAiQuillInstructionsSubtitle),
              trailing: FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.settingsAiQuillInstructionsNew),
                onPressed: () async {
                  await _showEditQuillPromptDialog(null);
                  setInnerState(() {});
                },
              ),
            ),
            const Divider(height: 1),
            ...prompts.map((item) {
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      item.isSystemDefault
                          ? FolioIcons.quill
                          : Icons.notes_rounded,
                      color: item.isSystemDefault
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    title: Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      item.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            item.isSystemDefault
                                ? Icons.visibility_outlined
                                : Icons.edit_outlined,
                            size: 20,
                          ),
                          tooltip: item.isSystemDefault
                              ? l10n.settingsAiQuillInstructionsView
                              : l10n.settingsAiQuillInstructionsEdit,
                          onPressed: () async {
                            await _showEditQuillPromptDialog(
                              item,
                              readOnly: item.isSystemDefault,
                            );
                            setInnerState(() {});
                          },
                        ),
                        if (!item.isSystemDefault)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: scheme.error,
                            ),
                            tooltip: l10n.settingsAiQuillInstructionsDelete,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => FolioDialog(
                                  title: Text(
                                    l10n.settingsAiQuillInstructionsDeleteTitle,
                                  ),
                                  content: Text(
                                    l10n.settingsAiQuillInstructionsDeleteBody(
                                      item.name,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: scheme.error,
                                        foregroundColor: scheme.onError,
                                      ),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _app.deleteQuillSystemPrompt(item.id);
                                setInnerState(() {});
                                if (mounted) _rebuild(() {});
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildAiSettingsSection({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required bool aiLocalProvidersSupported,
    required bool mcpServerSupported,
    required bool showDesktopOnlySections,
  }) {
    final showCompareExpanded =
        !_app.aiEnabled || _app.aiProvider == AiProvider.none;
    final showModelInBasic =
        _app.aiProvider == AiProvider.ollama ||
        _app.aiProvider == AiProvider.lmStudio ||
        _app.aiProvider == AiProvider.openAi ||
        _app.aiProvider == AiProvider.gemini;
    final isOnDevice = _app.aiProvider == AiProvider.geminiNano;
    final heroChips = <_SettingsInfoChip>[
      _SettingsInfoChip(
        icon: _app.aiEnabled ? Icons.check_circle_outline : Icons.pause_circle_outline,
        label: _app.aiEnabled ? l10n.active : l10n.inactive,
      ),
      _SettingsInfoChip(
        icon: Icons.hub_outlined,
        label: _providerLabel(_app.aiProvider, l10n),
      ),
      if (showModelInBasic && _app.aiModel.trim().isNotEmpty)
        _SettingsInfoChip(
          icon: Icons.psychology_outlined,
          label: _app.aiModel,
        ),
    ];

    return _SettingsPanel(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          _SettingsPanelHeroCard(
            icon: FolioIcons.quillOutlined,
            title: l10n.ai,
            description: _app.aiProvider == AiProvider.quillCloud
                ? (aiLocalProvidersSupported
                      ? l10n.settingsAiHeroQuillWithLocalAlt
                      : l10n.settingsAiHeroQuillCloudOnly)
                : isOnDevice
                ? l10n.aiOnDeviceHeroHint
                : (aiLocalProvidersSupported
                      ? l10n.settingsAiHeroLocalDefault
                      : l10n.settingsAiHeroQuillMobileOnly),
            chips: heroChips,
          ),

          // ── Básico ──
          _aiSettingsSectionHeader(l10n.settingsAiSectionBasic),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: showCompareExpanded
                ? _buildAiCloudVsLocalCompare(
                    l10n,
                    scheme,
                    aiLocalProvidersSupported: aiLocalProvidersSupported,
                  )
                : Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(l10n.settingsAiCompareExpandTitle),
                      children: [
                        _buildAiCloudVsLocalCompare(
                          l10n,
                          scheme,
                          aiLocalProvidersSupported: aiLocalProvidersSupported,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(FolioIcons.quillOutlined),
            title: Text(l10n.aiEnableToggleTitle),
            subtitle: Text(_app.aiEnabled ? l10n.active : l10n.inactive),
            value: _app.aiEnabled,
            onChanged: _detectingAiProvider
                ? null
                : (v) async {
                    if (v && !_app.aiEnabled) {
                      final acceptedScope =
                          await _confirmQuillGlobalScopeIfNeeded();
                      if (!acceptedScope) return;
                      if (!_app.hasCompletedQuillSetup) {
                        if (aiLocalProvidersSupported) {
                          final configured =
                              await _autoDetectAndConfigureAiProvider();
                          if (!configured) return;
                        } else if (aiOnDeviceProviderSupported) {
                          final selected = await _askUserProviderChoice();
                          if (selected == null) return;
                          await _app.setAiProvider(selected);
                          if (selected == AiProvider.geminiNano) {
                            await _refreshOnDeviceAiInfo(force: true);
                          }
                          await _saveAiFields();
                        }
                        await _app.setHasCompletedQuillSetup(true);
                      }
                      await _saveAiFields();
                      await _app.setAiEnabled(true);
                      return;
                    }
                    await _saveAiFields();
                    await _app.setAiEnabled(v);
                  },
          ),
          if (_detectingAiProvider)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(),
            ),
          if (aiLocalProvidersSupported &&
              (_app.aiProvider == AiProvider.ollama ||
                  _app.aiProvider == AiProvider.lmStudio)) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.assistant_navigation),
              title: Text(l10n.aiSetupAssistantTitle),
              subtitle: Text(l10n.aiSetupAssistantSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _detectingAiProvider
                  ? null
                  : _autoDetectAndConfigureAiProvider,
            ),
          ],
          const Divider(height: 1),
          _buildAiProviderDropdown(l10n),
          if (isOnDevice) ...[
            const Divider(height: 1),
            _buildOnDeviceAiStatusTile(l10n, scheme),
          ],
          if (showModelInBasic) ...[
            const Divider(height: 1),
            _buildAiModelDropdown(l10n),
          ],

          // ── Experiencia Quill ──
          _aiSettingsSectionHeader(l10n.settingsAiSectionExperience),
          SwitchListTile(
            secondary: const Icon(Icons.psychology_outlined),
            title: Text(l10n.aiAlwaysShowThought),
            subtitle: Text(l10n.aiAlwaysShowThoughtHint),
            value: _app.aiAlwaysShowThought,
            onChanged: _app.aiEnabled ? _app.setAiAlwaysShowThought : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.view_column_outlined),
            title: Text(l10n.settingsAiChatSplitViewTitle),
            subtitle: Text(l10n.settingsAiChatSplitViewSubtitle),
            value: _app.aiChatSplitView,
            onChanged: _app.aiEnabled
                ? (v) async {
                    await _app.setAiChatSplitView(v);
                    if (mounted) _rebuild(() {});
                  }
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_fix_high_outlined),
            title: Text(l10n.settingsAiQuillCopilotExperimentalTitle),
            subtitle: Text(l10n.settingsAiQuillCopilotExperimentalSubtitle),
            value: _app.aiQuillCopilotExperimental,
            onChanged: _app.aiEnabled
                ? (v) async {
                    await _app.setAiQuillCopilotExperimental(v);
                    if (mounted) _rebuild(() {});
                  }
                : null,
          ),
          const Divider(height: 1),
          _buildQuillInstructionsBlock(l10n, scheme),

          // ── Avanzado ──
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              title: Text(
                l10n.settingsAiSectionAdvanced,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: [
                if (mcpServerSupported)
                  _buildMcpServerToggle(context)
                else if (kIsWeb)
                  WebDesktopOnlyNotice(
                    icon: Icons.memory_outlined,
                    title: l10n.settingsMcpServerTitle,
                  ),
                if (aiLocalProvidersSupported &&
                    _app.aiProvider != AiProvider.quillCloud &&
                    _app.aiProvider != AiProvider.geminiNano) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.rocket_launch_outlined),
                    title: Text(l10n.aiLaunchProviderWithApp),
                    subtitle: Text(l10n.aiLaunchProviderWithAppHint),
                    value: _app.aiLaunchProviderWithApp,
                    onChanged: _app.aiEnabled
                        ? (v) async {
                            await _app.setAiLaunchProviderWithApp(v);
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.memory_outlined),
                    title: Text(l10n.aiContextWindowTokens),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aiContextWindowTokensHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        TextField(
                          controller: _aiContextWindowController,
                          enabled: _app.aiEnabled,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '131072',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _saveAiFields(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showModelInBasic) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: Text(l10n.aiEndpoint),
                    subtitle: TextField(
                      controller: _aiBaseUrlController,
                      decoration: const InputDecoration(
                        hintText: 'http://127.0.0.1:11434',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _saveAiFields(),
                    ),
                  ),
                  if (_app.aiProvider == AiProvider.openAi ||
                      _app.aiProvider == AiProvider.gemini) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.key_rounded),
                      title: Text(l10n.aiApiKeyLabel),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _aiApiKeyController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: l10n.aiApiKeyHint,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _saveAiFields(),
                          ),
                          if (_app.aiProvider == AiProvider.gemini)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                l10n.aiApiKeyGeminiHelp,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          if (_app.aiProvider == AiProvider.openAi)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                l10n.aiApiKeyOpenAiHelp,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(l10n.aiTimeoutMs),
                    subtitle: TextField(
                      controller: _aiTimeoutController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '30000',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _saveAiFields(),
                    ),
                  ),
                  if (_app.aiProvider == AiProvider.ollama ||
                      _app.aiProvider == AiProvider.lmStudio) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.public_outlined),
                      title: Text(l10n.aiAllowRemoteEndpoint),
                      subtitle: Text(
                        _app.aiEndpointMode == AiEndpointMode.allowRemote
                            ? l10n.aiAllowRemoteEndpointAllowed
                            : l10n.aiAllowRemoteEndpointLocalhostOnly,
                      ),
                      value:
                          _app.aiEndpointMode == AiEndpointMode.allowRemote,
                      onChanged: (v) async {
                        await _app.setAiEndpointMode(
                          v
                              ? AiEndpointMode.allowRemote
                              : AiEndpointMode.localhostOnly,
                        );
                        if (v) {
                          await _confirmRemoteEndpointIfNeeded();
                        }
                      },
                    ),
                    if (_app.aiEndpointMode == AiEndpointMode.allowRemote &&
                        !_app.aiRemoteEndpointConfirmed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          l10n.aiAllowRemoteEndpointNotConfirmed,
                          style: TextStyle(color: scheme.tertiary),
                        ),
                      ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.network_check_rounded),
                    title: Text(l10n.aiConnectToListModels),
                    onTap: _testAiConnection,
                  ),
                ],
                if (isOnDevice) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(l10n.aiTimeoutMs),
                    subtitle: TextField(
                      controller: _aiTimeoutController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '30000',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _saveAiFields(),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.network_check_rounded),
                    title: Text(l10n.aiConnectToListModels),
                    onTap: _testAiConnection,
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (showDesktopOnlySections)
            _buildMeetingNoteSettingsBlock(
              l10n: l10n,
              scheme: scheme,
            ),
        ],
      ),
    );
  }
}
