part of 'workspace_page.dart';

extension _WorkspacePageAiPlanModule on _WorkspacePageState {
  bool get _planModeEnabled => _planModeByChatId[_activeChat.id] ?? false;

  void _togglePlanMode() {
    _setStateSafe(() {
      _planModeByChatId[_activeChat.id] = !_planModeEnabled;
    });
  }

  int _indexOfLatestPendingPlanInChat(String chatId) {
    AiChatThreadData? thread;
    for (final t in _s.aiChatThreads) {
      if (t.id == chatId) {
        thread = t;
        break;
      }
    }
    final msgs = thread?.messages ?? const <AiChatMessage>[];
    for (var i = msgs.length - 1; i >= 0; i--) {
      final plan = msgs[i].agentPlan;
      if (plan != null && (plan['status'] as String? ?? '') == 'pending') {
        return i;
      }
    }
    return -1;
  }

  /// Marca como cancelados los planes `pending` del hilo activo (antes de uno nuevo).
  void _supersedePendingPlansInChat(String chatId) {
    if (_activeChat.id != chatId) return;
    final snapshot = List<AiChatMessage>.from(_activeChat.messages);
    for (var idx = 0; idx < snapshot.length; idx++) {
      final m = snapshot[idx];
      final plan = m.agentPlan;
      if (plan == null) continue;
      if ((plan['status'] as String? ?? '') != 'pending') continue;
      final nextPlan = Map<String, dynamic>.from(plan)..['status'] = 'cancelled';
      _s.updateMessageInActiveAiChat(
        idx,
        m.copyWith(agentPlan: nextPlan),
      );
    }
  }

  bool _looksLikePlanApproval(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty || t.length > 64) return false;
    const phrases = <String>[
      'sí',
      'si',
      'ok',
      'vale',
      'adelante',
      'ejecuta',
      'ejecutar',
      'aprobar',
      'aprueba',
      'aprobado',
      'hazlo',
      'procede',
      'continúa',
      'continua',
      'dale',
      'yes',
      'yep',
      'go',
      'do it',
      'approve',
      'run it',
      'execute',
      'run the plan',
      'ejecuta el plan',
      'sí, ejecuta',
      'si, ejecuta',
      'ok ejecuta',
    ];
    for (final p in phrases) {
      if (t == p) return true;
      if (t.startsWith('$p!') || t.startsWith('$p.') || t.startsWith('$p,')) {
        return true;
      }
    }
    return false;
  }

  String _planEditorKey(AiChatMessage message) =>
      '${_activeChat.id}:${message.timestamp.millisecondsSinceEpoch}';

  TextEditingController _planBodyControllerFor(
    AiChatMessage message,
    String initial,
  ) {
    final key = _planEditorKey(message);
    final existing = _planBodyControllers[key];
    if (existing != null) {
      // Si el mensaje trae texto nuevo (p. ej. revisión) y el controller
      // aún tiene otro documento, sincroniza.
      if (initial.trim().isNotEmpty &&
          existing.text.trim() != initial.trim() &&
          message.agentPlan?['status'] == 'pending') {
        // Solo auto-sync si el controller parece del plan anterior vacío/stub
        // o si planText del mensaje cambió tras una revisión.
        final planText = (message.agentPlan?['planText'] as String?)?.trim();
        if (planText != null &&
            planText.isNotEmpty &&
            existing.text.trim() != planText) {
          existing.text = planText;
        }
      }
      return existing;
    }
    final c = TextEditingController(text: initial);
    _planBodyControllers[key] = c;
    return c;
  }

  TextEditingController _planRevisionControllerFor(AiChatMessage message) {
    final key = _planEditorKey(message);
    return _planRevisionControllers.putIfAbsent(key, TextEditingController.new);
  }

  String _planDisplayText(AiChatMessage message) {
    final plan = message.agentPlan;
    final fromMeta = (plan?['planText'] as String?)?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    return message.content;
  }

  Widget _buildAgentPlanCard(AiChatMessage message, int messageIndex) {
    final plan = message.agentPlan;
    if (plan == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = plan['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final isExecuting = status == 'executing';
    final isCancelled = status == 'cancelled';
    final isApproved = status == 'approved';
    final bodyCtrl = _planBodyControllerFor(
      message,
      _planDisplayText(message),
    );
    final editorKey = _planEditorKey(message);
    final revisionExpanded = _planRevisionExpanded.contains(editorKey);
    final revisionCtrl = _planRevisionControllerFor(message);

    String statusLabel;
    Color statusBg;
    Color statusFg;
    if (isExecuting) {
      statusLabel = l10n.aiPlanExecutingLabel;
      statusBg = scheme.tertiaryContainer;
      statusFg = scheme.onTertiaryContainer;
    } else if (isCancelled) {
      statusLabel = l10n.aiPlanCancelledLabel;
      statusBg = scheme.surfaceContainerHighest;
      statusFg = scheme.onSurfaceVariant;
    } else if (isApproved) {
      statusLabel = l10n.aiPlanApprovedLabel;
      statusBg = scheme.secondaryContainer;
      statusFg = scheme.onSecondaryContainer;
    } else {
      statusLabel = l10n.aiPlanPendingLabel;
      statusBg = scheme.primaryContainer;
      statusFg = scheme.onPrimaryContainer;
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(FolioRadius.md),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isPending ? 0.45 : 0.22),
          width: isPending ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            child: Row(
              children: [
                Icon(
                  Icons.checklist_rtl_rounded,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.aiPlanCardTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(FolioRadius.sm),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: isPending
                ? TextField(
                    controller: bodyCtrl,
                    enabled: !_aiChatBusy,
                    minLines: 6,
                    maxLines: 18,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.aiPlanEditHint,
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FolioRadius.sm),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FolioRadius.sm),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (_) {
                      // El texto editado se lee al aprobar/revisar.
                    },
                  )
                : _buildMarkdownMessage(
                    context: context,
                    content: bodyCtrl.text.isNotEmpty
                        ? bodyCtrl.text
                        : _planDisplayText(message),
                    isUser: false,
                    textColor: scheme.onSurface,
                  ),
          ),
          if (isPending) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(FolioRadius.sm),
                    onTap: _aiChatBusy
                        ? null
                        : () {
                            _setStateSafe(() {
                              if (revisionExpanded) {
                                _planRevisionExpanded.remove(editorKey);
                              } else {
                                _planRevisionExpanded.add(editorKey);
                              }
                            });
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            revisionExpanded
                                ? Icons.expand_less_rounded
                                : Icons.tune_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.aiPlanAdjustSection,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (revisionExpanded) ...[
                    Text(
                      l10n.aiPlanAdjustHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: revisionCtrl,
                      enabled: !_aiChatBusy,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.aiPlanRevisionFieldHint,
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FolioRadius.sm),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _aiChatBusy
                            ? null
                            : () => unawaited(
                                  _reviseAgentPlan(
                                    messageIndex,
                                    revisionCtrl.text,
                                  ),
                                ),
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                        label: Text(l10n.aiPlanRequestRevision),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _aiChatBusy
                        ? null
                        : () => _rejectAgentPlan(messageIndex),
                    child: Text(l10n.aiPlanReject),
                  ),
                  FilledButton.icon(
                    onPressed: _aiChatBusy
                        ? null
                        : () => unawaited(_approveAgentPlan(messageIndex)),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(l10n.aiPlanApprove),
                  ),
                ],
              ),
            ),
          ],
          if (isExecuting)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _aiToolTrace.isNotEmpty
                  ? ToolInspectorPanel(steps: _aiToolTrace, colorScheme: scheme)
                  : AiToolActivityIndicator(
                      label: _aiToolActivityLabel ?? l10n.aiPlanExecutingLabel,
                      colorScheme: scheme,
                    ),
            ),
        ],
      ),
    );
  }

  void _rejectAgentPlan(int messageIndex) {
    final msgs = _activeChat.messages;
    if (messageIndex < 0 || messageIndex >= msgs.length) return;
    final old = msgs[messageIndex];
    final plan = old.agentPlan;
    if (plan == null) return;
    final body = _planBodyControllers[_planEditorKey(old)]?.text.trim();
    final nextPlan = Map<String, dynamic>.from(plan)
      ..['status'] = 'cancelled'
      ..['planText'] = (body != null && body.isNotEmpty)
          ? body
          : (plan['planText'] ?? old.content);
    _s.updateMessageInActiveAiChat(
      messageIndex,
      old.copyWith(
        content: nextPlan['planText'] as String? ?? old.content,
        agentPlan: nextPlan,
      ),
    );
    _planRevisionExpanded.remove(_planEditorKey(old));
  }

  Future<void> _reviseAgentPlan(
    int messageIndex,
    String revisionNotes,
  ) async {
    final notes = revisionNotes.trim();
    if (notes.isEmpty || _aiChatBusy) return;
    final msgs = _activeChat.messages;
    if (messageIndex < 0 || messageIndex >= msgs.length) return;
    final planMessage = msgs[messageIndex];
    final plan = planMessage.agentPlan;
    if (plan == null) return;
    final currentPlanText =
        _planBodyControllers[_planEditorKey(planMessage)]?.text.trim().isNotEmpty ==
                true
            ? _planBodyControllers[_planEditorKey(planMessage)]!.text.trim()
            : _planDisplayText(planMessage);
    final languageCode = Localizations.localeOf(context).languageCode;
    final isEs = languageCode.toLowerCase().startsWith('es');
    final revisePrompt = isEs
        ? 'Ajusta el siguiente plan según estas indicaciones del usuario. '
            'Devuelve solo el plan revisado (numerado, con tools), sin ejecutarlo.\n\n'
            'Indicaciones:\n$notes\n\nPlan actual:\n$currentPlanText'
        : 'Revise the following plan according to these user notes. '
            'Return only the revised numbered plan (with tools), do not execute.\n\n'
            'Notes:\n$notes\n\nCurrent plan:\n$currentPlanText';

    _setStateSafe(() => _aiChatBusy = true);
    try {
      final outcome = await _s.agentChatWithAiPlanProposal(
        messages: msgs.sublist(0, messageIndex + 1),
        prompt: revisePrompt,
        scopePageId: plan['scopePageId'] as String? ?? _s.selectedPageId,
        includePageContext: plan['includePageContext'] as bool? ?? true,
        contextPageIds: (plan['contextPageIds'] is List)
            ? (plan['contextPageIds'] as List).map((e) => '$e').toList()
            : const <String>[],
        languageCode: (plan['languageCode'] as String?) ?? languageCode,
        cloudInkOperation: plan['cloudInkOperation'] as String?,
        systemPromptOverride: (plan['systemPromptOverride'] as String?) ?? '',
      );
      if (!mounted) return;
      final newText = outcome.reply.trim().isEmpty
          ? currentPlanText
          : outcome.reply.trim();
      final nextPlan = Map<String, dynamic>.from(plan)
        ..['status'] = 'pending'
        ..['planText'] = newText
        ..['originalPrompt'] =
            (plan['originalPrompt'] as String?) ?? currentPlanText;
      // Conserva el prompt original del usuario si ya estaba.
      if ((plan['originalPrompt'] as String?)?.trim().isNotEmpty == true) {
        nextPlan['originalPrompt'] = plan['originalPrompt'];
      }
      _s.updateMessageInActiveAiChat(
        messageIndex,
        planMessage.copyWith(content: newText, agentPlan: nextPlan),
      );
      _planBodyControllers[_planEditorKey(planMessage)]?.text = newText;
      _planRevisionControllers[_planEditorKey(planMessage)]?.clear();
      _setStateSafe(
        () => _planRevisionExpanded.remove(_planEditorKey(planMessage)),
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
        _setStateSafe(() {
          _aiChatBusy = false;
          _aiToolActivityLabel = null;
        });
      }
    }
  }

  Future<void> _approveAgentPlan(int messageIndex) async {
    if (_aiChatBusy) return;
    final msgs = _activeChat.messages;
    if (messageIndex < 0 || messageIndex >= msgs.length) return;
    final planMessage = msgs[messageIndex];
    final plan = planMessage.agentPlan;
    if (plan == null) return;
    final chatId = _activeChat.id;
    final editedBody =
        _planBodyControllers[_planEditorKey(planMessage)]?.text.trim();
    final effectivePlanText = (editedBody != null && editedBody.isNotEmpty)
        ? editedBody
        : _planDisplayText(planMessage);

    // Persiste ediciones del usuario en el mensaje antes de ejecutar.
    final planContext = Map<String, dynamic>.from(plan)
      ..['planText'] = effectivePlanText;
    if (editedBody != null &&
        editedBody.isNotEmpty &&
        editedBody != planMessage.content) {
      _s.updateMessageInActiveAiChat(
        messageIndex,
        planMessage.copyWith(content: effectivePlanText, agentPlan: planContext),
      );
    }

    final historyThroughPlan = List<AiChatMessage>.from(
      msgs.sublist(0, messageIndex + 1),
    );
    // Sustituye el mensaje del plan en el historial con el texto editado.
    if (historyThroughPlan.isNotEmpty) {
      final last = historyThroughPlan.last;
      historyThroughPlan[historyThroughPlan.length - 1] = last.copyWith(
        content: effectivePlanText,
        agentPlan: planContext,
      );
    }

    final executingPlan = Map<String, dynamic>.from(planContext)
      ..['status'] = 'executing';
    _s.updateMessageInActiveAiChat(
      messageIndex,
      (messageIndex < _activeChat.messages.length
              ? _activeChat.messages[messageIndex]
              : planMessage)
          .copyWith(
            content: effectivePlanText,
            agentPlan: executingPlan,
          ),
    );
    _setStateSafe(() {
      _aiChatBusy = true;
      _aiToolTrace.clear();
    });

    try {
      final outcome = await _s.agentChatWithAiExecuteApprovedPlan(
        messages: historyThroughPlan,
        planContext: planContext,
        onToolEvent: _onAiToolEvent,
        onConfirmIrreversibleTool: _confirmIrreversibleToolCall,
      );
      if (!mounted) return;

      final approvedPlan = Map<String, dynamic>.from(planContext)
        ..['status'] = 'approved';
      if (_activeChat.id == chatId) {
        final current = _activeChat.messages;
        if (messageIndex >= 0 && messageIndex < current.length) {
          _s.updateMessageInActiveAiChat(
            messageIndex,
            current[messageIndex].copyWith(
              content: effectivePlanText,
              agentPlan: approvedPlan,
            ),
          );
        }
        _setStateSafe(() => _lastChatTokenUsage = outcome.usage);
      }
      _s.appendMessageToAiChatById(
        chatId,
        AiChatMessage.now(
          role: 'assistant',
          content: outcome.reply,
          agentApplySnapshot: outcome.agentApplySnapshot,
          toolCalls: outcome.toolCalls,
          toolErrors: outcome.toolErrors,
          aiTurnId: outcome.aiTurnId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (_activeChat.id == chatId) {
        final current = _activeChat.messages;
        if (messageIndex >= 0 && messageIndex < current.length) {
          final pendingPlan = Map<String, dynamic>.from(planContext)
            ..['status'] = 'pending';
          _s.updateMessageInActiveAiChat(
            messageIndex,
            current[messageIndex].copyWith(agentPlan: pendingPlan),
          );
        }
      }
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
        _setStateSafe(() {
          _aiChatBusy = false;
          _aiToolActivityLabel = null;
        });
      }
    }
  }

  Future<bool> _confirmIrreversibleToolCall(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (toolName == 'empty_trash') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => FolioDialog(
          title: Text(l10n.sidebarTrashEmptyAction),
          content: Text(l10n.sidebarTrashEmptyConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.sidebarTrashEmptyAction),
            ),
          ],
        ),
      );
      return ok == true;
    }

    if (toolName == 'permanently_delete_page') {
      final pageId = (arguments['pageId'] as String?)?.trim() ?? '';
      FolioPage? page;
      for (final p in _s.pages) {
        if (p.id == pageId) {
          page = p;
          break;
        }
      }
      final title = (page?.title.trim().isEmpty ?? true)
          ? l10n.untitledFallback
          : page!.title.trim();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => FolioDialog(
          title: Text(l10n.sidebarTrashDeleteForever),
          content: Text(l10n.sidebarTrashDeleteForeverConfirm(title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.sidebarTrashDeleteForever),
            ),
          ],
        ),
      );
      return ok == true;
    }

    return true;
  }
}
