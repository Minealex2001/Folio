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

  Future<void> _exportCurrentPage() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);

    final format = await showDialog<_FolioPageExportFormat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.exportPageDialogTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _FolioPageExportFormat.markdown),
            child: Text(l10n.exportPageFormatMarkdown),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _FolioPageExportFormat.html),
            child: Text(l10n.exportPageFormatHtml),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _FolioPageExportFormat.txt),
            child: Text(l10n.exportPageFormatTxt),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _FolioPageExportFormat.json),
            child: Text(l10n.exportPageFormatJson),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _FolioPageExportFormat.pdf),
            child: Text(l10n.exportPageFormatPdf),
          ),
        ],
      ),
    );
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

  Future<void> _publishCurrentPageToWeb() async {
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
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Text(l10n.publishWebDialogTitle),
            content: TextField(
              controller: slugController,
              decoration: InputDecoration(
                labelText: l10n.publishWebSlugLabel,
                hintText: l10n.publishWebSlugHint,
                helperText: l10n.publishWebSlugHelper,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.publishWebAction),
              ),
            ],
          );
        },
      );
      if (go != true || !mounted) return;
      final slug = slugController.text.trim();
      if (slug.isEmpty) {
        _snack(l10nRoot.publishWebEmptySlug);
        return;
      }
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
