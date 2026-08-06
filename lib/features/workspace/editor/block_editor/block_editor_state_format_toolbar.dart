part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Format-toolbar overlay (shown on text selection) and the Quill Copilot
/// AI ghost-text suggestion overlay. Both are positioned via `Overlay`
/// entries anchored to the focused block's render tree, and both get
/// dismissed by the same conditions (read-only mode, slash/mention menu
/// open, focus lost). Split out of `block_editor_state.dart` as one
/// bounded region -- the plan's Phase C, done as a mixin (matching the
/// Phase A/B precedent) rather than a fully standalone constructor-
/// injected controller class, since that would require threading a large
/// callback surface for no behavior change and this file already has a
/// proven, low-risk mixin extraction pattern established.
mixin _FormatToolbarOverlay on State<BlockEditor> {
  BlockEditorState get _toolbarSelf => this as BlockEditorState;

  void _onToolbarPointerDown(String blockId) {
    final st = _toolbarSelf;
    st._toolbarInteractionToken++;
    st._toolbarInteractionBlockId = blockId;
    if (!mounted) return;
    setState(() {});
    _scheduleFormatToolbarOverlayUpdate();
  }

  void _onToolbarPointerUpOrCancel(String blockId) {
    final st = _toolbarSelf;
    if (st._toolbarInteractionBlockId != blockId) return;
    final token = st._toolbarInteractionToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Si hubo otra interacción más reciente, no limpiar aún.
      if (token != st._toolbarInteractionToken) return;
      if (st._toolbarInteractionBlockId != blockId) return;
      st._toolbarInteractionBlockId = null;
      setState(() {});
      _scheduleFormatToolbarOverlayUpdate();
    });
  }

  GlobalKey _formatToolbarHostKeyFor(String blockId) =>
      _toolbarSelf._formatToolbarHostKeys.putIfAbsent(blockId, GlobalKey.new);

  void _removeFormatToolbarOverlay() {
    final st = _toolbarSelf;
    st._formatToolbarOverlayEntry?.remove();
    st._formatToolbarOverlayEntry = null;
  }

  void _scheduleFormatToolbarOverlayUpdate() {
    final st = _toolbarSelf;
    if (st._formatToolbarOverlayPostFrameScheduled) return;
    st._formatToolbarOverlayPostFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      st._formatToolbarOverlayPostFrameScheduled = false;
      if (!mounted) return;
      _updateFormatToolbarOverlay();
    });
  }

  quill.QuillRawEditorState? _findQuillRawEditorState(BuildContext context) {
    quill.QuillRawEditorState? found;
    void walk(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is quill.QuillRawEditorState) {
        found = e.state as quill.QuillRawEditorState;
        return;
      }
      e.visitChildren(walk);
    }

    walk(context as Element);
    return found;
  }

  EditableTextState? _findEditableTextState(BuildContext context) {
    EditableTextState? found;
    void walk(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        found = e.state as EditableTextState;
        return;
      }
      e.visitChildren(walk);
    }

    walk(context as Element);
    return found;
  }

  Offset? _formatToolbarAnchorGlobal({
    required String blockId,
    required BuildContext hostContext,
    required FolioBlock block,
  }) {
    final st = _toolbarSelf;
    final qc = st._quillByBlockId[blockId];
    if (qc != null && _stylableBlockTypes.contains(block.type)) {
      final raw = _findQuillRawEditorState(hostContext);
      if (raw == null) return null;
      return raw.contextMenuAnchors.primaryAnchor;
    }
    final ed = _findEditableTextState(hostContext);
    if (ed == null) return null;
    return ed.contextMenuAnchors.primaryAnchor;
  }

  void _updateFormatToolbarOverlay() {
    final st = _toolbarSelf;
    if (!mounted) return;
    if (widget.readOnlyMode) {
      _removeFormatToolbarOverlay();
      return;
    }
    final page = st._s.selectedPage;
    if (page == null) {
      _removeFormatToolbarOverlay();
      return;
    }

    final bid = st._toolbarInteractionBlockId ?? st._selectionActiveBlockId;
    if (bid == null) {
      _removeFormatToolbarOverlay();
      return;
    }

    FolioBlock? block;
    for (final b in page.blocks) {
      if (b.id == bid) {
        block = b;
        break;
      }
    }
    if (block == null) {
      _removeFormatToolbarOverlay();
      return;
    }

    if (!blockEditorTypeUsesSlashMenu(block.type)) {
      _removeFormatToolbarOverlay();
      return;
    }

    if (st._slashBlockId == bid || st._mentionBlockId == bid) {
      _removeFormatToolbarOverlay();
      return;
    }

    final hostKey = st._formatToolbarHostKeys[bid];
    final hostCtx = hostKey?.currentContext;
    if (hostCtx == null) {
      _removeFormatToolbarOverlay();
      return;
    }

    final anchor = _formatToolbarAnchorGlobal(
      blockId: bid,
      hostContext: hostCtx,
      block: block,
    );
    if (anchor == null) {
      _removeFormatToolbarOverlay();
      return;
    }

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      return;
    }

    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.sizeOf(context);
    const toolbarMaxW = 560.0;
    const toolbarH = 56.0;
    const gap = 6.0;
    final width = math.min(toolbarMaxW, media.width - 16);
    var left = anchor.dx - width / 2;
    left = left.clamp(8.0, math.max(8.0, media.width - width - 8.0));
    var top = anchor.dy - toolbarH - gap;
    top = top.clamp(8.0, math.max(8.0, media.height - toolbarH - 8.0));

    final idx = st._controllerBlockIds.indexOf(bid);
    if (idx < 0 || idx >= st._controllers.length || idx >= st._focusNodes.length) {
      _removeFormatToolbarOverlay();
      return;
    }
    final ctrl = st._controllers[idx];
    final focus = st._focusNodes[idx];
    final FolioBlock forToolbar = block;
    final quillCtrl = _stylableBlockTypes.contains(forToolbar.type)
        ? st._ensureQuillController(pageId: page.id, block: forToolbar)
        : null;

    st._formatToolbarOverlayEntry?.remove();
    st._formatToolbarOverlayEntry = OverlayEntry(
      builder: (overlayCtx) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              height: toolbarH,
              child: Material(
                elevation: 6,
                color: Colors.transparent,
                shadowColor: scheme.shadow.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: quillCtrl != null
                    ? FolioQuillFormatToolbar(
                        controller: quillCtrl,
                        colorScheme: scheme,
                        focusNode: focus,
                        onInteractionStart: () => _onToolbarPointerDown(bid),
                        onInteractionEnd: () => _onToolbarPointerUpOrCancel(bid),
                        onAskQuill: widget.readOnlyMode ||
                                widget.onAiSlashCommand == null
                            ? null
                            : () => st.showAiSelectionPopover(
                                blockId: forToolbar.id,
                              ),
                      )
                    : FolioFormatToolbar(
                        controller: ctrl,
                        colorScheme: scheme,
                        textFocusNode: focus,
                        onInteractionStart: () => _onToolbarPointerDown(bid),
                        onInteractionEnd: () => _onToolbarPointerUpOrCancel(bid),
                        onAskQuill: widget.readOnlyMode ||
                                widget.onAiSlashCommand == null
                            ? null
                            : () => st.showAiSelectionPopover(
                                blockId: forToolbar.id,
                              ),
                        onOpenBlockAppearance: st._blockSupportsAppearance(forToolbar)
                            ? () => unawaited(
                                st._editBlockAppearance(
                                  page,
                                  forToolbar,
                                  focusNode: focus,
                                ),
                              )
                            : null,
                        onMentionPage: (ctx) => st._toolbarMentionPage(ctx, ctrl),
                        onInsertUserMention: () => st._insertAtSelection(ctrl, '@usuario '),
                        onInsertDateMention: () => st._insertAtSelection(
                          ctrl,
                          '@${DateFormat.yMMMd(Localizations.localeOf(overlayCtx).toLanguageTag()).format(DateTime.now())} ',
                        ),
                        onInsertInlineMath: () =>
                            st._insertAtSelection(ctrl, r'\( x \)'),
                      ),
              ),
            ),
          ],
        );
      },
    );
    overlayState.insert(st._formatToolbarOverlayEntry!);
  }

  void _removeQuillCopilotOverlay() {
    final st = _toolbarSelf;
    st._quillCopilotOverlayEntry?.remove();
    st._quillCopilotOverlayEntry = null;
  }

  void _scheduleQuillCopilotOverlayUpdate() {
    final st = _toolbarSelf;
    if (st._quillCopilotOverlayPostFrameScheduled) return;
    st._quillCopilotOverlayPostFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      st._quillCopilotOverlayPostFrameScheduled = false;
      if (!mounted) return;
      _updateQuillCopilotOverlay();
    });
  }

  void _updateQuillCopilotOverlay() {
    final st = _toolbarSelf;
    if (!mounted || widget.readOnlyMode) {
      _removeQuillCopilotOverlay();
      return;
    }
    final bid = st._quillCopilotSuggestionBlockId;
    final suggestion = st._quillCopilotSuggestionText;
    if (bid == null || suggestion == null || suggestion.isEmpty) {
      _removeQuillCopilotOverlay();
      return;
    }

    final page = st._s.selectedPage;
    if (page == null) {
      _removeQuillCopilotOverlay();
      return;
    }
    FolioBlock? block;
    for (final b in page.blocks) {
      if (b.id == bid) {
        block = b;
        break;
      }
    }
    if (block == null || !_stylableBlockTypes.contains(block.type)) {
      _removeQuillCopilotOverlay();
      return;
    }

    if (st._slashBlockId == bid || st._mentionBlockId == bid) {
      _removeQuillCopilotOverlay();
      return;
    }

    final idx = st._controllerBlockIds.indexOf(bid);
    if (idx < 0 || idx >= st._focusNodes.length) {
      _removeQuillCopilotOverlay();
      return;
    }
    if (!st._focusNodes[idx].hasFocus) {
      _removeQuillCopilotOverlay();
      return;
    }

    final qc = st._quillByBlockId[bid];
    if (qc == null) {
      _removeQuillCopilotOverlay();
      return;
    }

    final hostKey = st._formatToolbarHostKeys[bid];
    final hostCtx = hostKey?.currentContext;
    if (hostCtx == null) {
      _removeQuillCopilotOverlay();
      return;
    }
    final raw = _findQuillRawEditorState(hostCtx);
    if (raw == null) {
      _removeQuillCopilotOverlay();
      return;
    }

    final renderEditor = raw.renderEditor;
    final localRect = renderEditor.getLocalRectForCaret(qc.selection.extent);
    final globalPoint = renderEditor.localToGlobal(localRect.topRight);

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    final scheme = Theme.of(context).colorScheme;
    final baseStyle = st._styleFor(block.type, Theme.of(context).textTheme);
    final media = MediaQuery.sizeOf(context);
    final maxW = math.max(40.0, media.width - globalPoint.dx - 8.0);

    st._quillCopilotOverlayEntry?.remove();
    st._quillCopilotOverlayEntry = OverlayEntry(
      builder: (overlayCtx) {
        return Stack(
          children: [
            Positioned(
              left: globalPoint.dx,
              top: globalPoint.dy,
              width: maxW,
              child: IgnorePointer(
                child: Text(
                  suggestion,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: baseStyle.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlayState.insert(st._quillCopilotOverlayEntry!);
  }

  KeyEventResult? _handleQuillCopilotTabKey(String blockId, KeyEvent event) {
    final st = _toolbarSelf;
    if (event.logicalKey != LogicalKeyboardKey.tab) return null;
    if (event is! KeyDownEvent) return null;
    if (st._quillCopilotSuggestionBlockId != blockId) return null;
    final suggestion = st._quillCopilotSuggestionText;
    if (suggestion == null || suggestion.isEmpty) return null;
    final qc = st._quillByBlockId[blockId];
    if (qc == null) return null;

    final offset = qc.selection.baseOffset;
    st._quillCopilotSuggestionBlockId = null;
    st._quillCopilotSuggestionText = null;
    _removeQuillCopilotOverlay();

    qc.replaceText(offset, 0, suggestion, null);
    qc.updateSelection(
      TextSelection.collapsed(offset: offset + suggestion.length),
      quill.ChangeSource.local,
    );
    st._quillFlushNowByBlockId[blockId]?.call();
    st._scheduleQuillCopilotProbe(blockId);
    return KeyEventResult.handled;
  }
}
