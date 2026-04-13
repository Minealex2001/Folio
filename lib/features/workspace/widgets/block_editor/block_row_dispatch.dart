part of 'package:folio/features/workspace/widgets/block_editor.dart';

Widget? _buildSpecialBlockRowOrNull(_BlockRowScope s) {
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
  final showInlineEditControls = s.showInlineEditControls;
  final index = s.index;
  final readOnlyMode = s.readOnlyMode;

  if (block.type == 'image') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: Focus(
              focusNode: focus,
              child: GestureDetector(
                onTap: () => focus.requestFocus(),
                behavior: HitTestBehavior.opaque,
                child: st._imageBlockBody(
                  scheme,
                  block,
                  page,
                  index,
                  showActions || focus.hasFocus,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'table') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: IgnorePointer(
              ignoring: readOnlyMode,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: readOnlyMode
                    ? null
                    : () {
                        focus.requestFocus();
                      },
                child: TableBlockEditor(
                  json: block.text,
                  scheme: scheme,
                  textTheme: theme.textTheme,
                  firstCellFocusNode: focus,
                  showToolbar: showInlineEditControls,
                  onChanged: (enc) =>
                      st._onTableEncoded(page.id, block.id, index, enc),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'database') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: IgnorePointer(
              ignoring: readOnlyMode,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: readOnlyMode ? null : () {},
                child: DatabaseBlockEditor(
                  json: block.text,
                  scheme: scheme,
                  textTheme: theme.textTheme,
                  controlsVisible: showInlineEditControls,
                  onChanged: (enc) =>
                      st._onTableEncoded(page.id, block.id, index, enc),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'equation') {
    final codeCtrl = ctrl as CodeController;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'LaTeX',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CodeTheme(
                    data: folioCodeThemeData(theme),
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      child: CodeField(
                        key: ObjectKey(focus),
                        controller: codeCtrl,
                        focusNode: focus,
                        readOnly: readOnlyMode,
                        minLines: 2,
                        maxLines: null,
                        wrap: true,
                        textStyle: st._styleFor('code', theme.textTheme),
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FolioEquationPreview(
                  latex: block.text,
                  textStyle: theme.textTheme.bodyLarge,
                  scheme: scheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'mermaid') {
    final codeCtrl = ctrl as CodeController;
    final showSourceEditor =
        block.text.trim().isEmpty ||
        st._mermaidEditingSourceIds.contains(block.id);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Mermaid',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
                if (showSourceEditor) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CodeTheme(
                      data: folioCodeThemeData(theme),
                      child: ColoredBox(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                        child: CodeField(
                          key: ObjectKey(focus),
                          controller: codeCtrl,
                          focusNode: focus,
                          readOnly: readOnlyMode,
                          minLines: 3,
                          maxLines: null,
                          wrap: true,
                          textStyle: st._styleFor('code', theme.textTheme),
                          decoration: const BoxDecoration(),
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FolioMermaidPreview(source: block.text),
                ] else
                  Focus(
                    focusNode: focus,
                    child: GestureDetector(
                      onTap: () => focus.requestFocus(),
                      behavior: HitTestBehavior.opaque,
                      child: FolioMermaidPreview(source: block.text),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'code') {
    final codeCtrl = ctrl as CodeController;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MenuAnchor(
                      style: MenuStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          scheme.surfaceContainerHigh,
                        ),
                        surfaceTintColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        shadowColor: WidgetStatePropertyAll(
                          scheme.shadow.withValues(alpha: 0.14),
                        ),
                        elevation: const WidgetStatePropertyAll(8),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 8),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      menuChildren: [
                        for (final o in st._codeLanguageOptionsForBlock(block))
                          MenuItemButton(
                            leadingIcon: Icon(
                              iconForCodeLanguageOption(o),
                              size: 20,
                            ),
                            trailingIcon:
                                o.id == st._codeLangDropdownValue(block)
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: scheme.primary,
                                  )
                                : null,
                            onPressed: () {
                              st._onCodeLanguagePicked(
                                page.id,
                                block.id,
                                index,
                                o.id,
                              );
                            },
                            child: Text(o.label),
                          ),
                      ],
                      builder: (context, menuController, child) {
                        final id = st._codeLangDropdownValue(block);
                        final label = st._codeLangLabelForId(id);
                        final langIcon = codeLanguageIcon(id);
                        return Material(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              if (menuController.isOpen) {
                                menuController.close();
                              } else {
                                menuController.open();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    langIcon,
                                    size: 20,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 22,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CodeTheme(
                    data: folioCodeThemeData(theme),
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      child: CodeField(
                        // flutter_code_editor no actualiza el FocusNode interno en didUpdateWidget;
                        // sin esta clave, al resincronizar controladores se reutiliza el State con un nodo ya disposed.
                        key: ObjectKey(focus),
                        controller: codeCtrl,
                        focusNode: focus,
                        readOnly: readOnlyMode,
                        minLines: 3,
                        maxLines: null,
                        wrap: true,
                        textStyle: st._styleFor('code', theme.textTheme),
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'divider') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  if (block.type == 'file') {
    final wf = st._imageWidthFor(block);
    final boxH = (260 * (0.4 + 0.6 * wf)).clamp(140.0, 420.0);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final targetW = (maxW * wf).clamp(120.0, maxW);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: targetW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showActions)
                          st._blockMediaWidthToolbar(page, block, theme),
                        st._buildCollabUploadProgressBadge(
                          block.id,
                          theme,
                          scheme,
                        ),
                        SizedBox(
                          height: boxH,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: FutureBuilder<File?>(
                              future: st._resolveBlockUrlFileCached(block.url),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snap.hasError) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        ).fileResolveError,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: scheme.error),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton.tonalIcon(
                                        onPressed: () => st._pickFileForBlock(
                                          page.id,
                                          block.id,
                                        ),
                                        icon: const Icon(
                                          Icons.attach_file_rounded,
                                        ),
                                        label: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).replaceFile,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                final file = snap.data;
                                if (file == null) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if ((block.url ?? '').trim().isNotEmpty)
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).fileMissing,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: scheme.error),
                                        ),
                                      const SizedBox(height: 8),
                                      FilledButton.tonalIcon(
                                        onPressed: () => st._pickFileForBlock(
                                          page.id,
                                          block.id,
                                        ),
                                        icon: const Icon(
                                          Icons.attach_file_rounded,
                                        ),
                                        label: Text(
                                          (block.url ?? '').trim().isEmpty
                                              ? AppLocalizations.of(
                                                  context,
                                                ).chooseFile
                                              : AppLocalizations.of(
                                                  context,
                                                ).replaceFile,
                                        ),
                                      ),
                                      if ((block.url ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        TextButton(
                                          onPressed: () => st._clearBlockUrl(
                                            page.id,
                                            block.id,
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).removeFile,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                }
                                return FolioFilePreviewCard(
                                  file: file,
                                  theme: theme,
                                  scheme: scheme,
                                  onOpenExternal: () =>
                                      st._openBlockUrlExternal(block.url),
                                  onReplace: () =>
                                      st._pickFileForBlock(page.id, block.id),
                                  onClear: () =>
                                      st._clearBlockUrl(page.id, block.id),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'bookmark') {
    final url = (block.url ?? '').trim();
    final host = Uri.tryParse(url)?.host ?? '';
    final wf = st._imageWidthFor(block);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final targetW = (maxW * wf).clamp(120.0, maxW);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: targetW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showActions)
                          st._blockMediaWidthToolbar(page, block, theme),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (host.isNotEmpty)
                                Text(
                                  host,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              if (host.isNotEmpty) const SizedBox(height: 6),
                              TextField(
                                controller: ctrl,
                                focusNode: focus,
                                readOnly: readOnlyMode,
                                showCursor: !readOnlyMode,
                                maxLines: null,
                                minLines: 1,
                                style: theme.textTheme.titleSmall,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: AppLocalizations.of(
                                    context,
                                  ).bookmarkTitleHint,
                                ),
                              ),
                              if (url.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).bookmarkBlockHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                SelectableText(
                                  url,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: () => unawaited(
                                        st._openBlockUrlExternal(block.url),
                                      ),
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).bookmarkOpenLink,
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => unawaited(
                                        st._editBookmarkUrlDialog(
                                          page.id,
                                          block.id,
                                          index,
                                        ),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).bookmarkSetUrl,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'embed') {
    final url = (block.url ?? '').trim();
    final wf = st._imageWidthFor(block);
    final embedH = (360 * (0.45 + 0.55 * wf)).clamp(200.0, 560.0);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final targetW = (maxW * wf).clamp(120.0, maxW);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: targetW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showActions)
                          st._blockMediaWidthToolbar(page, block, theme),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: embedH,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.35,
                              ),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: url.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).embedEmptyHint,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  )
                                : FolioEmbedWebView(url: url, scheme: scheme),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'audio') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: FutureBuilder<File?>(
                future: st._resolveBlockUrlFileCached(block.url),
                builder: (context, snap) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      st._buildCollabUploadProgressBadge(
                        block.id,
                        theme,
                        scheme,
                      ),
                      if (snap.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (snap.data == null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Elige un archivo de audio',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: () => unawaited(
                                st._pickAudioForBlock(page.id, block.id),
                              ),
                              icon: const Icon(Icons.audio_file_rounded),
                              label: const Text('Elegir audio…'),
                            ),
                          ],
                        )
                      else
                        FolioAudioBlockPlayer(file: snap.data!, scheme: scheme),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'meeting_note') {
    final rawU = (block.url ?? '').trim();
    final transcriptPreview = block.text.trim();
    final hasMeetingContent = rawU.isNotEmpty || transcriptPreview.isNotEmpty;
    final compactView =
        hasMeetingContent &&
        !showInlineEditControls &&
        !showActions &&
        !focus.hasFocus;
    final previewText = transcriptPreview.isEmpty
        ? 'Sin transcripcion'
        : transcriptPreview;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: compactView
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.meeting_room_outlined,
                              size: 16,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.meetingNoteTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (rawU.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.audio_file_rounded,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          previewText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    )
                  : (rawU.isEmpty
                        ? MeetingNoteBlockWidget(
                            block: block,
                            page: page,
                            session: st._s,
                            appSettings: st.widget.appSettings,
                            scheme: scheme,
                            resolvedFile: null,
                            folioCloudEntitlements: s.folioCloudEntitlements,
                          )
                        : FutureBuilder<File?>(
                            future: st._resolveBlockUrlFileCached(rawU),
                            builder: (ctx, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return MeetingNoteBlockWidget(
                                block: block,
                                page: page,
                                session: st._s,
                                appSettings: st.widget.appSettings,
                                scheme: scheme,
                                resolvedFile: snap.data,
                                folioCloudEntitlements:
                                    s.folioCloudEntitlements,
                              );
                            },
                          )),
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'video') {
    final rawU = (block.url ?? '').trim();
    final wf = st._imageWidthFor(block);
    final ytId = rawU.startsWith('http://') || rawU.startsWith('https://')
        ? folioYoutubeVideoIdFromUrl(rawU)
        : null;
    if (ytId != null) {
      final vidH = (220 * (0.45 + 0.55 * wf)).clamp(120.0, 320.0);
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            st._blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final targetW = (maxW * wf).clamp(120.0, maxW);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: targetW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showActions)
                            st._blockMediaWidthToolbar(page, block, theme),
                          st._buildCollabUploadProgressBadge(
                            block.id,
                            theme,
                            scheme,
                          ),
                          Container(
                            height: vidH,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: FolioYoutubePreviewCard(
                                      pageUrl: rawU,
                                      videoId: ytId,
                                      scheme: scheme,
                                      compact: true,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      st._clearBlockUrl(page.id, block.id),
                                  child: Text(
                                    AppLocalizations.of(context).removeVideo,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    final localH = (200 * (0.45 + 0.55 * wf)).clamp(120.0, 300.0);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final targetW = (maxW * wf).clamp(120.0, maxW);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: targetW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showActions)
                          st._blockMediaWidthToolbar(page, block, theme),
                        st._buildCollabUploadProgressBadge(
                          block.id,
                          theme,
                          scheme,
                        ),
                        SizedBox(
                          height: localH,
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: FutureBuilder<File?>(
                              future: st._resolveBlockUrlFileCached(block.url),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snap.hasError) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        ).videoResolveError,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: scheme.error),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton.tonal(
                                        onPressed: () => st._pickVideoForBlock(
                                          page.id,
                                          block.id,
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).replaceVideo,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                final file = snap.data;
                                if (file == null) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if ((block.url ?? '').trim().isNotEmpty)
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).videoMissing,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: scheme.error),
                                        ),
                                      const SizedBox(height: 8),
                                      FilledButton.tonal(
                                        onPressed: () => st._pickVideoForBlock(
                                          page.id,
                                          block.id,
                                        ),
                                        child: Text(
                                          (block.url ?? '').trim().isEmpty
                                              ? AppLocalizations.of(
                                                  context,
                                                ).chooseVideo
                                              : AppLocalizations.of(
                                                  context,
                                                ).replaceVideo,
                                        ),
                                      ),
                                      if ((block.url ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        TextButton(
                                          onPressed: () => st._clearBlockUrl(
                                            page.id,
                                            block.id,
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).removeVideo,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                }
                                return FolioEmbeddedVideoPlayer(
                                  key: ValueKey(file.path),
                                  file: file,
                                  scheme: scheme,
                                  onOpenExternal: () =>
                                      st._openBlockUrlExternal(block.url),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'toggle') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: FolioToggleBlockBody(
              pageId: page.id,
              block: block,
              session: st._s,
              colorScheme: scheme,
              textTheme: theme.textTheme,
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'toc') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: FolioTocBlockBody(
              pageId: page.id,
              blocks: page.blocks,
              session: st._s,
              scheme: scheme,
              textTheme: theme.textTheme,
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'breadcrumb') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: FolioBreadcrumbBlockBody(
              pageId: page.id,
              session: st._s,
              scheme: scheme,
              textTheme: theme.textTheme,
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'child_page') {
    final cid = block.text.trim();
    FolioPage? child;
    try {
      child = st._s.pages.firstWhere((p) => p.id == cid);
    } catch (_) {
      child = null;
    }
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bloque página',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (child != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(child.title),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => st._s.selectPage(child!.id),
                    )
                  else
                    Text(
                      'Sin subpágina enlazada.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (!readOnlyMode) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            st._s.createChildPageLinkedToBlock(
                              pageId: page.id,
                              blockId: block.id,
                            );
                            st._blockRowSetState(() {});
                          },
                          child: const Text('Crear subpágina'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await st._pickPageForChildBlock(
                              context,
                              excludeId: page.id,
                            );
                            if (picked != null && s.st.mounted) {
                              st._s.updateBlockText(page.id, block.id, picked);
                              st._blockRowSetState(() {});
                            }
                          },
                          child: const Text('Enlazar página…'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'template_button') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: FolioTemplateButtonBlockBody(
              pageId: page.id,
              block: block,
              session: st._s,
              scheme: scheme,
              textTheme: theme.textTheme,
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'task') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: FolioTaskBlockBody(
              pageId: page.id,
              block: block,
              session: st._s,
              scheme: scheme,
              textTheme: theme.textTheme,
            ),
          ),
        ],
      ),
    );
  }

  if (block.type == 'column_list') {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          st._blockMenuSlot(showActions: showActions, menu: menu),
          dragHandle,
          marker,
          Expanded(
            child: FolioColumnListBlockBody(
              pageId: page.id,
              block: block,
              session: st._s,
              scheme: scheme,
              textTheme: theme.textTheme,
              showActions: showActions,
            ),
          ),
        ],
      ),
    );
  }

  return null;
}
