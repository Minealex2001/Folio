part of 'workspace_page.dart';

extension _WorkspacePageAiChatModule on _WorkspacePageState {
  Future<void> _sendAiChat() async {
    if (_aiChatBusy) return;
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    final targetChat = _activeChat;
    final targetChatId = targetChat.id;
    final includePageContext = targetChat.includePageContext;
    final contextPageIds = List<String>.from(targetChat.contextPageIds);
    final userMessage = AiChatMessage.now(role: 'user', content: text);
    final threadMessages = List<AiChatMessage>.from(targetChat.messages)
      ..add(userMessage);
    _setStateSafe(() => _aiChatBusy = true);
    _scheduleAiChatScrollToBottom();
    try {
      await _s.pingAi();
    } catch (e) {
      if (mounted) {
        _setStateSafe(() => _aiChatBusy = false);
        final l10n = AppLocalizations.of(context);
        final msg = e is AiServiceUnreachableException
            ? l10n.aiServiceUnreachable
            : l10n.aiErrorWithDetails(e);
        _snack(msg, error: true);
      }
      return;
    }
    if (!mounted) return;
    _setStateSafe(() {
      _chatInputController.clear();
    });
    // Recalcular estimación tras limpiar, para que no quede "pegada".
    _updateInkEstimateFromComposer();
    _s.appendMessageToAiChatById(targetChatId, userMessage);
    try {
      final outcome = await _runAiFromChat(
        text,
        threadMessages,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
      );
      if (!mounted) return;
      if (_activeChat.id == targetChatId) {
        _setStateSafe(() => _lastChatTokenUsage = outcome.usage);
      }
      _s.appendMessageToAiChatById(
        targetChatId,
        AiChatMessage.now(role: 'assistant', content: outcome.reply),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (e is FolioCloudAiException && e.isInkExhausted) {
        await showFolioCloudAiInkExhaustedDialog(
          context,
          onOpenSettings: _openSettings,
          onOpenFolioCloudPitch: _openFolioCloudSubscriptionPitch,
        );
      } else {
        _snack(l10n.aiErrorWithDetails(e), error: true);
      }
    } finally {
      if (mounted) {
        _setStateSafe(() => _aiChatBusy = false);
      }
    }
  }

  Future<AgentChatOutcome> _runAiFromChat(
    String text,
    List<AiChatMessage> threadMessages, {
    required bool includePageContext,
    required List<String> contextPageIds,
  }) async {
    final t = text.trim();
    final languageCode = Localizations.localeOf(context).languageCode;
    final attachments = await _collectAiAttachments();
    final isCloudProvider =
        widget.appSettings.aiProvider == AiProvider.quillCloud;
    final op = isCloudProvider ? _aiInkEstimateOperationKind : null;
    return _s.agentChatWithAi(
      messages: threadMessages,
      prompt: t,
      scopePageId: _s.selectedPageId,
      includePageContext: includePageContext,
      contextPageIds: contextPageIds,
      attachments: attachments,
      languageCode: languageCode,
      cloudInkOperation: op,
    );
  }
}

