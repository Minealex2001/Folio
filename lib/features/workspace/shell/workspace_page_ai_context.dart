part of 'workspace_page.dart';

extension _WorkspacePageAiContextModule on _WorkspacePageState {
  List<_AiContextItem> _buildAiContextSuggestions(
    AppLocalizations l10n,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (_aiContextMenuView == _AiContextMenuView.root) {
      final hasMeetingBlocks =
          _s.selectedPage?.blocks.any(
            (b) => b.type == 'meeting_note' && (b.url ?? '').trim().isNotEmpty,
          ) ??
          false;
      return <_AiContextItem>[
        _AiContextItem(
          kind: _AiContextItemKind.addFile,
          id: '__add_file__',
          label: l10n.aiContextAddFile,
        ),
        _AiContextItem(
          kind: _AiContextItemKind.page,
          id: '__open_pages__',
          label: l10n.aiContextAddPage,
        ),
        if (hasMeetingBlocks)
          _AiContextItem(
            kind: _AiContextItemKind.meetingNote,
            id: '__add_meeting_note__',
            label: l10n.meetingNoteSendToAi,
          ),
      ];
    }
    final suggestions = <_AiContextItem>[
      _AiContextItem(
        kind: _AiContextItemKind.currentPage,
        id: '__current_page__',
        label: _s.selectedPage?.title.isNotEmpty == true
            ? l10n.aiContextCurrentPageChip(_s.selectedPage!.title)
            : l10n.aiContextCurrentPageFallback,
      ),
      ..._s.pages.map(
        (page) => _AiContextItem(
          kind: _AiContextItemKind.page,
          id: page.id,
          label: page.title.trim().isEmpty ? l10n.untitledFallback : page.title,
        ),
      ),
    ];
    if (needle.isEmpty) return suggestions.take(8).toList();
    return suggestions
        .where((item) => item.label.toLowerCase().contains(needle))
        .take(8)
        .toList();
  }

  bool _chatInputHasContextTrigger() {
    final value = _chatInputController.value;
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return false;
    final caret = selection.baseOffset;
    if (caret < 0 || caret > text.length) return false;
    final prefix = text.substring(0, caret);
    final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(prefix);
    if (match == null) return false;
    _aiContextQuery = match.group(2) ?? '';
    _aiContextMenuView = _AiContextMenuView.pages;
    return true;
  }

  void _hideAiContextMenu() {
    _aiContextMenuOverlay?.remove();
    _aiContextMenuOverlay = null;
    _aiContextMenuPinned = false;
    _aiContextMenuView = _AiContextMenuView.root;
  }

  void _showAiContextMenu({String initialQuery = '', bool pinned = false}) {
    _aiContextQuery = initialQuery;
    _aiContextMenuPinned = pinned;
    _aiContextMenuSelectedIndex = 0;
    _aiContextMenuUsingKeyboard = false;
    final l10n = AppLocalizations.of(context);
    final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
    if (suggestions.isEmpty) {
      _hideAiContextMenu();
      return;
    }
    _aiContextMenuOverlay?.remove();
    _aiContextMenuOverlay = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _hideAiContextMenu(),
                ),
              ),
              CompositedTransformFollower(
                link: _aiComposerLayerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomLeft,
                offset: const Offset(0, -8),
                child: Material(
                  elevation: 8,
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 320,
                      maxHeight: 280,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final item = suggestions[index];
                        final alreadySelected =
                            item.kind == _AiContextItemKind.page &&
                            item.id != '__open_pages__' &&
                            _activeChat.contextPageIds.contains(item.id);
                        final isKeyboardSelected =
                            _aiContextMenuUsingKeyboard &&
                            index == _aiContextMenuSelectedIndex;
                        final bgColor = isKeyboardSelected
                            ? scheme.primaryContainer.withValues(alpha: 0.3)
                            : Colors.transparent;
                        return MouseRegion(
                          onEnter: (_) {
                            if (_aiContextMenuUsingKeyboard) {
                              _setStateSafe(() {
                                _aiContextMenuSelectedIndex = index;
                                _aiContextMenuUsingKeyboard = false;
                              });
                            }
                          },
                          child: Container(
                            color: bgColor,
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                alreadySelected
                                    ? Icons.check_rounded
                                    : _iconForAiContextItem(item.kind),
                                size: 18,
                              ),
                              title: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: item.id == '__open_pages__'
                                  ? const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () {
                                _aiContextMenuUsingKeyboard = false;
                                _applyAiContextSuggestion(item);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_aiContextMenuOverlay!);
  }

  void _updateAiContextMenu() {
    if (_aiContextMenuPinned) {
      _showAiContextMenu(initialQuery: _aiContextQuery, pinned: true);
      return;
    }
    if (!_chatInputFocusNode.hasFocus || !_chatInputHasContextTrigger()) {
      _hideAiContextMenu();
      return;
    }
    _showAiContextMenu(initialQuery: _aiContextQuery);
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      final text = _chatInputController.text;
      if (text != _chatDraft) {
        _setStateSafe(() => _chatDraft = text);
      }
    });
  }

  IconData _iconForAiContextItem(_AiContextItemKind kind) {
    switch (kind) {
      case _AiContextItemKind.currentPage:
        return Icons.menu_book_rounded;
      case _AiContextItemKind.page:
        return Icons.description_outlined;
      case _AiContextItemKind.file:
        return Icons.attach_file_rounded;
      case _AiContextItemKind.addFile:
        return Icons.add_circle_outline_rounded;
      case _AiContextItemKind.meetingNote:
        return Icons.mic_rounded;
    }
  }

  Future<void> _applyAiContextSuggestion(_AiContextItem item) async {
    switch (item.kind) {
      case _AiContextItemKind.currentPage:
        _s.setActiveAiChatIncludePageContext(true);
        _s.setActiveAiChatContextPageIds(const []);
        _showAiContextMenu(
          initialQuery: _aiContextQuery,
          pinned: _aiContextMenuPinned,
        );
        break;
      case _AiContextItemKind.page:
        if (item.id == '__open_pages__') {
          _aiContextMenuView = _AiContextMenuView.pages;
          _showAiContextMenu(pinned: true);
          return;
        }
        final next = <String>{..._activeChat.contextPageIds, item.id}.toList();
        _s.setActiveAiChatIncludePageContext(true);
        _s.setActiveAiChatContextPageIds(next);
        _showAiContextMenu(initialQuery: _aiContextQuery, pinned: true);
        break;
      case _AiContextItemKind.file:
        break;
      case _AiContextItemKind.addFile:
        await _pickAiAttachments();
        _showAiContextMenu(pinned: true);
        break;
      case _AiContextItemKind.meetingNote:
        await _pickMeetingNoteAttachment();
        _showAiContextMenu(pinned: true);
        break;
    }
    if (_aiContextMenuView == _AiContextMenuView.pages) {
      final value = _chatInputController.value;
      final text = value.text;
      final selection = value.selection;
      if (selection.isValid) {
        final caret = selection.baseOffset;
        final prefix = text.substring(0, caret);
        final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(prefix);
        if (match != null) {
          final replaceStart = match.start + (match.group(1)?.length ?? 0);
          final newText = text.replaceRange(replaceStart, caret, '');
          _chatInputController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: replaceStart),
          );
        }
      }
    }
    if (mounted) _setStateSafe(() {});
  }

  void _openAiContextPickerFromButton() {
    _chatInputFocusNode.requestFocus();
    _aiContextMenuView = _AiContextMenuView.root;
    _showAiContextMenu(pinned: true);
  }

  void _removeAiContextItem(_AiContextItem item) {
    switch (item.kind) {
      case _AiContextItemKind.currentPage:
        _s.setActiveAiChatIncludePageContext(false);
        _s.setActiveAiChatContextPageIds(const []);
        break;
      case _AiContextItemKind.page:
        final next = List<String>.from(_activeChat.contextPageIds)
          ..remove(item.id);
        if (next.isEmpty) {
          _s.setActiveAiChatContextPageIds(const []);
          _s.setActiveAiChatIncludePageContext(false);
        } else {
          _s.setActiveAiChatIncludePageContext(true);
          _s.setActiveAiChatContextPageIds(next);
        }
        break;
      case _AiContextItemKind.file:
        _setStateSafe(() => _aiAttachmentPaths.remove(item.id));
        _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
        break;
      case _AiContextItemKind.meetingNote:
        _setStateSafe(() {
          _aiAttachmentPaths.remove(item.id);
          _aiMeetingPayloads.remove(item.id);
          _aiMeetingTranscripts.remove(item.id);
        });
        _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
        break;
      case _AiContextItemKind.addFile:
        break;
    }
  }
}

