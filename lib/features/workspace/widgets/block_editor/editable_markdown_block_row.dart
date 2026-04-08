part of 'package:folio/features/workspace/widgets/block_editor.dart';

Widget _buildEditableMarkdownBlockRow(_BlockRowScope s) {
  final st = s.st;
  final block = s.block;
  final page = s.page;
  final scheme = s.scheme;
  final theme = s.theme;
  final context = s.context;
  final ctrl = s.ctrl;
  final focus = s.focus;
  final marker = s.marker;
  final dragHandle = s.dragHandle;
  final menu = s.menu;
  final showActions = s.showActions;
  final style = s.style;
  final compactReadOnlyMobile = s.compactReadOnlyMobile;
  final readOnlyMode = s.readOnlyMode;
  final appSettings = s.appSettings;
  final isParagraph = block.type == 'paragraph';
  final isListLine =
      block.type == 'todo' ||
      block.type == 'bullet' ||
      block.type == 'numbered';

  final allowsSlash = blockEditorTypeUsesSlashMenu(block.type);
  final String? slashTail = allowsSlash
      ? slashFilterFromBlockText(ctrl.text)
      : null;
  final showSlashMenu = slashTail != null && st._slashBlockId == block.id;
  final slashItems = showSlashMenu
      ? st._catalogFilteredForSlash(slashTail)
      : const <BlockTypeDef>[];
  final mentionTail = allowsSlash
      ? mentionFilterFromSelection(ctrl.text, ctrl.selection)
      : null;
  final showMentionMenu =
      !showSlashMenu && mentionTail != null && st._mentionBlockId == block.id;
  final mentionItems = showMentionMenu
      ? st._catalogFilteredForMention(mentionTail)
      : const <FolioPage>[];
  final slashPanelMaxH = math.min(
    192.0,
    math.max(100.0, MediaQuery.sizeOf(context).height * 0.25),
  );

  /// Vista previa mientras escribes: el [TextField] va **encima** (texto transparente)
  /// para no bloquear toques ni el cursor; el markdown queda detrás.
  /// Sin previa si solo hay `#`…`######` y espacios (el render no muestra nada útil).
  final showInlinePreview =
      allowsSlash &&
      !readOnlyMode &&
      !focus.hasFocus &&
      ctrl.text.trim().isNotEmpty &&
      !BlockEditorState._isIncompleteAtxHeadingLine(ctrl.text);

  var currentStyle = style;
  if (block.type == 'quote') {
    currentStyle = currentStyle.copyWith(
      fontStyle: FontStyle.italic,
      fontSize: currentStyle.fontSize! * 1.05,
      color: scheme.onSurface.withValues(alpha: 0.8),
    );
  }
  currentStyle = st._applyBlockAppearanceToTextStyle(
    currentStyle,
    scheme,
    block,
  );
  final appearance = st._blockAppearanceFor(block);
  final customBackground = st._blockBackgroundColorFor(
    scheme,
    appearance.backgroundRole,
  );
  final customBackgroundBorder = st._blockBackgroundBorderColorFor(
    scheme,
    appearance.backgroundRole,
  );

  final mdSheet = folioMarkdownStyleSheet(context, currentStyle, scheme);

  final field = TextField(
    controller: ctrl,
    focusNode: focus,
    readOnly: readOnlyMode,
    showCursor: !readOnlyMode,
    maxLines: null,
    minLines: 1,
    cursorColor: showInlinePreview ? scheme.onSurface : null,
    style: showInlinePreview
        ? currentStyle.copyWith(
            color: Colors.transparent,
            decoration: TextDecoration.none,
          )
        : currentStyle,
    textAlignVertical: isParagraph
        ? TextAlignVertical.top
        : TextAlignVertical.center,
    decoration: isListLine
        ? InputDecoration.collapsed(
            hintText: block.type == 'todo' ? 'Tarea…' : '',
          )
        : InputDecoration(
            border: InputBorder.none,
            isDense: true,
            filled: false,
            hintText: isParagraph ? 'Escribe…  /  para tipos de bloque' : null,
            contentPadding: EdgeInsets.zero,
          ),
  );

  final stackedField = showInlinePreview
      ? Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Align(
                alignment: isParagraph
                    ? AlignmentDirectional.topStart
                    : AlignmentDirectional.centerStart,
                child: FolioMarkdownPreview(
                  data: ctrl.text,
                  styleSheet: mdSheet,
                  onFolioPageLink: st._s.selectPage,
                ),
              ),
            ),
            field,
          ],
        )
      : field;

  final readOnlyMarkdown = FolioMarkdownPreview(
    data: ctrl.text,
    styleSheet: mdSheet,
    onFolioPageLink: st._s.selectPage,
  );

  final blockContent = readOnlyMode && allowsSlash
      ? readOnlyMarkdown
      : stackedField;

  Widget textContainer = blockContent;
  if (block.type == 'quote') {
    textContainer = Container(
      padding: EdgeInsets.fromLTRB(
        12,
        customBackground != null ? 8 : 2,
        customBackground != null ? 12 : 0,
        customBackground != null ? 8 : 2,
      ),
      decoration: BoxDecoration(
        color: customBackground,
        borderRadius: customBackground != null
            ? BorderRadius.circular(12)
            : null,
        border: Border(
          left: BorderSide(color: scheme.outlineVariant, width: 4),
        ),
      ),
      child: blockContent,
    );
  } else if (block.type == 'callout') {
    final calloutTone = calloutToneForIcon(block.icon);
    textContainer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            customBackground ?? calloutBackgroundForTone(scheme, calloutTone),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: customBackground != null
              ? customBackgroundBorder
              : calloutBorderForTone(scheme, calloutTone),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: calloutChipForTone(scheme, calloutTone),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: MouseRegion(
                      cursor: readOnlyMode
                          ? MouseCursor.defer
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: readOnlyMode
                            ? null
                            : () async {
                                final emoji = await st._pickEmoji(context);
                                if (emoji != null) {
                                  st._s.updateBlockIcon(
                                    page.id,
                                    block.id,
                                    emoji,
                                  );
                                }
                              },
                        child: FolioIconTokenView(
                          appSettings: appSettings,
                          token: block.icon,
                          fallbackText: '💡',
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tipo de callout',
                  enabled: !readOnlyMode,
                  onSelected: readOnlyMode
                      ? null
                      : (emoji) =>
                            st._s.updateBlockIcon(page.id, block.id, emoji),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: '💡', child: Text('💡 Info')),
                    PopupMenuItem(value: '✅', child: Text('✅ Éxito')),
                    PopupMenuItem(value: '⚠️', child: Text('⚠️ Warning')),
                    PopupMenuItem(value: '🚨', child: Text('🚨 Error')),
                    PopupMenuItem(value: 'ℹ️', child: Text('ℹ️ Nota')),
                  ],
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: scheme.onSurfaceVariant,
                  ),
                  constraints: const BoxConstraints(minWidth: 34),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Expanded(child: blockContent),
        ],
      ),
    );
  } else if (customBackground != null) {
    textContainer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: customBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: customBackgroundBorder),
      ),
      child: blockContent,
    );
  }

  final showFloatingToolbar =
      !readOnlyMode &&
      allowsSlash &&
      !showSlashMenu &&
      !showMentionMenu &&
      focus.hasFocus;

  /// Barra de formato **en el árbol del bloque** (no Overlay): evita capas a
  /// pantalla completa, hit-test erróneos y bloques grises gigantes.
  final Widget editorSlot = showFloatingToolbar
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            textContainer,
            Padding(
              padding: const EdgeInsets.only(top: FolioSpace.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FolioFormatToolbar(
                  controller: ctrl,
                  colorScheme: scheme,
                  textFocusNode: focus,
                  onOpenBlockAppearance: st._blockSupportsAppearance(block)
                      ? () => unawaited(
                          st._editBlockAppearance(
                            page,
                            block,
                            focusNode: focus,
                          ),
                        )
                      : null,
                  onMentionPage: (ctx) => st._toolbarMentionPage(ctx, ctrl),
                  onInsertUserMention: () =>
                      st._insertAtSelection(ctrl, '@usuario '),
                  onInsertDateMention: () => st._insertAtSelection(
                    ctrl,
                    '@${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(DateTime.now())} ',
                  ),
                  onInsertInlineMath: () =>
                      st._insertAtSelection(ctrl, r'\( x \)'),
                ),
              ),
            ),
          ],
        )
      : textContainer;

  final Widget textSlot;
  if (showSlashMenu) {
    final tail = slashTail;
    textSlot = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        editorSlot,
        Padding(
          padding: const EdgeInsets.only(top: FolioSpace.xs),
          child: BlockEditorFloatingPanel(
            scheme: scheme,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: slashPanelMaxH,
                minHeight: slashItems.isEmpty ? 48 : 72,
              ),
              child: slashItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Sin coincidencias',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Scrollbar(
                      controller: st._slashListScrollController,
                      interactive: false,
                      thumbVisibility: true,
                      thickness: 3,
                      radius: const Radius.circular(3),
                      child: BlockEditorInlineSlashList(
                        scrollController: st._slashListScrollController,
                        theme: theme,
                        scheme: scheme,
                        items: slashItems,
                        selectedIndex: slashItems.isEmpty
                            ? 0
                            : st._slashSelectedIndex.clamp(
                                0,
                                slashItems.length - 1,
                              ),
                        showSections: tail.trim().isEmpty,
                        onPick: st._applyInlineSlashChoice,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  } else if (showMentionMenu) {
    textSlot = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        editorSlot,
        Padding(
          padding: const EdgeInsets.only(top: FolioSpace.xs),
          child: BlockEditorFloatingPanel(
            scheme: scheme,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: slashPanelMaxH,
                minHeight: mentionItems.isEmpty ? 48 : 72,
              ),
              child: mentionItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Sin paginas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Scrollbar(
                      controller: st._mentionListScrollController,
                      interactive: false,
                      thumbVisibility: true,
                      thickness: 3,
                      radius: const Radius.circular(3),
                      child: BlockEditorInlineMentionList(
                        scrollController: st._mentionListScrollController,
                        theme: theme,
                        scheme: scheme,
                        items: mentionItems,
                        selectedIndex: mentionItems.isEmpty
                            ? 0
                            : st._mentionSelectedIndex.clamp(
                                0,
                                mentionItems.length - 1,
                              ),
                        onPick: st._applyInlineMentionChoice,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  } else {
    textSlot = editorSlot;
  }

  return BlockRowChrome(
    depth: block.depth,
    compactReadOnlyMobile: compactReadOnlyMobile,
    crossAxisAlignment: isParagraph
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center,
    menuSlot: st._blockMenuSlot(showActions: showActions, menu: menu),
    dragHandle: dragHandle,
    marker: marker,
    child: textSlot,
  );
}
