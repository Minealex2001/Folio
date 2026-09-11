part of 'workspace_page.dart';

extension _WorkspacePageAiPanelModule on _WorkspacePageState {
  String _formatTokenCount(int? n) {
    if (n == null) return '—';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(2)}k';
    return n.toString();
  }

  void _insertNewlineInChatInput() {
    final c = _chatInputController;
    final sel = c.selection;
    if (!sel.isValid) {
      c.text = '${c.text}\n';
      c.selection = TextSelection.collapsed(offset: c.text.length);
      return;
    }
    final t = c.text;
    final start = sel.start;
    final end = sel.end;
    final newText = t.replaceRange(start, end, '\n');
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  KeyEventResult _onChatInputKey(FocusNode node, KeyEvent event) {
    if (!widget.session.aiEnabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Handle keyboard navigation when context menu is open
    if (_aiContextMenuOverlay != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _aiContextMenuSelectedIndex = math.max(
          0,
          _aiContextMenuSelectedIndex - 1,
        );
        _aiContextMenuUsingKeyboard = true;
        _aiContextMenuOverlay?.markNeedsBuild();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final l10n = AppLocalizations.of(context);
        final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
        _aiContextMenuSelectedIndex = math.min(
          suggestions.length - 1,
          _aiContextMenuSelectedIndex + 1,
        );
        _aiContextMenuUsingKeyboard = true;
        _aiContextMenuOverlay?.markNeedsBuild();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final l10n = AppLocalizations.of(context);
        final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
        if (_aiContextMenuSelectedIndex >= 0 &&
            _aiContextMenuSelectedIndex < suggestions.length) {
          unawaited(
            _applyAiContextSuggestion(suggestions[_aiContextMenuSelectedIndex]),
          );
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideAiContextMenu();
        return KeyEventResult.handled;
      }
    }

    // Regular enter key handling
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      _insertNewlineInChatInput();
      return KeyEventResult.handled;
    }
    unawaited(_sendAiChat());
    return KeyEventResult.handled;
  }

  Widget _buildAiTypingRow(
    ThemeData theme,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FolioIcons.quill,
              size: 16,
              color: scheme.onSecondaryContainer,
            ),
          ),
          Flexible(
            child: Semantics(
              label: l10n.aiTypingSemantics,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(
                    FolioRadius.lg,
                  ).copyWith(topLeft: Radius.zero),
                ),
                child: _aiToolTrace.isNotEmpty
                    ? ToolInspectorPanel(
                        steps: _aiToolTrace,
                        colorScheme: scheme,
                      )
                    : FolioAiChatReplySkeleton(colorScheme: scheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAiChatHeaderDetailsSheet({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme scheme,
    required bool showInkInChat,
    required bool isCloudProvider,
    required FolioInkSnapshot inkSnap,
    required bool inkUnlimited,
    required bool inkLooksLow,
    required bool inkLooksEmpty,
    required String Function() providerLabel,
    required int estInkCost,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.aiChatHeaderDetailsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(FolioIcons.quillOutlined),
                  title: Text(l10n.aiAssistantSubtitle),
                  subtitle: Text(l10n.aiGeneratedLabel),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isCloudProvider
                        ? Icons.cloud_outlined
                        : Icons.computer_outlined,
                  ),
                  title: Text(l10n.aiChatHeaderProviderSection),
                  subtitle: Text(providerLabel()),
                ),
                if (showInkInChat) ...[
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.water_drop_outlined,
                      color: inkLooksLow
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      inkUnlimited
                          ? '∞'
                          : l10n.aiChatInkRemaining(inkSnap.totalInk),
                    ),
                    subtitle: Text(
                      inkUnlimited
                          ? l10n.workspaceHomeCloudStaffShort
                          : l10n.aiChatInkBreakdownTooltip(
                              inkSnap.monthlyBalance,
                              inkSnap.purchasedBalance,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aiChatInkEstimatedCost(estInkCost),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox.shrink(),
                if (inkLooksEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openSettings();
                    },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(l10n.folioCloudBuyInk),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiCollapsedFab(BuildContext context, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.aiShowPanel,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _applyAiChatPanelCollapsed(false),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              FolioIcons.quill,
              color: scheme.onPrimaryContainer,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMobileAiChatSheet() async {
    if (!mounted) return;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) {
              _mobileSheetChatScroll = scrollController;
              final theme = Theme.of(ctx);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: _buildAiPanel(
                          ctx,
                          onRequestClosePanel: () =>
                              Navigator.of(sheetContext).pop(),
                          chatListScrollController: scrollController,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _mobileSheetChatScroll = null;
    }
  }

  Widget _wrapWithMobileDockFabsIfNeeded({
    required bool aiEnabled,
    required bool collabEnabled,
    required AppLocalizations l10n,
    required Widget child,
  }) {
    if (!aiEnabled && !collabEnabled) return child;
    final dockFabs = <Widget>[
      if (collabEnabled)
        FloatingActionButton.small(
          heroTag: 'mobile_collab_room_fab',
          tooltip: l10n.collabMenuAction,
          onPressed: () => unawaited(_openCollaborationSheet()),
          child: ListenableBuilder(
            listenable: _collab,
            builder: (context, _) =>
                _buildCollabFabIcon(Theme.of(context).colorScheme),
          ),
        ),
      if (collabEnabled && aiEnabled) const SizedBox(width: 12),
      if (aiEnabled)
        FloatingActionButton.small(
          heroTag: 'mobile_quill_chat_fab',
          tooltip: l10n.aiShowPanel,
          onPressed: () => unawaited(_openMobileAiChatSheet()),
          child: const Icon(FolioIcons.quill),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: dockFabs),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildAiPanel(
    BuildContext context, {
    VoidCallback? onRequestClosePanel,
    ScrollController? chatListScrollController,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.sizeOf(context);
    final layoutMode = QuillChatLayout.resolve(
      viewportWidth: media.width,
      splitView: widget.appSettings.aiChatSplitView,
      forceMobile: media.width < FolioDesktop.compactBreakpoint,
    );
    final flatChrome = QuillChatLayout.useFlatChrome(layoutMode);
    final isCloudProvider =
        widget.appSettings.aiProvider == AiProvider.quillCloud;
    final showInkInChat =
        isCloudProvider &&
        widget.appSettings.isAiRuntimeEnabled &&
        widget.folioCloudEntitlements.snapshot.canUseCloudAi;
    final cloudSnap = widget.folioCloudEntitlements.snapshot;
    final inkSnap = cloudSnap.ink;
    final inkUnlimited = cloudSnap.folioStaff;
    const lowInkThreshold = 20;
    final estInkCost = _inkCostForOperationKind(_aiInkEstimateOperationKind);
    final inkLooksLow =
        showInkInChat &&
        !inkUnlimited &&
        inkSnap.totalInk > 0 &&
        inkSnap.totalInk <= lowInkThreshold;
    final inkLooksEmpty =
        showInkInChat && !inkUnlimited && inkSnap.totalInk <= 0;
    final showSplitToggle =
        layoutMode == QuillChatLayoutMode.dockNarrow ||
        layoutMode == QuillChatLayoutMode.dockWide ||
        layoutMode == QuillChatLayoutMode.split;

    String providerLabel() {
      switch (widget.appSettings.aiProvider) {
        case AiProvider.none:
          return l10n.aiProviderNotSet;
        case AiProvider.quillCloud:
          return 'Quill Cloud';
        case AiProvider.ollama:
          return l10n.aiProviderOllamaName;
        case AiProvider.lmStudio:
          return l10n.aiProviderLmStudioName;
        case AiProvider.openAi:
          return 'OpenAI';
        case AiProvider.gemini:
          return 'Gemini';
        case AiProvider.geminiNano:
          switch (OnDeviceAiBridge.cachedBrandOrDefault) {
            case OnDeviceAiBrand.samsung:
              return l10n.aiProviderGalaxyAiByGemini;
            case OnDeviceAiBrand.google:
            case OnDeviceAiBrand.other:
              return l10n.aiProviderGeminiNano;
          }
      }
    }

    final aiReady = widget.session.aiEnabled;
    final threadCount = _s.aiChatThreads.length;
    final activeIdx = threadCount == 0
        ? 0
        : _s.aiActiveChatIndex.clamp(0, threadCount - 1);
    final activeTitle = threadCount == 0
        ? l10n.aiAssistantTitle
        : _s.aiChatThreads[activeIdx].title;
    final headerPad = layoutMode == QuillChatLayoutMode.mobile ? 12.0 : 10.0;
    final edgeRadius = flatChrome ? FolioRadius.md : FolioRadius.lg;
    final contextItems = _buildActiveAiContextItems(l10n);
    final tokenUsage = _lastChatTokenUsage;
    final tokenWindow = math.max(1, widget.appSettings.aiContextWindowTokens);

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: ColoredBox(
        color: scheme.surface,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(headerPad, headerPad, 4, 4),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(FolioRadius.sm),
                    ),
                    child: Icon(
                      FolioIcons.quill,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          l10n.aiAssistantSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.aiManageQuillInstructionsTooltip,
                    onPressed: () => _openSettings(initialSection: 'ai'),
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: l10n.aiChatHeaderMenuTooltip,
                    onPressed: () => unawaited(
                      _showAiChatHeaderDetailsSheet(
                        l10n: l10n,
                        theme: theme,
                        scheme: scheme,
                        showInkInChat: showInkInChat,
                        isCloudProvider: isCloudProvider,
                        inkSnap: inkSnap,
                        inkUnlimited: inkUnlimited,
                        inkLooksLow: inkLooksLow,
                        inkLooksEmpty: inkLooksEmpty,
                        providerLabel: providerLabel,
                        estInkCost: estInkCost,
                      ),
                    ),
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (showSplitToggle)
                    IconButton(
                      tooltip: l10n.aiChatSplitViewTooltip,
                      onPressed: () async {
                        final v = !widget.appSettings.aiChatSplitView;
                        await widget.appSettings.setAiChatSplitView(v);
                        if (!mounted) return;
                        _setStateSafe(() {});
                      },
                      icon: Icon(
                        widget.appSettings.aiChatSplitView
                            ? Icons.view_column_rounded
                            : Icons.view_sidebar_rounded,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    tooltip: l10n.aiHidePanel,
                    onPressed: () {
                      if (onRequestClosePanel != null) {
                        onRequestClosePanel();
                      } else {
                        _applyAiChatPanelCollapsed(true);
                      }
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (!aiReady)
              Container(
                margin: EdgeInsets.fromLTRB(headerPad, 0, headerPad, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: scheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCloudProvider
                            ? l10n.aiProviderNotReadyCloud
                            : l10n.aiProviderNotReadyLocal,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: _openSettings,
                      color: scheme.onErrorContainer,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            if (_planModeEnabled)
              Container(
                margin: EdgeInsets.fromLTRB(headerPad, 0, headerPad, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.aiPlanModeActiveBanner,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(headerPad, 0, headerPad, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(FolioRadius.md),
                      onTap: _aiChatBusy
                          ? null
                          : () => unawaited(_showAiThreadsPickerSheet()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(FolioRadius.md),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: l10n.aiRenameChatTooltip,
                    onPressed: _aiChatBusy ? null : _showRenameActiveChatDialog,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: l10n.aiDeleteCurrentChat,
                    onPressed: _aiChatBusy ? null : _deleteActiveChat,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  FilledButton.tonal(
                    onPressed: _aiChatBusy ? null : _createNewChat,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(l10n.aiNewChat),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: headerPad),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: flatChrome
                      ? Border(
                          top: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                        )
                      : Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                  borderRadius: flatChrome
                      ? BorderRadius.zero
                      : BorderRadius.circular(edgeRadius),
                ),
                child: Builder(
                  builder: (context) {
                    final msgs = _activeChat.messages;
                    final showChatList = msgs.isNotEmpty || _aiChatBusy;
                    if (!showChatList) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      color: scheme.primary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.aiChatEmptyHint,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.55,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        _chatInputFocusNode.requestFocus();
                                      },
                                      child: Text(
                                        l10n.aiChatEmptyFocusComposer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                    // Si ya hay placeholder assistant en streaming, no duplicar
                    // la fila "typing" (skeleton) — eso mostraba dos burbujas.
                    final liveStreamAtEnd = msgs.isNotEmpty &&
                        _aiStreamingMessageKeys.contains(
                          '${_activeChat.id}#${msgs.length - 1}',
                        );
                    final typingExtra =
                        (_aiChatBusy && !liveStreamAtEnd) ? 1 : 0;
                    return ListView.builder(
                      controller:
                          chatListScrollController ?? _aiChatScrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: msgs.length + typingExtra,
                      itemBuilder: (context, i) {
                        if (_aiChatBusy && !liveStreamAtEnd && i == msgs.length) {
                          return _buildAiTypingRow(theme, scheme, l10n);
                        }
                        return _buildAiMessageRow(
                          context,
                          msgs[i],
                          i,
                          theme,
                          scheme,
                          l10n,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(headerPad, 8, headerPad, headerPad),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.40),
                  ),
                  borderRadius: BorderRadius.circular(edgeRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (tokenUsage?.promptTokens != null) ...[
                                  Tooltip(
                                    message: l10n.aiContextUsageTooltip(
                                      tokenWindow,
                                    ),
                                    child: _QuillComposerMetaChip(
                                      icon: Icons.memory_outlined,
                                      label: l10n.aiContextUsageSummary(
                                        _formatTokenCount(
                                          tokenUsage!.promptTokens,
                                        ),
                                        _formatTokenCount(
                                          tokenUsage.completionTokens,
                                        ),
                                      ),
                                      scheme: scheme,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (showInkInChat) ...[
                                  Tooltip(
                                    message: inkUnlimited
                                        ? l10n.workspaceHomeCloudStaffShort
                                        : l10n.aiChatInkBreakdownTooltip(
                                            inkSnap.monthlyBalance,
                                            inkSnap.purchasedBalance,
                                          ),
                                    child: _QuillComposerMetaChip(
                                      icon: Icons.water_drop_outlined,
                                      label: inkUnlimited
                                          ? '∞'
                                          : '${inkSnap.totalInk}',
                                      scheme: scheme,
                                      emphasize: inkLooksLow || inkLooksEmpty,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _QuillComposerMetaChip(
                                    icon: Icons.bolt_outlined,
                                    label: '~$estInkCost',
                                    scheme: scheme,
                                  ),
                                  if (inkLooksLow || inkLooksEmpty) ...[
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: _openSettings,
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(l10n.folioCloudBuyInk),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (contextItems.isEmpty)
                            Text(
                              l10n.aiContextComposerHelper,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 34,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: contextItems.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (context, i) {
                                  final item = contextItems[i];
                                  final isPageContext =
                                      item.kind ==
                                          _AiContextItemKind.currentPage ||
                                      item.kind == _AiContextItemKind.page;
                                  final chip = InputChip(
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.only(
                                      right: 6,
                                    ),
                                    avatar: Icon(
                                      _iconForAiContextItem(item.kind),
                                      size: 14,
                                    ),
                                    label: Text(
                                      item.label,
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    onDeleted:
                                        item.kind == _AiContextItemKind.addFile
                                        ? null
                                        : () => _removeAiContextItem(item),
                                  );
                                  if (!isPageContext) return chip;
                                  return Tooltip(
                                    message: l10n.aiContextMentionHint,
                                    child: chip,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    CompositedTransformTarget(
                      link: _aiComposerLayerLink,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: (_aiChatBusy || !aiReady)
                                ? null
                                : _openCloudContextPickerFromButton,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            tooltip: l10n.aiAttach,
                            visualDensity: VisualDensity.compact,
                            color: scheme.onSurfaceVariant,
                          ),
                          IconButton(
                            onPressed: (_aiChatBusy || !aiReady)
                                ? null
                                : _openGenerateImageSheet,
                            icon: const Icon(Icons.image_outlined),
                            tooltip: l10n.aiGenerateImageAction,
                            visualDensity: VisualDensity.compact,
                            color: scheme.onSurfaceVariant,
                          ),
                          IconButton(
                            onPressed: _aiChatBusy ? null : _togglePlanMode,
                            icon: Icon(
                              _planModeEnabled
                                  ? Icons.checklist_rtl_rounded
                                  : Icons.checklist_outlined,
                            ),
                            tooltip: l10n.aiPlanModeToggleTooltip,
                            visualDensity: VisualDensity.compact,
                            color: _planModeEnabled
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            style: _planModeEnabled
                                ? IconButton.styleFrom(
                                    backgroundColor: scheme.primaryContainer,
                                  )
                                : null,
                          ),
                          // Fase A5 del plan Quill/MCP — atajos nombrados
                          // hacia Plan-mode ("Workflows"), no un ejecutor
                          // nuevo. Primary Surface de disparo: este botón.
                          IconButton(
                            onPressed: (_aiChatBusy || !aiReady)
                                ? null
                                : _openQuillWorkflowsPicker,
                            icon: const Icon(Icons.auto_awesome_motion_outlined),
                            tooltip: l10n.quillWorkflowsPickerTooltip,
                            visualDensity: VisualDensity.compact,
                            color: scheme.onSurfaceVariant,
                          ),
                          if (_transcribingVoice)
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: FolioLoadingIndicator(
                                size: FolioLoadingSize.small,
                              ),
                            )
                          else
                            IconButton(
                              onPressed:
                                  !aiReady ? null : _toggleVoiceRecording,
                              icon: Icon(
                                _recordingVoice
                                    ? Icons.stop_circle_rounded
                                    : Icons.mic_rounded,
                                color: _recordingVoice
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                              tooltip: _recordingVoice
                                  ? l10n.aiDictationRecordingStopTooltip
                                  : l10n.aiDictationRecordingMicTooltip,
                              visualDensity: VisualDensity.compact,
                            ),
                          Expanded(
                            child: Focus(
                              onKeyEvent: _onChatInputKey,
                              child: TextField(
                                focusNode: _chatInputFocusNode,
                                controller: _chatInputController,
                                readOnly: _aiChatBusy || !aiReady,
                                minLines: 1,
                                maxLines: layoutMode ==
                                        QuillChatLayoutMode.mobile
                                    ? 4
                                    : 5,
                                onTap: _updateAiContextMenu,
                                onChanged: (_) {
                                  _updateAiContextMenu();
                                  _updateInkEstimateFromComposer();
                                },
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize:
                                      layoutMode == QuillChatLayoutMode.mobile
                                          ? 15
                                          : null,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: l10n.aiInputHintCopilot,
                                  isDense: true,
                                  hintStyle: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.85),
                                      ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: _aiChatBusy ? l10n.aiStopGenerating : '',
                            child: FilledButton(
                              onPressed: !aiReady
                                  ? null
                                  : _aiChatBusy
                                      ? _stopAiChat
                                      : _sendAiChat,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(40, 40),
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                              child: Icon(
                                _aiChatBusy
                                    ? Icons.stop_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoiceRecording() async {
    final l10n = AppLocalizations.of(context);
    if (_recordingVoice) {
      try {
        final path = await _audioRecorder.stop();
        _setStateSafe(() {
          _recordingVoice = false;
          _transcribingVoice = true;
        });
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            final chosenModel = widget.appSettings.meetingNoteModelId;
            try {
              await WhisperService.instance.ensureReady(
                modelId: chosenModel,
              );
            } catch (err) {
              _snack(l10n.aiDictationWhisperNotReady, error: true);
              _setStateSafe(() => _transcribingVoice = false);
              return;
            }

            if (!mounted) return;
            final text = await WhisperService.instance.transcribe(
              file,
              language: Localizations.localeOf(context).languageCode,
              modelId: chosenModel,
            );
            
            if (text.trim().isNotEmpty) {
              _setStateSafe(() {
                final currentText = _chatInputController.text;
                if (currentText.isEmpty) {
                  _chatInputController.text = text.trim();
                } else {
                  _chatInputController.text = '$currentText ${text.trim()}';
                }
              });
            } else {
              _snack(l10n.aiDictationNoVoiceDetected, error: true);
            }
            
            await file.delete().catchError((_) => File(''));
          }
        }
      } catch (e) {
        _snack(e.toString(), error: true);
      } finally {
        _setStateSafe(() {
          _transcribingVoice = false;
        });
      }
    } else {
      try {
        if (await _audioRecorder.hasPermission()) {
          final tempDir = await getTemporaryDirectory();
          final path = p.join(
            tempDir.path,
            'dictation_${DateTime.now().millisecondsSinceEpoch}.wav',
          );
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: path,
          );
          _setStateSafe(() {
            _recordingVoice = true;
          });
        } else {
          _snack(l10n.aiDictationMicError, error: true);
        }
      } catch (e) {
        _snack(e.toString(), error: true);
      }
    }
  }

  /// Entrada dedicada de "Generar imagen": prompt + toggle explícito de
  /// contexto de página (default OFF), separado del chat de tool-calling
  /// general — no depende de que el modelo decida invocar la tool.
  Future<void> _openGenerateImageSheet() async {
    final l10n = AppLocalizations.of(context);
    final ai = _s.aiService;
    if (ai == null) return;
    final promptController = TextEditingController(
      text: _chatInputController.text.trim(),
    );
    var useContext = false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final scheme = theme.colorScheme;
            final isCloudProvider =
                widget.appSettings.aiProvider == AiProvider.quillCloud;
            final inkCost = isCloudProvider
                ? _inkCostForOperationKind('generate_image')
                : null;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.aiGenerateImageSheetTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptController,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.aiGenerateImagePromptLabel,
                      hintText: l10n.aiGenerateImagePromptHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.aiGenerateImageUseContextLabel),
                    value: useContext,
                    onChanged: (v) => setSheetState(() => useContext = v),
                  ),
                  if (inkCost != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '~$inkCost 💧',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: () {
                      if (promptController.text.trim().isEmpty) {
                        _snack(l10n.aiGenerateImagePromptRequired, error: true);
                        return;
                      }
                      // Quitar el foco antes de cerrar la hoja: si el
                      // TextField sigue enfocado mientras se anima la salida
                      // y luego se dispone `promptController` (fuera de la
                      // hoja, ver más abajo), el cursor/overlay de selección
                      // puede seguir usando el controller ya liberado y
                      // corromper el frame ("TextEditingController was used
                      // after being disposed" — mismo patrón que
                      // sidebar.dart._renameActiveVault).
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(sheetContext).pop(true);
                    },
                    child: Text(l10n.aiGenerateImageGenerateButton),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Cubre también el cierre por gesto/toque fuera (sin pasar por el botón
    // "Generar" de arriba, que ya hace unfocus antes de su propio pop).
    FocusManager.instance.primaryFocus?.unfocus();
    if (confirmed != true || !mounted) {
      promptController.dispose();
      return;
    }
    final prompt = promptController.text.trim();
    promptController.dispose();
    await _submitGenerateImage(
      prompt: prompt,
      useCurrentPageContext: useContext,
    );
  }

  Future<void> _submitGenerateImage({
    required String prompt,
    required bool useCurrentPageContext,
  }) async {
    final l10n = AppLocalizations.of(context);
    final ai = _s.aiService;
    if (ai == null) return;
    if (!ai.supportsImageGeneration) {
      _snack(l10n.aiImageGenerationUnsupportedProvider, error: true);
      return;
    }
    final targetChatId = _activeChat.id;
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    _setStateSafe(() => _aiChatBusy = true);
    _s.appendMessageToAiChatById(
      targetChatId,
      AiChatMessage.now(role: 'assistant', content: ''),
    );
    final placeholderIndex = _activeChat.messages.length - 1;
    try {
      final message = await _s.generateImageForChatDirect(
        ai: ai,
        prompt: prompt,
        useCurrentPageContext: useCurrentPageContext,
        scopePageId: _s.selectedPageId,
        isEs: isEs,
      );
      if (!mounted) return;
      _s.updateMessageInAiChatById(targetChatId, placeholderIndex, message);
    } catch (e) {
      _s.removeMessageInAiChatById(targetChatId, placeholderIndex);
      if (!mounted) return;
      _handleAiChatError(e);
    } finally {
      if (mounted) {
        _setStateSafe(() => _aiChatBusy = false);
      }
    }
  }
}

class _QuillComposerMetaChip extends StatelessWidget {
  const _QuillComposerMetaChip({
    required this.icon,
    required this.label,
    required this.scheme,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final fg = emphasize ? scheme.tertiary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(FolioRadius.sm),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

