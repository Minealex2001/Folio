part of 'workspace_page.dart';

extension _WorkspacePageAiThreadsModule on _WorkspacePageState {
  String _aiPanelContextSubtitle(AppLocalizations l10n) {
    final chat = _activeChat;
    if (!chat.includePageContext) return l10n.aiChatContextDisabledSubtitle;
    if (chat.contextPageIds.isEmpty) {
      final t = _s.selectedPage?.title;
      if (t != null && t.isNotEmpty) {
        return l10n.aiChatContextUsesCurrentPage(t);
      }
      return l10n.aiNoPageSelected;
    }
    if (chat.contextPageIds.length == 1) {
      final id = chat.contextPageIds.first;
      for (final p in _s.pages) {
        if (p.id == id) return p.title;
      }
      return l10n.aiChatContextOnePageFallback;
    }
    return l10n.aiChatContextNPages(chat.contextPageIds.length);
  }

  Future<void> _showRenameActiveChatDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _s.activeAiChat.title);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.aiRenameChatDialogTitle),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: l10n.aiRenameChatLabel),
              maxLength: 80,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                final t = controller.text.trim();
                if (t.isNotEmpty) Navigator.pop(ctx, t);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(ctx, t);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
      if (!mounted || result == null) return;
      _s.renameAiChatAt(_s.aiActiveChatIndex, result);
    } finally {
      controller.dispose();
    }
  }

  void _createNewChat() {
    _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    _setStateSafe(() => _lastChatTokenUsage = null);
    _s.createNewAiChat();
  }

  void _deleteActiveChat() {
    _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    _setStateSafe(() => _lastChatTokenUsage = null);
    _s.deleteActiveAiChat();
  }
}

