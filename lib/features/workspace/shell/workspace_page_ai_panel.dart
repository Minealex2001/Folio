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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Handle keyboard navigation when context menu is open
    if (_aiContextMenuOverlay != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _setStateSafe(() {
          _aiContextMenuSelectedIndex = math.max(
            0,
            _aiContextMenuSelectedIndex - 1,
          );
          _aiContextMenuUsingKeyboard = true;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final l10n = AppLocalizations.of(context);
        final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
        _setStateSafe(() {
          _aiContextMenuSelectedIndex = math.min(
            suggestions.length - 1,
            _aiContextMenuSelectedIndex + 1,
          );
          _aiContextMenuUsingKeyboard = true;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final l10n = AppLocalizations.of(context);
        final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
        if (_aiContextMenuSelectedIndex >= 0 &&
            _aiContextMenuSelectedIndex < suggestions.length) {
          _applyAiContextSuggestion(suggestions[_aiContextMenuSelectedIndex]);
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
    final textColor = scheme.onSurface;
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
              Icons.smart_toy_outlined,
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
                child: FolioAiTypingIndicator(
                  color: textColor.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiChatContextRow(
    ThemeData theme,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final u = _lastChatTokenUsage;
    final window = math.max(1, widget.appSettings.aiContextWindowTokens);
    final prompt = u?.promptTokens;
    if (prompt == null) {
      return Text(
        l10n.aiContextUsageUnavailable,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    final frac = math.min(1.0, prompt / window);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: l10n.aiContextUsageTooltip(window),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FolioRadius.xs),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.aiContextUsageSummary(
            _formatTokenCount(prompt),
            _formatTokenCount(u!.completionTokens),
          ),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
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
              Icons.chat_bubble_rounded,
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
            initialChildSize: 0.92,
            minChildSize: 0.38,
            maxChildSize: 0.98,
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
          child: _buildCollabFabIcon(Theme.of(context).colorScheme),
        ),
      if (collabEnabled && aiEnabled) const SizedBox(width: 12),
      if (aiEnabled)
        FloatingActionButton.small(
          heroTag: 'mobile_quill_chat_fab',
          tooltip: l10n.aiShowPanel,
          onPressed: () => unawaited(_openMobileAiChatSheet()),
          child: const Icon(Icons.chat_bubble_rounded),
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
    final isCloudProvider =
        widget.appSettings.aiProvider == AiProvider.quillCloud;
    final showInkInChat =
        isCloudProvider &&
        widget.appSettings.isAiRuntimeEnabled &&
        widget.folioCloudEntitlements.snapshot.canUseCloudAi;
    final inkSnap = widget.folioCloudEntitlements.snapshot.ink;
    const lowInkThreshold = 20;
    final estInkCost = _inkCostForOperationKind(_aiInkEstimateOperationKind);
    final inkLooksLow =
        showInkInChat &&
        inkSnap.totalInk > 0 &&
        inkSnap.totalInk <= lowInkThreshold;
    final inkLooksEmpty = showInkInChat && inkSnap.totalInk <= 0;

    String providerLabel() {
      switch (widget.appSettings.aiProvider) {
        case AiProvider.none:
          return _t('Sin configurar', 'Not set');
        case AiProvider.quillCloud:
          return 'Folio Cloud';
        case AiProvider.ollama:
          return 'Ollama';
        case AiProvider.lmStudio:
          return 'LM Studio';
      }
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: ColoredBox(
        color: scheme.surface,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainerHighest,
                    scheme.surfaceContainerHigh,
                  ],
                ),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                borderRadius: BorderRadius.circular(FolioRadius.xl),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer,
                          scheme.tertiaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.aiAssistantTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l10n.aiBetaBadge,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    border: Border.all(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.40,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isCloudProvider
                                            ? Icons.cloud_outlined
                                            : Icons.computer_outlined,
                                        size: 14,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        providerLabel(),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _aiPanelContextSubtitle(l10n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.95,
                            ),
                            height: 1.35,
                          ),
                        ),
                        if (showInkInChat) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Tooltip(
                                message: l10n.aiChatInkBreakdownTooltip(
                                  inkSnap.monthlyBalance,
                                  inkSnap.purchasedBalance,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: inkLooksLow
                                        ? scheme.tertiaryContainer.withValues(
                                            alpha: 0.65,
                                          )
                                        : scheme.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.water_drop_outlined,
                                        size: 16,
                                        color: inkLooksLow
                                            ? scheme.onTertiaryContainer
                                            : scheme.primary.withValues(
                                                alpha: 0.92,
                                              ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          l10n.aiChatInkRemaining(
                                            inkSnap.totalInk,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: inkLooksLow
                                                    ? scheme.onTertiaryContainer
                                                    : scheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (inkLooksEmpty) ...[
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: _openSettings,
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: Text(_t('Comprar tinta', 'Buy ink')),
                            ),
                          ],
                        ],
                      ],
                    ),
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
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _s.aiChatThreads.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final active = i == _s.aiActiveChatIndex;
                        return ChoiceChip(
                          label: Text(
                            _s.aiChatThreads[i].title,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: active,
                          visualDensity: VisualDensity.compact,
                          onSelected: _aiChatBusy
                              ? null
                              : (_) {
                                  _s.syncActiveAiChatAttachmentPaths(
                                    _aiAttachmentPaths,
                                  );
                                  _setStateSafe(() => _lastChatTokenUsage = null);
                                  _s.selectAiChat(i);
                                },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: l10n.aiRenameChatTooltip,
                    onPressed: _aiChatBusy ? null : _showRenameActiveChatDialog,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: l10n.aiDeleteCurrentChat,
                    onPressed: _aiChatBusy ? null : _deleteActiveChat,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const SizedBox(width: 2),
                  FilledButton.tonal(
                    onPressed: _aiChatBusy ? null : _createNewChat,
                    child: Text(l10n.aiNewChat),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(FolioRadius.xl),
                ),
                child: Builder(
                  builder: (context) {
                    final msgs = _activeChat.messages;
                    final showChatList = msgs.isNotEmpty || _aiChatBusy;
                    if (!showChatList) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(
                                          alpha: 0.10,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.forum_outlined,
                                        color: scheme.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.aiChatEmptyHint,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.55,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
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
                    final typingExtra = _aiChatBusy ? 1 : 0;
                    return ListView.builder(
                      controller:
                          chatListScrollController ?? _aiChatScrollController,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                      itemCount: msgs.length + typingExtra,
                      itemBuilder: (context, i) {
                        if (_aiChatBusy && i == msgs.length) {
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
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAiChatContextRow(theme, scheme, l10n),
                  const SizedBox(height: 4),
                  Text(
                    l10n.aiChatKeyboardHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.surfaceContainerHighest, scheme.surface],
                  ),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.40),
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showInkInChat) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: 2,
                          bottom: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.water_drop_outlined,
                              size: 16,
                              color: inkLooksLow
                                  ? scheme.tertiary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _t(
                                  'Coste estimado: $estInkCost gotas.',
                                  'Estimated cost: $estInkCost ink.',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.92,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (inkLooksLow || inkLooksEmpty) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _openSettings,
                                child: Text(_t('Tinta', 'Ink')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    Builder(
                      builder: (context) {
                        final items = _buildActiveAiContextItems(l10n);
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              top: 4,
                            ),
                            child: Text(
                              l10n.aiContextComposerHint,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            top: 4,
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: items
                                .map(
                                  (item) => InputChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: Icon(
                                      _iconForAiContextItem(item.kind),
                                      size: 16,
                                    ),
                                    label: Text(item.label),
                                    onDeleted:
                                        item.kind == _AiContextItemKind.addFile
                                        ? null
                                        : () => _removeAiContextItem(item),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                    CompositedTransformTarget(
                      link: _aiComposerLayerLink,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _openCloudContextPickerFromButton,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              tooltip: l10n.aiAttach,
                              padding: const EdgeInsets.all(12),
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Focus(
                                  onKeyEvent: _onChatInputKey,
                                  child: TextField(
                                    focusNode: _chatInputFocusNode,
                                    controller: _chatInputController,
                                    minLines: 1,
                                    maxLines: 5,
                                    onTap: _updateAiContextMenu,
                                    onChanged: (_) {
                                      _updateAiContextMenu();
                                      _updateInkEstimateFromComposer();
                                    },
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: l10n.aiInputHintCopilot,
                                      helperText: l10n.aiContextComposerHelper,
                                      helperMaxLines: 2,
                                      isDense: true,
                                      hintStyle: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant
                                                .withValues(alpha: 0.85),
                                          ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _aiChatBusy ? null : _sendAiChat,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                              child: _aiChatBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 20,
                                    ),
                            ),
                          ],
                        ),
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


}

