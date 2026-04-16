part of 'workspace_page.dart';

extension _WorkspacePageToolsModule on _WorkspacePageState {
  String _suggestMarkdownFileName(String title) {
    final base = title.trim().isEmpty ? 'page' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'page' : safe}.md';
  }

  String _suggestHtmlFileName(String title) {
    final base = title.trim().isEmpty ? 'page' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'page' : safe}.html';
  }

  String _suggestTxtFileName(String title) {
    final base = title.trim().isEmpty ? 'page' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'page' : safe}.txt';
  }

  String _suggestJsonFileName(String title) {
    final base = title.trim().isEmpty ? 'page' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'page' : safe}.json';
  }

  String _suggestPdfFileName(String title) {
    final base = title.trim().isEmpty ? 'page' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'page' : safe}.pdf';
  }

  Future<_FolioPageExportFormat?> _showExportFormatMenu(
    BuildContext anchorContext,
    AppLocalizations l10n,
  ) async {
    final theme = Theme.of(anchorContext);
    final scheme = theme.colorScheme;

    final buttonBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return null;

    final buttonRect =
        buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
        buttonBox.size;
    final position = RelativeRect.fromRect(
      buttonRect,
      Offset.zero & overlayBox.size,
    );

    final maxW = math.min(420.0, overlayBox.size.width - 24.0);
    final menuW = maxW.clamp(280.0, 420.0);
    final maxH = math.min(420.0, overlayBox.size.height - 24.0);

    Widget tile({
      required _FolioPageExportFormat value,
      required IconData icon,
      required String label,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.pop(anchorContext, value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: scheme.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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

    return showMenu<_FolioPageExportFormat>(
      context: anchorContext,
      position: position,
      constraints: BoxConstraints.tightFor(width: menuW),
      items: [
        PopupMenuItem<_FolioPageExportFormat>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: BlockEditorFloatingPanel(
              scheme: scheme,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                      child: Text(
                        l10n.exportPageDialogTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
                        children: [
                          tile(
                            value: _FolioPageExportFormat.markdown,
                            icon: Icons.description_outlined,
                            label: l10n.exportPageFormatMarkdown,
                          ),
                          tile(
                            value: _FolioPageExportFormat.html,
                            icon: Icons.language_rounded,
                            label: l10n.exportPageFormatHtml,
                          ),
                          tile(
                            value: _FolioPageExportFormat.txt,
                            icon: Icons.subject_rounded,
                            label: l10n.exportPageFormatTxt,
                          ),
                          tile(
                            value: _FolioPageExportFormat.json,
                            icon: Icons.data_object_rounded,
                            label: l10n.exportPageFormatJson,
                          ),
                          tile(
                            value: _FolioPageExportFormat.pdf,
                            icon: Icons.picture_as_pdf_rounded,
                            label: l10n.exportPageFormatPdf,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportCurrentPage([BuildContext? anchorContext]) async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final format = await _showExportFormatMenu(anchorContext ?? context, l10n);
    if (format == null) return;

    switch (format) {
      case _FolioPageExportFormat.markdown:
        return _exportCurrentPageToMarkdown();
      case _FolioPageExportFormat.html:
        return _exportCurrentPageToHtml();
      case _FolioPageExportFormat.txt:
        return _exportCurrentPageToTxt();
      case _FolioPageExportFormat.json:
        return _exportCurrentPageToJson();
      case _FolioPageExportFormat.pdf:
        return _exportCurrentPageToPdf();
    }
  }

  Future<FolioMarkdownImportMode?> _askMarkdownImportMode() {
    final page = _s.selectedPage;
    if (page == null) {
      return Future.value(FolioMarkdownImportMode.newPage);
    }
    final l10n = AppLocalizations.of(context);
    return showDialog<FolioMarkdownImportMode>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.markdownImportModeDialogTitle),
        content: Text(l10n.markdownImportModeDialogBody),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.newPage),
            child: Text(l10n.markdownImportModeNewPage),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.appendToCurrentPage),
            child: Text(l10n.markdownImportModeAppend),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.replaceCurrentPage),
            child: Text(l10n.markdownImportModeReplace),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentPageAsTemplate() async {
    final page = _s.selectedPage;
    if (page == null) return;
    final l10n = AppLocalizations.of(context);
    String name = page.title.isNotEmpty ? page.title : l10n.untitledFallback;
    String description = '';
    String category = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FolioDialog(
          title: Text(l10n.saveAsTemplateTitle),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.templateNameHint),
                  controller: TextEditingController(text: name),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateDescriptionHint,
                  ),
                  onChanged: (v) => description = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateCategoryHint,
                  ),
                  onChanged: (v) => category = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    _s.savePageAsTemplate(
      page.id,
      name: name.trim().isNotEmpty ? name.trim() : null,
      description: description.trim(),
      category: category.trim(),
    );
    if (!mounted) return;
    _snack(l10n.templateSaved);
  }

  Future<void> _importDocumentFile() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown', 'txt', 'json', 'html', 'htm'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final path = pick.files.single.path;
    if (path == null || path.trim().isEmpty) {
      _snack(l10n.markdownImportCouldNotReadPath);
      return;
    }
    final mode = await _askMarkdownImportMode();
    if (mode == null) return;
    try {
      final name = pick.files.single.name;
      final lower = name.toLowerCase();
      final raw = await File(path).readAsString();
      final title = name.replaceFirst(RegExp(r'\.[^.]+$'), '');

      final FolioMarkdownImportResult result;
      if (lower.endsWith('.json')) {
        result = _s.importPageJsonDocument(raw, mode: mode);
      } else if (lower.endsWith('.html') || lower.endsWith('.htm')) {
        result = _s.importHtmlDocument(raw, title: title, mode: mode);
      } else {
        // .md/.markdown/.txt => Markdown
        result = _s.importMarkdownDocument(raw, title: title, mode: mode);
      }
      if (!mounted) return;
      _snack(
        l10n.markdownImportedBlocks(result.pageTitle, result.blockCount),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.markdownImportFailedWithError('$e'));
    }
  }

  Future<void> _exportCurrentPageToMarkdown() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final destination = await FilePicker.saveFile(
      dialogTitle: l10n.exportMarkdownFileDialogTitle,
      fileName: _suggestMarkdownFileName(page.title),
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      final markdown = _s.exportPageAsMarkdown(page.id);
      await File(destination).writeAsString(markdown);
      if (!mounted) return;
      _snack(l10n.markdownExportSuccess);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.markdownExportFailedWithError('$e'));
    }
  }

  Future<void> _exportCurrentPageToHtml() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final destination = await FilePicker.saveFile(
      dialogTitle: l10n.exportHtmlFileDialogTitle,
      fileName: _suggestHtmlFileName(page.title),
      type: FileType.custom,
      allowedExtensions: const ['html'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      final html = folioPageExportHtmlDocument(
        page,
        pagePublishedSubtitle: l10n.pageHtmlExportPublishedWithFolio,
      );
      await File(destination).writeAsString(html);
      if (!mounted) return;
      _snack(l10n.htmlExportSuccess);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.htmlExportFailedWithError('$e'));
    }
  }

  Future<void> _exportCurrentPageToTxt() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final destination = await FilePicker.saveFile(
      dialogTitle: l10n.exportTxtFileDialogTitle,
      fileName: _suggestTxtFileName(page.title),
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      await File(destination).writeAsString(page.plainTextContent);
      if (!mounted) return;
      _snack(l10n.txtExportSuccess);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.txtExportFailedWithError('$e'));
    }
  }

  Future<void> _exportCurrentPageToJson() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final destination = await FilePicker.saveFile(
      dialogTitle: l10n.exportJsonFileDialogTitle,
      fileName: _suggestJsonFileName(page.title),
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (destination == null || destination.trim().isNotEmpty == false) return;
    try {
      final payload = <String, Object?>{
        'schema': 'folio.page.v1',
        'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
        'page': page.toJson(),
      };
      final json = const JsonEncoder.withIndent('  ').convert(payload);
      await File(destination).writeAsString(json);
      if (!mounted) return;
      _snack(l10n.jsonExportSuccess);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.jsonExportFailedWithError('$e'));
    }
  }

  Future<void> _exportCurrentPageToPdf() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final destination = await FilePicker.saveFile(
      dialogTitle: l10n.exportPdfFileDialogTitle,
      fileName: _suggestPdfFileName(page.title),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      final bytes = await folioPageExportPdfBytes(
        page: page,
        pagePublishedSubtitle: l10n.pageHtmlExportPublishedWithFolio,
      );
      await File(destination).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _snack(l10n.pdfExportSuccess);
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.pdfExportFailedWithError('$e'));
    }
  }

  String _suggestWebSlugFromTitle(String title) {
    var s = title.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.isEmpty) return 'page';
    if (s.length > 48) {
      s = s.substring(0, 48).replaceAll(RegExp(r'-+$'), '');
    }
    return s.isEmpty ? 'page' : s;
  }

  Future<String?> _showPublishWebSlugMenu({
    required BuildContext anchorContext,
    required TextEditingController slugController,
    required AppLocalizations l10n,
  }) async {
    final theme = Theme.of(anchorContext);
    final scheme = theme.colorScheme;

    final buttonBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return null;

    final buttonRect =
        buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
        buttonBox.size;
    final position = RelativeRect.fromRect(
      buttonRect,
      Offset.zero & overlayBox.size,
    );

    final maxW = math.min(520.0, overlayBox.size.width - 24.0);
    final menuW = maxW.clamp(360.0, 520.0);
    final maxH = math.min(340.0, overlayBox.size.height - 24.0);

    String? result;
    await showMenu<void>(
      context: anchorContext,
      position: position,
      constraints: BoxConstraints.tightFor(width: menuW),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: BlockEditorFloatingPanel(
              scheme: scheme,
              child: StatefulBuilder(
                builder: (menuCtx, setMenuState) {
                  String? errorText;
                  void closeWithSlug() {
                    final slug = slugController.text.trim();
                    if (slug.isEmpty) {
                      setMenuState(() {
                        errorText = l10n.publishWebEmptySlug;
                      });
                      return;
                    }
                    result = slug;
                    Navigator.pop(menuCtx);
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                          child: Text(
                            l10n.publishWebDialogTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        TextField(
                          controller: slugController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.publishWebSlugLabel,
                            hintText: l10n.publishWebSlugHint,
                            helperText: l10n.publishWebSlugHelper,
                            errorText: errorText,
                          ),
                          onSubmitted: (_) => closeWithSlug(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(menuCtx),
                              child: Text(l10n.cancel),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: closeWithSlug,
                              child: Text(l10n.publishWebAction),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
    return result;
  }

  Future<void> _publishCurrentPageToWeb([BuildContext? anchorContext]) async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10nRoot = AppLocalizations.of(context);
    if (Firebase.apps.isEmpty) {
      _snack(l10nRoot.firebaseUnavailablePublish);
      return;
    }
    if (!widget.cloudAccountController.isSignedIn) {
      _snack(l10nRoot.signInCloudToPublishWeb);
      return;
    }
    if (!widget.folioCloudEntitlements.snapshot.canPublishToWeb) {
      _snack(l10nRoot.planMissingWebPublish);
      return;
    }
    final slugController = TextEditingController(
      text: _suggestWebSlugFromTitle(page.title),
    );
    final snap = widget.folioCloudEntitlements.snapshot;
    try {
      final slug = await _showPublishWebSlugMenu(
        anchorContext: anchorContext ?? context,
        slugController: slugController,
        l10n: l10nRoot,
      );
      if (slug == null || !mounted) return;
      String? appIconDataUri;
      try {
        final data = await rootBundle.load('assets/icons/folio.ico');
        appIconDataUri =
            'data:image/x-icon;base64,${base64Encode(data.buffer.asUint8List())}';
      } catch (_) {}
      final html = folioPageExportHtmlDocument(
        page,
        appIconDataUri: appIconDataUri,
        pagePublishedSubtitle: l10nRoot.pageHtmlExportPublishedWithFolio,
      );
      final res = await publishHtmlPage(
        slug: slug,
        html: html,
        entitlementSnapshot: snap,
      );
      if (!mounted) return;
      _snack(l10nRoot.publishWebSuccessWithUrl('${res.publicUrl}'));
      await launchUrl(res.publicUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _snack(l10nRoot.publishWebFailedWithError('$e'));
    } finally {
      slugController.dispose();
    }
  }
}

enum _FolioPageExportFormat {
  markdown,
  html,
  txt,
  json,
  pdf,
}
