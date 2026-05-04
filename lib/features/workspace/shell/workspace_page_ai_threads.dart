part of 'workspace_page.dart';

extension _WorkspacePageAiThreadsModule on _WorkspacePageState {
  List<int> _filteredAiChatThreadIndices(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return List<int>.generate(_s.aiChatThreads.length, (i) => i);
    }
    final out = <int>[];
    for (var i = 0; i < _s.aiChatThreads.length; i++) {
      if (_s.aiChatThreads[i].title.toLowerCase().contains(q)) {
        out.add(i);
      }
    }
    return out;
  }

  Future<void> _showAiThreadsPickerSheet() async {
    final l10n = AppLocalizations.of(context);
    final searchCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final maxH = MediaQuery.sizeOf(sheetCtx).height * 0.55;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          ),
          child: StatefulBuilder(
            builder: (sheetCtx, setModal) {
              final indices = _filteredAiChatThreadIndices(searchCtrl.text);
              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Text(
                          l10n.aiChatThreadsListTitle,
                          style: Theme.of(sheetCtx).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (_) => setModal(() {}),
                          decoration: InputDecoration(
                            hintText: l10n.aiThreadSearchHint,
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: indices.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    l10n.aiChatThreadsEmptySearch,
                                    style: Theme.of(sheetCtx)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(sheetCtx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: indices.length,
                                itemBuilder: (ctx, j) {
                                  final i = indices[j];
                                  final active = i == _s.aiActiveChatIndex;
                                  final title = _s.aiChatThreads[i].title;
                                  return ListTile(
                                    selected: active,
                                    title: Text(
                                      title.isEmpty
                                          ? l10n.untitledFallback
                                          : title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: _aiChatBusy
                                        ? null
                                        : () {
                                            _s.syncActiveAiChatAttachmentPaths(
                                              _aiAttachmentPaths,
                                            );
                                            _setStateSafe(
                                              () =>
                                                  _lastChatTokenUsage = null,
                                            );
                                            _s.selectAiChat(i);
                                            Navigator.pop(sheetCtx);
                                          },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    // El route puede animar un frame más tras el pop; no dispose hasta después.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchCtrl.dispose();
    });
  }

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

