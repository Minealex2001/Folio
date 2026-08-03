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
      final hasMeetingText =
          _s.selectedPage?.blocks.any(
            (b) => b.type == 'meeting_note' && b.text.trim().isNotEmpty,
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
        _AiContextItem(
          kind: _AiContextItemKind.editorSelection,
          id: '__editor_selection__',
          label: l10n.aiContextEditorSelection,
        ),
        if (hasMeetingText)
          _AiContextItem(
            kind: _AiContextItemKind.lastMeetingOnPage,
            id: '__last_meeting_on_page__',
            label: l10n.aiContextLastMeetingOnPage,
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
      ..._s.activePages.map(
        (page) => _AiContextItem(
          kind: _AiContextItemKind.page,
          id: page.id,
          label: page.title.trim().isEmpty ? l10n.untitledFallback : page.title,
        ),
      ),
    ];
    if (needle.isEmpty) return suggestions.take(12).toList();
    final ranked = FolioVaultLightSearch(
      _s.activePages,
    ).rankPageIds(needle, maxResults: 10);
    final rankedSet = ranked.toSet();
    final merged = <_AiContextItem>[];
    for (final id in ranked) {
      final p = _s.pages.where((x) => x.id == id).firstOrNull;
      if (p == null) continue;
      merged.add(
        _AiContextItem(
          kind: _AiContextItemKind.page,
          id: p.id,
          label: p.title.trim().isEmpty ? l10n.untitledFallback : p.title,
        ),
      );
    }
    for (final item in suggestions) {
      if (merged.length >= 12) break;
      if (item.kind == _AiContextItemKind.page && rankedSet.contains(item.id)) {
        continue;
      }
      if (item.label.toLowerCase().contains(needle)) merged.add(item);
    }
    return merged.take(12).toList();
  }

  String? _subtitleForAiContextItem(
    _AiContextItem item,
    AppLocalizations l10n,
  ) {
    switch (item.kind) {
      case _AiContextItemKind.addFile:
        return l10n.aiAttachFileSubtitle;
      case _AiContextItemKind.page:
        if (item.id == '__open_pages__') return l10n.aiAttachPageSubtitle;
        return l10n.aiContextMentionHint;
      case _AiContextItemKind.editorSelection:
        return l10n.aiAttachSelectionSubtitle;
      case _AiContextItemKind.meetingNote:
        return l10n.aiAttachMeetingSubtitle;
      case _AiContextItemKind.lastMeetingOnPage:
        return l10n.aiAttachLastMeetingSubtitle;
      case _AiContextItemKind.currentPage:
        return l10n.aiContextMentionHint;
      case _AiContextItemKind.file:
        return null;
    }
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
    _aiContextQuery = '';
    if (_aiContextMenuSearchController.text.isNotEmpty) {
      _aiContextMenuSearchController.clear();
    }
  }

  void _showAiContextMenu({String initialQuery = '', bool pinned = false}) {
    _aiContextQuery = initialQuery;
    _aiContextMenuPinned = pinned;
    final l10n = AppLocalizations.of(context);
    if (_aiContextMenuView == _AiContextMenuView.pages &&
        _aiContextMenuSearchController.text != _aiContextQuery) {
      _aiContextMenuSearchController.value = TextEditingValue(
        text: _aiContextQuery,
        selection: TextSelection.collapsed(offset: _aiContextQuery.length),
      );
    }
    final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
    if (suggestions.isEmpty &&
        _aiContextMenuView != _AiContextMenuView.pages) {
      _hideAiContextMenu();
      return;
    }
    // Si el overlay ya está abierto, solo refrescar (p. ej. teclado / búsqueda).
    if (_aiContextMenuOverlay != null) {
      _aiContextMenuOverlay!.markNeedsBuild();
      return;
    }
    _aiContextMenuSelectedIndex = 0;
    _aiContextMenuUsingKeyboard = false;
    _aiContextMenuOverlay = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isPages = _aiContextMenuView == _AiContextMenuView.pages;
        final items = _buildAiContextSuggestions(l10n, _aiContextQuery);

        Widget actionTile(_AiContextItem item, int index) {
          final alreadySelected =
              item.kind == _AiContextItemKind.page &&
              item.id != '__open_pages__' &&
              _activeChat.contextPageIds.contains(item.id);
          final isCurrentSelected =
              item.kind == _AiContextItemKind.currentPage &&
              _activeChat.includePageContext &&
              _activeChat.contextPageIds.isEmpty;
          final selected = alreadySelected || isCurrentSelected;
          final isKeyboardSelected =
              _aiContextMenuUsingKeyboard &&
              index == _aiContextMenuSelectedIndex;
          final subtitle = _subtitleForAiContextItem(item, l10n);
          final icon = selected
              ? Icons.check_circle_rounded
              : _iconForAiContextItem(item.kind);

          return Material(
            color: isKeyboardSelected
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : Colors.transparent,
            child: InkWell(
              onTap: () {
                _aiContextMenuUsingKeyboard = false;
                unawaited(_applyAiContextSuggestion(item));
              },
              child: MouseRegion(
                onEnter: (_) {
                  if (!_aiContextMenuUsingKeyboard) return;
                  _aiContextMenuSelectedIndex = index;
                  _aiContextMenuUsingKeyboard = false;
                  _aiContextMenuOverlay?.markNeedsBuild();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.14)
                              : scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.9,
                                ),
                          borderRadius: BorderRadius.circular(FolioRadius.sm),
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.id == '__open_pages__')
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        )
                      else if (selected)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            l10n.aiAttachPageAlreadyAdded,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

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
                  elevation: 10,
                  shadowColor: scheme.shadow.withValues(alpha: 0.18),
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 280,
                      maxWidth: math.min(
                        360,
                        MediaQuery.sizeOf(context).width - 24,
                      ),
                      maxHeight: math.min(
                        420,
                        MediaQuery.sizeOf(context).height * 0.55,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isPages)
                                IconButton(
                                  tooltip: l10n.aiAttachMenuBack,
                                  onPressed: () {
                                    _aiContextMenuView =
                                        _AiContextMenuView.root;
                                    _aiContextQuery = '';
                                    _aiContextMenuSearchController.clear();
                                    _aiContextMenuOverlay?.markNeedsBuild();
                                  },
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPages
                                          ? l10n.aiAttachMenuSectionPages
                                          : l10n.aiAttachMenuTitle,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPages
                                          ? l10n.aiAttachPageSubtitle
                                          : l10n.aiAttachMenuSubtitle,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).closeButtonTooltip,
                                onPressed: _hideAiContextMenu,
                                icon: const Icon(Icons.close_rounded, size: 20),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                        if (isPages)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: TextField(
                              autofocus: pinned,
                              controller: _aiContextMenuSearchController,
                              onChanged: (value) {
                                _aiContextQuery = value;
                                _aiContextMenuOverlay?.markNeedsBuild();
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: l10n.aiAttachMenuSearchPagesHint,
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                filled: true,
                                fillColor: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.55),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    FolioRadius.md,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                            child: Text(
                              l10n.aiAttachMenuSectionActions,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        Flexible(
                          child: items.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    l10n.aiContextComposerHint,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  shrinkWrap: true,
                                  itemCount: items.length,
                                  itemBuilder: (context, index) =>
                                      actionTile(items[index], index),
                                ),
                        ),
                      ],
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
        return Icons.upload_file_rounded;
      case _AiContextItemKind.meetingNote:
        return Icons.mic_rounded;
      case _AiContextItemKind.editorSelection:
        return Icons.text_fields_rounded;
      case _AiContextItemKind.lastMeetingOnPage:
        return Icons.transcribe_rounded;
    }
  }

  void _stripComposerAtTokenIfAny() {
    final value = _chatInputController.value;
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return;
    final caret = selection.baseOffset;
    if (caret < 0 || caret > text.length) return;
    final prefix = text.substring(0, caret);
    final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(prefix);
    if (match == null) return;
    final replaceStart = match.start + (match.group(1)?.length ?? 0);
    final newText = text.replaceRange(replaceStart, caret, '');
    _chatInputController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: replaceStart),
    );
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
          _aiContextQuery = '';
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
        _hideAiContextMenu();
        break;
      case _AiContextItemKind.meetingNote:
        await _pickMeetingNoteAttachment();
        _hideAiContextMenu();
        break;
      case _AiContextItemKind.editorSelection:
        _aiAttachNextEditorSelection = true;
        _stripComposerAtTokenIfAny();
        _hideAiContextMenu();
        break;
      case _AiContextItemKind.lastMeetingOnPage:
        _aiAttachNextLastMeeting = true;
        _stripComposerAtTokenIfAny();
        _hideAiContextMenu();
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

  void _openCloudContextPickerFromButton() {
    _chatInputFocusNode.requestFocus();
    _aiContextMenuView = _AiContextMenuView.root;
    _aiContextQuery = '';
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
      case _AiContextItemKind.editorSelection:
      case _AiContextItemKind.lastMeetingOnPage:
        break;
    }
  }
}
