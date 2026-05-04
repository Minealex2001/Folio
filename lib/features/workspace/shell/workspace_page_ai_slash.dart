part of 'workspace_page.dart';

extension _WorkspacePageAiSlashModule on _WorkspacePageState {
  String _buildAiSlashPrompt(FolioAiSlashParams p, {required bool isEs}) {
    final sel = (p.selectionPlain ?? '').trim();
    final block = p.blockPlain.trim();
    final hasSel = sel.isNotEmpty;
    final body = hasSel ? sel : block;
    switch (p.intent) {
      case AiSlashIntent.summarize:
        return isEs
            ? 'Resume en 3–8 viñetas claras el siguiente contenido de mi nota. Si el contexto de página está activo y no hay selección, usa la página abierta.\n\n$body'
            : 'Summarize the following note content in 3–8 clear bullets. If page context is on and there is no selection, use the open page.\n\n$body';
      case AiSlashIntent.continueWriting:
        return isEs
            ? 'Continúa escribiendo con el mismo idioma y tono, sin repetir el texto; añade al bloque o después según encaje mejor:\n\n$body'
            : 'Continue writing in the same language and tone without repeating the text; append to the block or after it as fits best:\n\n$body';
      case AiSlashIntent.explain:
        return isEs
            ? 'Explica con claridad (párrafos breves) el siguiente texto:\n\n$body'
            : 'Explain clearly in short paragraphs:\n\n$body';
      case AiSlashIntent.actionItems:
        return isEs
            ? 'Extrae action items. Cuando haya fechas, prioridad o contexto, usa bloques nativos {"type":"task","text":{...JSON FolioTaskData...}} o {"type":"task","title":"..."}; si son ítems simples, bloques todo. Si el modo lo permite, incluye en la respuesta JSON con "blocks" para aplicar al final de la página actual. Texto fuente:\n\n$body'
            : 'Extract action items. When dates, priority or context matter, use native blocks {"type":"task","text":{...FolioTaskData JSON...}} or {"type":"task","title":"..."}; for simple items use todo blocks. If the mode allows, include JSON with "blocks" to append at the end of the current page. Source text:\n\n$body';
      case AiSlashIntent.todo:
        return isEs
            ? 'Convierte lo siguiente en tareas: prefiere bloques task (JSON en text o campo title) si conviene fechas o prioridad; si no, un bloque todo por ítem. Aplica en la página actual.\n\n$body'
            : 'Turn the following into tasks: prefer task blocks (JSON in text or title field) when dates or priority help; otherwise one todo block per item. Apply on the current page.\n\n$body';
      case AiSlashIntent.mindmap:
        return isEs
            ? 'Genera una estructura jerárquica (h1/h2/h3) tipo mapa mental. Si es mejor, usa un bloque canvas con nodos de texto. Fuente:\n\n$body'
            : 'Build a hierarchical outline (h1/h2/h3) like a mind map. If better, use a canvas block with simple text nodes. Source:\n\n$body';
      case AiSlashIntent.table:
        return isEs
            ? 'Crea una tabla (bloque tabla de Folio) a partir del siguiente contenido:\n\n$body'
            : 'Create a Folio table block from the following content:\n\n$body';
      case AiSlashIntent.improve:
        return isEs
            ? 'Mejora redacción, claridad y tono profesional sin cambiar el significado:\n\n$body'
            : 'Improve wording, clarity, and professional tone without changing meaning:\n\n$body';
      case AiSlashIntent.translate:
        return isEs
            ? 'Traduce el siguiente texto al idioma del usuario salvo que pida otro explícitamente:\n\n$body'
            : 'Translate the following into the user’s language unless another is explicitly requested:\n\n$body';
    }
  }

  Future<void> _handleFolioAiSlash(FolioAiSlashParams params) async {
    if (_aiChatBusy) return;
    final isEs = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('es');
    final prompt = _buildAiSlashPrompt(params, isEs: isEs);
    final targetChat = _activeChat;
    final targetChatId = targetChat.id;
    final includePageContext = targetChat.includePageContext;
    final contextPageIds = List<String>.from(targetChat.contextPageIds);
    final userMessage = AiChatMessage.now(role: 'user', content: prompt);
    final threadMessages = List<AiChatMessage>.from(targetChat.messages)
      ..add(userMessage);
    _setStateSafe(() {
      _aiPanelCollapsed = false;
      _aiChatBusy = true;
    });
    unawaited(widget.appSettings.setAiChatPanelCollapsed(false));
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
    _s.appendMessageToAiChatById(targetChatId, userMessage);
    try {
      final outcome = await _runAiFromChat(
        prompt,
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
}
