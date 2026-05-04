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
        AiChatMessage.now(
          role: 'assistant',
          content: outcome.reply,
          agentApplySnapshot: outcome.agentApplySnapshot,
        ),
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
    final extra = _composeAiExtraContextForNextSend();
    return _s.agentChatWithAi(
      messages: threadMessages,
      prompt: t,
      scopePageId: _s.selectedPageId,
      includePageContext: includePageContext,
      contextPageIds: contextPageIds,
      attachments: attachments,
      languageCode: languageCode,
      cloudInkOperation: op,
      extraContextSections: extra,
    );
  }

  String _composeAiExtraContextForNextSend() {
    final isEs = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('es');
    final b = StringBuffer();
    if (_aiAttachNextEditorSelection) {
      _aiAttachNextEditorSelection = false;
      final snippet = _readEditorSelectionPlainForAi();
      if (snippet != null && snippet.trim().isNotEmpty) {
        b.writeln(
          isEs ? '--- Selección del editor ---' : '--- Editor selection ---',
        );
        b.writeln(snippet.trim());
      }
    }
    if (_aiAttachNextLastMeeting) {
      _aiAttachNextLastMeeting = false;
      final m = _readLastMeetingSnippetOnPage();
      if (m != null && m.trim().isNotEmpty) {
        b.writeln(
          isEs
              ? '--- Última nota de reunión en la página ---'
              : '--- Last meeting note on this page ---',
        );
        b.writeln(m.trim());
      }
    }
    return b.toString().trim();
  }

  String? _readEditorSelectionPlainForAi() {
    final page = _s.selectedPage;
    if (page == null) return null;
    final key = _blockEditorKeysByPage[page.id];
    return key?.currentState?.plainSelectionTextForAi();
  }

  String? _readLastMeetingSnippetOnPage() {
    final page = _s.selectedPage;
    if (page == null) return null;
    FolioBlock? last;
    for (final block in page.blocks) {
      if (block.type == 'meeting_note' && block.text.trim().isNotEmpty) {
        last = block;
      }
    }
    final t = last?.text.trim();
    if (t == null || t.isEmpty) return null;
    return t.length > 12000 ? t.substring(0, 12000) : t;
  }
}

