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

      if (_planModeEnabled) {
      final pendingIdx = _indexOfLatestPendingPlanInChat(targetChatId);
      if (pendingIdx >= 0 && _looksLikePlanApproval(text)) {
        await _approveAgentPlan(pendingIdx);
        return;
      }
      // Nueva petición con modo Plan: cierra planes pendientes previos para
      // que no contaminen el siguiente (p. ej. «Google» vs «física»).
      _supersedePendingPlansInChat(targetChatId);
    }

    // El modo Plan sigue sin streaming (la respuesta se renderiza como
    // tarjeta de plan, no como burbuja de texto normal) — se mantiene el
    // comportamiento de siempre: se añade el mensaje completo al terminar.
    if (_planModeEnabled) {
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
            agentPlan: outcome.agentPlan,
            toolCalls: outcome.toolCalls,
            toolErrors: outcome.toolErrors,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _handleAiChatError(e);
      } finally {
        if (mounted) {
          _setStateSafe(() {
            _aiChatBusy = false;
            _aiToolActivityLabel = null;
          });
        }
      }
      return;
    }

    // Camino normal (tool-calling): placeholder vacío + streaming en vivo.
    final placeholderIndex = threadMessages.length;
    final placeholderKey = '$targetChatId#$placeholderIndex';
    _s.appendMessageToAiChatById(
      targetChatId,
      AiChatMessage.now(role: 'assistant', content: ''),
    );
    _setStateSafe(() => _aiStreamingMessageKeys.add(placeholderKey));
    try {
      final outcome = await _runAiFromChat(
        text,
        threadMessages,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
        onReplyDelta: (textSoFar) {
          if (!mounted) return;
          _s.updateMessageInAiChatById(
            targetChatId,
            placeholderIndex,
            AiChatMessage.now(role: 'assistant', content: textSoFar),
          );
        },
      );
      if (!mounted) return;
      if (_activeChat.id == targetChatId) {
        _setStateSafe(() => _lastChatTokenUsage = outcome.usage);
      }
      _s.updateMessageInAiChatById(
        targetChatId,
        placeholderIndex,
        AiChatMessage.now(
          role: 'assistant',
          content: outcome.reply,
          agentApplySnapshot: outcome.agentApplySnapshot,
          agentPlan: outcome.agentPlan,
          toolCalls: outcome.toolCalls,
          toolErrors: outcome.toolErrors,
        ),
      );
    } catch (e) {
      _s.removeMessageInAiChatById(targetChatId, placeholderIndex);
      if (!mounted) return;
      _handleAiChatError(e);
    } finally {
      if (mounted) {
        _setStateSafe(() {
          _aiChatBusy = false;
          _aiToolActivityLabel = null;
          _aiStreamingMessageKeys.remove(placeholderKey);
          _aiTypewriterActiveMessageKeys.remove(placeholderKey);
        });
      }
    }
  }

  void _handleAiChatError(Object e) {
    final l10n = AppLocalizations.of(context);
    if (e is FolioCloudAiException && e.isInkExhausted) {
      unawaited(
        showFolioCloudAiInkExhaustedDialog(
          context,
          onOpenSettings: _openSettings,
          onOpenFolioCloudPitch: _openFolioCloudSubscriptionPitch,
        ),
      );
    } else {
      _snack(l10n.aiErrorWithDetails(e), error: true);
    }
  }

  /// Reenvía el turno de usuario que precede a [messageIndex] (el último
  /// mensaje de Quill del hilo) y reemplaza esa respuesta in situ — mismo
  /// mecanismo de streaming que `_sendAiChat`, sin añadir mensajes nuevos.
  Future<void> _regenerateAiMessage(int messageIndex) async {
    if (_aiChatBusy) return;
    final targetChat = _activeChat;
    final targetChatId = targetChat.id;
    if (messageIndex != targetChat.messages.length - 1) return;
    if (messageIndex <= 0) return;
    final original = targetChat.messages[messageIndex];
    if (original.role != 'assistant') return;
    final userTurn = targetChat.messages[messageIndex - 1];
    if (userTurn.role != 'user') return;
    final text = userTurn.content.trim();
    if (text.isEmpty) return;

    final includePageContext = targetChat.includePageContext;
    final contextPageIds = List<String>.from(targetChat.contextPageIds);
    final threadMessages = targetChat.messages.sublist(0, messageIndex - 1);
    final placeholderKey = '$targetChatId#$messageIndex';

    _setStateSafe(() {
      _aiChatBusy = true;
      _aiStreamingMessageKeys.add(placeholderKey);
    });
    _s.updateMessageInAiChatById(
      targetChatId,
      messageIndex,
      AiChatMessage.now(role: 'assistant', content: ''),
    );
    try {
      final outcome = await _runAiFromChat(
        text,
        threadMessages,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
        onReplyDelta: (textSoFar) {
          if (!mounted) return;
          _s.updateMessageInAiChatById(
            targetChatId,
            messageIndex,
            AiChatMessage.now(role: 'assistant', content: textSoFar),
          );
        },
      );
      if (!mounted) return;
      if (_activeChat.id == targetChatId) {
        _setStateSafe(() => _lastChatTokenUsage = outcome.usage);
      }
      _s.updateMessageInAiChatById(
        targetChatId,
        messageIndex,
        AiChatMessage.now(
          role: 'assistant',
          content: outcome.reply,
          agentApplySnapshot: outcome.agentApplySnapshot,
          agentPlan: outcome.agentPlan,
          toolCalls: outcome.toolCalls,
          toolErrors: outcome.toolErrors,
        ),
      );
    } catch (e) {
      _s.updateMessageInAiChatById(targetChatId, messageIndex, original);
      if (!mounted) return;
      _handleAiChatError(e);
    } finally {
      if (mounted) {
        _setStateSafe(() {
          _aiChatBusy = false;
          _aiToolActivityLabel = null;
          _aiStreamingMessageKeys.remove(placeholderKey);
          _aiTypewriterActiveMessageKeys.remove(placeholderKey);
        });
      }
    }
  }

  void _onAiToolEvent(AiToolLoopEvent event) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (event.kind) {
      case AiToolLoopEventKind.toolCallStart:
        _setStateSafe(() {
          _aiToolActivityLabel = aiToolActivityLabel(
            toolName: event.call.name,
            l10n: l10n,
          );
        });
      case AiToolLoopEventKind.toolCallResult:
        _setStateSafe(() => _aiToolActivityLabel = null);
    }
  }

  Future<AgentChatOutcome> _runAiFromChat(
    String text,
    List<AiChatMessage> threadMessages, {
    required bool includePageContext,
    required List<String> contextPageIds,
    /// Streaming en vivo del texto de respuesta final (solo camino de
    /// tool-calling; el modo Plan sigue sin streaming, ver `_sendAiChat`).
    void Function(String textSoFar)? onReplyDelta,
  }) async {
    final t = text.trim();
    final languageCode = Localizations.localeOf(context).languageCode;
    final attachments = await _collectAiAttachments();
    final isCloudProvider =
        widget.appSettings.aiProvider == AiProvider.quillCloud;
    final op = isCloudProvider ? _aiInkEstimateOperationKind : null;
    final extra = _composeAiExtraContextForNextSend();
    final presets = widget.appSettings.quillSystemPrompts;
    final bestPromptId = await _classifyBestPromptId(t, presets);
    final preset = presets.firstWhere(
      (p) => p.id == bestPromptId,
      orElse: () => presets.firstWhere((p) => p.id == 'quill_default', orElse: () => presets.first),
    );

    if (_planModeEnabled) {
      return _s.agentChatWithAiPlanProposal(
        messages: threadMessages,
        prompt: t,
        scopePageId: _s.selectedPageId,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
        attachments: attachments,
        languageCode: languageCode,
        cloudInkOperation: op,
        extraContextSections: extra,
        systemPromptOverride: preset.prompt,
        systemPromptOverrideIsNarrowTask: preset.isNarrowTask,
      );
    }

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
      systemPromptOverride: preset.prompt,
      systemPromptOverrideIsNarrowTask: preset.isNarrowTask,
      useToolCalling: widget.appSettings.quillToolCallingEnabled,
      onToolEvent: _onAiToolEvent,
      onReplyDelta: onReplyDelta,
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

  Future<String> _classifyBestPromptId(String userPrompt, List<QuillSystemPrompt> prompts) async {
    if (prompts.length <= 1) return prompts.first.id;

    final ai = _s.aiService;
    if (ai == null) return 'quill_default';

    // Compact prompt to minimize tokens and latency
    final systemInstruction =
        'You are a routing agent. Classify the user request and respond with ONLY the exact ID of the best matching instruction preset from the list.\n'
        'Respond ONLY with the exact ID string (no quotes, no punctuation, no other text).';

    final promptBuilder = StringBuffer();
    promptBuilder.writeln('Available instructions:');
    for (final p in prompts) {
      promptBuilder.writeln('- "${p.id}": ${p.name} (${p.prompt.substring(0, math.min(80, p.prompt.length))}...)');
    }
    promptBuilder.writeln('\nUser Request: "$userPrompt"');
    promptBuilder.writeln('Best match ID:');

    try {
      final res = await ai.complete(AiCompletionRequest(
        cloudInkOperation: 'agent_routing',
        systemPrompt: systemInstruction,
        prompt: promptBuilder.toString(),
        model: 'auto',
      ));
      final choice = res.text.trim().replaceAll('"', '').replaceAll("'", '');
      final matching = prompts.firstWhereOrNull((p) => p.id == choice);
      if (matching != null) {
        AppLogger.info('Quill auto-routed request to preset: ${matching.name} (${matching.id})', tag: 'ai.routing');
        return matching.id;
      }
    } catch (e) {
      AppLogger.error('Quill auto-routing failed', error: e, tag: 'ai.routing');
    }
    return 'quill_default';
  }
}

